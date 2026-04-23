from __future__ import annotations

import json
import os
import shutil
import subprocess
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from rmq_tmds_build.targets import load_boards_manifest
from rmq_tmds_build.wsl2_ftdi import detect_serial_devices, wsl2_ftdi_board_profiles


REPO_ROOT = Path(__file__).resolve().parents[2]
FTDI_MODE_SCRIPT = REPO_ROOT / "scripts" / "wsl2_ftdi_mode.sh"
USB_SERIAL_HELPER_SCRIPT = REPO_ROOT / "scripts" / "check_usb_serial_wsl.sh"

DUMP_FIELD_SPECS: list[tuple[str, str, str]] = [
    ("demo_enable", "D", "bool"),
    ("cursor_col", "X", "hex"),
    ("cursor_row", "Y", "hex"),
    ("cursor_template", "T", "hex"),
    ("cursor_vertical", "V", "bool"),
    ("cursor_mode", "M", "hex"),
    ("cursor_visible", "C", "bool"),
    ("cursor_blink_enable", "B", "bool"),
    ("cursor_blink_period", "P", "hex"),
    ("attr_blink_period", "A", "hex"),
    ("cursor_glyph", "G", "hex"),
    ("cursor_attr", "U", "hex"),
    ("cursor_fg", "F", "hex"),
    ("cursor_bg", "N", "hex"),
    ("cursor_blink_attr", "L", "bool"),
    ("width", "W", "hex"),
    ("height", "H", "hex"),
    ("shadow_dirty", "S", "bool"),
    ("frame_counter", "K", "hex"),
    ("last_rx", "R", "hex"),
    ("last_cmd", "Q", "hex"),
    ("last_cmd_hit", "J", "bool"),
    ("last_shape_source", "Z", "char"),
    ("last_shape_word", "O", "hex"),
    ("last_shape_template", "T", "hex"),
    ("last_shape_vertical", "V", "bool"),
    ("last_shape_mode", "M", "hex"),
    ("glyph_bit_base", "GB", "hex"),
    ("cursor_x_offset", "XO", "hex"),
]


class ValidationError(RuntimeError):
    """Raised when a playlist step fails validation."""


@dataclass
class RunContext:
    board: str
    tty: str | None
    baud: int
    dry_run: bool
    transcript: list[dict[str, Any]]
    steps: list[dict[str, Any]]


def _utc_timestamp() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def load_playlist(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        playlist = json.load(handle)
    if not isinstance(playlist.get("steps"), list):
        raise ValidationError(f"playlist {path} is missing a steps list")
    return playlist


def board_host_profile(board: str) -> dict[str, Any] | None:
    profiles = {profile["board"]: profile for profile in wsl2_ftdi_board_profiles()}
    return profiles.get(board)


def _board_host_interfaces(board: str) -> dict[str, Any]:
    return describe_board(board).get("host_interfaces", {})


def _device_matches_profile(device: dict[str, Any], profile: dict[str, Any]) -> bool:
    preferred_serial = profile.get("preferred_serial", "")
    preferred_vid_pid = profile.get("preferred_vid_pid", "")
    if preferred_serial and device.get("serial", "") != preferred_serial:
        return False
    if preferred_vid_pid and device.get("vid_pid", "") != preferred_vid_pid:
        return False
    return True


def _device_matches_usb_serial(device: dict[str, Any], interface: dict[str, Any]) -> bool:
    expected_vid_pid = interface.get("expected_vid_pid", "")
    expected_product_substring = interface.get("expected_product_substring", "")
    expected_serial = interface.get("preferred_serial", "")
    if expected_vid_pid and device.get("vid_pid", "") != expected_vid_pid:
        return False
    # VID:PID is the strongest discriminator here. Product strings for cheap USB
    # serial adapters can vary between Windows usbipd output and the Linux sysfs
    # product field, so do not reject a device solely on product-text mismatch
    # once the VID:PID already matches.
    if (
        expected_product_substring
        and not expected_vid_pid
        and expected_product_substring not in device.get("product", "")
    ):
        return False
    if expected_serial and device.get("serial", "") != expected_serial:
        return False
    return bool(expected_vid_pid or expected_product_substring or expected_serial)


def _windows_shell() -> str | None:
    for candidate in ("pwsh.exe", "powershell.exe"):
        if shutil.which(candidate):
            return candidate
    return None


def _usbipd_list_output() -> str:
    shell = _windows_shell()
    if shell is None:
        raise ValidationError("pwsh.exe or powershell.exe is required to query usbipd from WSL")
    result = subprocess.run(
        [shell, "-NoProfile", "-Command", "usbipd list"],
        check=True,
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
    )
    return result.stdout


def _find_usbipd_candidate(board: str, interface: dict[str, Any]) -> dict[str, str] | None:
    expected_vid_pid = interface.get("expected_vid_pid", "")
    expected_product_substring = interface.get("expected_product_substring", "")
    shell_output = _usbipd_list_output()
    for line in shell_output.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("BUSID") or stripped.startswith("Persisted:") or stripped.startswith("GUID"):
            continue
        parts = stripped.split()
        if len(parts) < 4 or "-" not in parts[0]:
            continue
        busid = parts[0]
        vid_pid = parts[1]
        state = " ".join(parts[-2:]) if len(parts) >= 2 else ""
        description = " ".join(parts[2:-2]) if len(parts) > 4 else " ".join(parts[2:])
        if expected_vid_pid and vid_pid.lower() != expected_vid_pid.lower():
            continue
        if expected_product_substring and expected_product_substring not in description:
            continue
        return {"busid": busid, "vid_pid": vid_pid, "description": description, "state": state}
    return None


def _usbipd_attach_guidance(board: str, interface: dict[str, Any]) -> str:
    attach_command = interface.get("windows_attach_command_hint", "")
    busid_hint = interface.get("windows_attach_busid_hint", "")
    jtag_note = interface.get("windows_jtag_busid_note", "")
    candidate = None
    try:
        candidate = _find_usbipd_candidate(board, interface)
    except Exception:
        candidate = None

    if candidate is not None:
        state = candidate.get("state", "").lower()
        detail = (
            f"detected Windows-side candidate {candidate['busid']} {candidate['vid_pid']} "
            f"{candidate['description']} ({candidate['state']})"
        )
        if "not shared" in state:
            attach_command = f'usbipd attach --wsl --busid "{candidate["busid"]}"'
            message = f"could not locate a shared WSL tty for board {board}; {detail}. Try: {attach_command}"
        elif "attached" in state:
            attach_command = ""
            message = (
                f"could not locate a shared WSL tty for board {board}; {detail}. "
                f"The device already appears attached to WSL. Run `{USB_SERIAL_HELPER_SCRIPT} {board} load` "
                "to load the WSL-side serial modules, or "
                f"`{USB_SERIAL_HELPER_SCRIPT} {board} status` for a diagnostic summary. "
                "If a tty appears, rerun with `TEST_TTY=/dev/ttyUSB0` or the correct device path."
            )
        else:
            attach_command = ""
            message = (
                f"could not locate a shared WSL tty for board {board}; {detail}. "
                f"Check both Windows usbipd state and WSL serial-driver state, or run `{USB_SERIAL_HELPER_SCRIPT} {board} status`."
            )
    elif busid_hint:
        detail = f"expected Windows-side UART busid hint {busid_hint}"
        message = f"could not locate a shared WSL tty for board {board}; {detail}"
    else:
        detail = "no matching Windows-side usbipd entry was auto-detected"
        message = f"could not locate a shared WSL tty for board {board}; {detail}"

    if attach_command and "Try:" not in message:
        message += f". Try: {attach_command}"
    if jtag_note:
        message += f". Note: {jtag_note}"
    return message


def resolve_board_tty(board: str, retry_uart_mode: bool = True) -> str:
    profile = board_host_profile(board)
    if profile is None:
        raise ValidationError(
            f"board {board} has no manifest-backed WSL2 FTDI host interface in resources/boards.json; "
            "use --tty for now or extend the manifest for this board"
        )

    def pick_device() -> str | None:
        devices = detect_serial_devices()
        devices_by_path = {device["dev_path"]: device for device in devices}
        preferred_paths = list(profile.get("preferred_tty_ports", []))
        for dev_path in preferred_paths:
            device = devices_by_path.get(dev_path)
            if device and _device_matches_profile(device, profile):
                return dev_path
        for device in devices:
            if _device_matches_profile(device, profile):
                return device["dev_path"]
        return None

    dev_path = pick_device()
    if dev_path or not retry_uart_mode:
        if dev_path:
            return dev_path
        raise ValidationError(
            f"could not locate a UART tty for board {board}; check cabling, resources/boards.local.json, "
            "or pass --tty explicitly"
        )

    subprocess.run([str(FTDI_MODE_SCRIPT), "uart"], check=True, cwd=REPO_ROOT)
    dev_path = pick_device()
    if dev_path:
        return dev_path
    raise ValidationError(
        f"switched WSL2 FTDI bridges to uart mode but still could not locate a tty for board {board}"
    )


def resolve_usb_serial_tty(board: str) -> str:
    interface = _board_host_interfaces(board).get("usb_serial", {})
    devices = detect_serial_devices()
    preferred_paths = list(interface.get("expected_tty_ports", []))
    devices_by_path = {device["dev_path"]: device for device in devices}
    for dev_path in preferred_paths:
        device = devices_by_path.get(dev_path)
        if device and _device_matches_usb_serial(device, interface):
            return dev_path
    for device in devices:
        if _device_matches_usb_serial(device, interface):
            return device["dev_path"]
    raise ValidationError(_usbipd_attach_guidance(board, interface))


def parse_dump_line(line: str) -> dict[str, Any]:
    stripped = line.strip()
    if not stripped.startswith("DBG "):
        raise ValidationError(f"not a debug dump line: {stripped!r}")
    tokens = stripped.split()
    expected_token_count = 1 + len(DUMP_FIELD_SPECS)
    if len(tokens) < expected_token_count:
        raise ValidationError(
            f"debug dump had {len(tokens) - 1} fields, expected at least {len(DUMP_FIELD_SPECS)}: {stripped!r}"
        )

    parsed: dict[str, Any] = {"raw_line": stripped}
    for token, (name, prefix, kind) in zip(tokens[1:], DUMP_FIELD_SPECS):
        if not token.startswith(prefix):
            raise ValidationError(f"debug dump token {token!r} did not start with expected prefix {prefix!r}")
        payload = token[len(prefix):]
        if kind == "bool":
            parsed[name] = 1 if payload == "1" else 0
        elif kind == "hex":
            parsed[name] = int(payload, 16)
        elif kind == "char":
            parsed[name] = "" if payload == "." else payload
        else:
            raise ValidationError(f"unsupported field kind {kind!r}")

    parsed["last_rx_ascii"] = chr(parsed["last_rx"]) if 32 <= parsed["last_rx"] <= 126 else ""
    parsed["last_cmd_ascii"] = chr(parsed["last_cmd"]) if 32 <= parsed["last_cmd"] <= 126 else ""
    parsed["cursor_glyph_ascii"] = chr(parsed["cursor_glyph"]) if 32 <= parsed["cursor_glyph"] <= 126 else ""
    return parsed


def _normalize_expected_value(actual: Any, expected: Any) -> Any:
    if isinstance(actual, int) and isinstance(expected, str):
        if len(expected) == 1:
            return ord(expected)
        if expected.startswith("0x"):
            return int(expected, 16)
    return expected


def assert_expected_fields(parsed: dict[str, Any], expected: dict[str, Any]) -> None:
    mismatches: list[str] = []
    for field, expected_value in expected.items():
        if field not in parsed:
            mismatches.append(f"{field}: missing")
            continue
        actual = parsed[field]
        normalized_expected = _normalize_expected_value(actual, expected_value)
        if actual != normalized_expected:
            mismatches.append(f"{field}: expected {normalized_expected!r}, got {actual!r}")
    if mismatches:
        raise ValidationError("; ".join(mismatches))


def write_report(
    *,
    results_dir: Path,
    playlist_path: Path,
    context: RunContext,
    status: str,
    started_at: str,
    ended_at: str,
    error: str | None,
) -> Path:
    results_dir.mkdir(parents=True, exist_ok=True)
    report_path = results_dir / f"{_utc_timestamp()}-{context.board}-{playlist_path.stem}.json"
    payload = {
        "board": context.board,
        "tty": context.tty,
        "baud": context.baud,
        "playlist": str(playlist_path.relative_to(REPO_ROOT)),
        "status": status,
        "started_at": started_at,
        "ended_at": ended_at,
        "dry_run": context.dry_run,
        "error": error,
        "steps": context.steps,
        "transcript": context.transcript,
    }
    report_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    return report_path


def _record_transcript(context: RunContext, direction: str, payload: str) -> None:
    context.transcript.append(
        {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "direction": direction,
            "payload": payload,
        }
    )


def run_playlist(
    *,
    board: str,
    playlist: dict[str, Any],
    playlist_path: Path,
    tty: str | None,
    baud: int,
    results_dir: Path,
    dry_run: bool,
) -> Path:
    started_at = datetime.now(timezone.utc).isoformat()
    context = RunContext(board=board, tty=tty, baud=baud, dry_run=dry_run, transcript=[], steps=[])

    if dry_run:
        for index, step in enumerate(playlist["steps"], start=1):
            context.steps.append(
                {
                    "index": index,
                    "label": step.get("label", f"step-{index}"),
                    "action": step.get("action", ""),
                    "status": "dry-run",
                }
            )
        ended_at = datetime.now(timezone.utc).isoformat()
        return write_report(
            results_dir=results_dir,
            playlist_path=playlist_path,
            context=context,
            status="dry-run",
            started_at=started_at,
            ended_at=ended_at,
            error=None,
        )

    try:
        import serial  # type: ignore
    except ImportError as exc:
        raise ValidationError(
            "pyserial is required to run UART validation; update the repo venv with "
            "./build_system/create-venv.sh or build_system/python/.venv/bin/python -m pip install -e ./build_system/python"
        ) from exc

    last_dump: dict[str, Any] | None = None
    default_timeout = float(playlist.get("default_timeout_seconds", 3.0))

    def read_dump(port: Any, timeout_seconds: float) -> dict[str, Any]:
        deadline = time.monotonic() + timeout_seconds
        partial_line_grace_seconds = 0.75
        partial_line_max_extension_seconds = 2.0
        partial_deadline: float | None = None
        partial_cap_deadline: float | None = None
        partial_buffer = bytearray()
        last_dbg_parse_error: str | None = None
        while True:
            now = time.monotonic()
            if now >= deadline:
                if partial_buffer and partial_deadline is not None and now < partial_deadline:
                    pass
                else:
                    break

            read_size = max(1, int(getattr(port, "in_waiting", 0) or 0))
            raw_chunk = port.read(read_size)
            if not raw_chunk:
                continue

            partial_buffer.extend(raw_chunk)
            if partial_cap_deadline is None:
                partial_cap_deadline = time.monotonic() + partial_line_max_extension_seconds
            partial_deadline = min(
                time.monotonic() + partial_line_grace_seconds,
                partial_cap_deadline,
            )

            while b"\n" in partial_buffer:
                raw_line, _, remainder = partial_buffer.partition(b"\n")
                partial_buffer = bytearray(remainder)
                if not partial_buffer:
                    partial_deadline = None
                    partial_cap_deadline = None

                text_line = raw_line.rstrip(b"\r").decode("utf-8", errors="replace")
                _record_transcript(context, "rx", text_line)
                if not text_line.startswith("DBG "):
                    continue
                try:
                    return parse_dump_line(text_line)
                except ValidationError as exc:
                    last_dbg_parse_error = str(exc)
                    continue
        if last_dbg_parse_error is not None:
            raise ValidationError(
                f"timed out waiting for UART debug dump after {timeout_seconds:.2f}s; "
                f"last DBG parse error: {last_dbg_parse_error}"
            )
        raise ValidationError(f"timed out waiting for UART debug dump after {timeout_seconds:.2f}s")

    try:
        with serial.Serial(tty, baudrate=baud, timeout=0.2) as port:
            port.reset_input_buffer()
            port.reset_output_buffer()

            for index, step in enumerate(playlist["steps"], start=1):
                label = step.get("label", f"step-{index}")
                action = step.get("action", "")
                step_record: dict[str, Any] = {
                    "index": index,
                    "label": label,
                    "action": action,
                    "status": "running",
                }
                context.steps.append(step_record)

                if action == "send":
                    data = step.get("data", "")
                    encoded = data.encode("utf-8")
                    port.write(encoded)
                    port.flush()
                    _record_transcript(context, "tx", data)
                    if step.get("post_delay_ms"):
                        time.sleep(float(step["post_delay_ms"]) / 1000.0)
                    step_record["status"] = "passed"
                elif action == "sleep":
                    milliseconds = int(step.get("milliseconds", 0))
                    time.sleep(milliseconds / 1000.0)
                    step_record["status"] = "passed"
                elif action == "dump":
                    dump_command = step.get("command", "*")
                    port.write(dump_command.encode("utf-8"))
                    port.flush()
                    _record_transcript(context, "tx", dump_command)
                    timeout_seconds = float(step.get("timeout_seconds", default_timeout))
                    last_dump = read_dump(port, timeout_seconds)
                    step_record["dump"] = last_dump
                    if "expect" in step:
                        assert_expected_fields(last_dump, step["expect"])
                    step_record["status"] = "passed"
                elif action == "expect-last-dump":
                    if last_dump is None:
                        raise ValidationError("no previous dump available for expect-last-dump step")
                    assert_expected_fields(last_dump, step.get("expect", {}))
                    step_record["status"] = "passed"
                else:
                    raise ValidationError(f"unsupported step action {action!r} in {playlist_path}")
    except Exception as exc:  # noqa: BLE001
        ended_at = datetime.now(timezone.utc).isoformat()
        if context.steps and context.steps[-1]["status"] == "running":
            context.steps[-1]["status"] = "failed"
            context.steps[-1]["error"] = str(exc)
        report_path = write_report(
            results_dir=results_dir,
            playlist_path=playlist_path,
            context=context,
            status="failed",
            started_at=started_at,
            ended_at=ended_at,
            error=str(exc),
        )
        raise ValidationError(f"{exc} (report: {report_path})") from exc

    ended_at = datetime.now(timezone.utc).isoformat()
    return write_report(
        results_dir=results_dir,
        playlist_path=playlist_path,
        context=context,
        status="passed",
        started_at=started_at,
        ended_at=ended_at,
        error=None,
    )


def describe_board(board: str) -> dict[str, Any]:
    manifest = load_boards_manifest()
    try:
        return manifest["boards"][board]
    except KeyError as exc:
        valid = ", ".join(sorted(manifest.get("boards", {})))
        raise ValidationError(f"unknown board {board!r}. Valid boards: {valid}") from exc


def resolve_uart_target(board: str, tty_override: str | None, auto_switch_uart: bool) -> str | None:
    describe_board(board)
    if tty_override:
        return tty_override
    host_interfaces = _board_host_interfaces(board)
    if "wsl2_ftdi" in host_interfaces:
        return resolve_board_tty(board, retry_uart_mode=auto_switch_uart)
    if "usb_serial" in host_interfaces:
        return resolve_usb_serial_tty(board)
    raise ValidationError(
        f"board {board} has no UART host-interface metadata; pass --tty explicitly or extend resources/boards.json"
    )
