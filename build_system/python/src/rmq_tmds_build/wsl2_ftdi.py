from __future__ import annotations

import argparse
from pathlib import Path
from typing import Any

from .paths import BOARDS_LOCAL_MANIFEST_PATH
from .targets import ensure_boards_local_manifest, load_boards_manifest


TTY_ROOT = Path("/sys/class/tty")
SERIAL_BY_ID_ROOT = Path("/dev/serial/by-id")


def _read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8").strip()
    except OSError:
        return ""


def _find_ancestor_with(path: Path, marker: str) -> Path | None:
    current = path
    while True:
        if (current / marker).exists():
            return current
        if current.parent == current:
            return None
        current = current.parent


def _tty_by_id_links() -> dict[str, list[str]]:
    links: dict[str, list[str]] = {}
    if not SERIAL_BY_ID_ROOT.exists():
        return links
    for candidate in sorted(SERIAL_BY_ID_ROOT.iterdir()):
        try:
            resolved = candidate.resolve()
        except OSError:
            continue
        tty_name = resolved.name
        links.setdefault(tty_name, []).append(candidate.name)
    return links


def detect_serial_devices() -> list[dict[str, Any]]:
    by_id_links = _tty_by_id_links()
    devices: list[dict[str, Any]] = []
    for pattern in ("ttyUSB*", "ttyACM*"):
        for tty_path in sorted(TTY_ROOT.glob(pattern)):
            device_symlink = tty_path / "device"
            if not device_symlink.exists():
                continue
            try:
                resolved = device_symlink.resolve()
            except OSError:
                continue
            usb_interface = _find_ancestor_with(resolved, "bInterfaceNumber")
            usb_device = _find_ancestor_with(resolved, "idVendor")
            entry: dict[str, Any] = {
                "tty": tty_path.name,
                "dev_path": f"/dev/{tty_path.name}",
                "by_id": by_id_links.get(tty_path.name, []),
                "usb_device_path": str(usb_device) if usb_device else "",
                "usb_interface_path": str(usb_interface) if usb_interface else "",
                "manufacturer": _read_text(usb_device / "manufacturer") if usb_device else "",
                "product": _read_text(usb_device / "product") if usb_device else "",
                "serial": _read_text(usb_device / "serial") if usb_device else "",
                "vid_pid": "",
                "interface": _read_text(usb_interface / "interface") if usb_interface else "",
                "interface_number": _read_text(usb_interface / "bInterfaceNumber") if usb_interface else "",
            }
            if usb_device:
                vid = _read_text(usb_device / "idVendor")
                pid = _read_text(usb_device / "idProduct")
                if vid and pid:
                    entry["vid_pid"] = f"{vid}:{pid}"
            devices.append(entry)
    return devices


def wsl2_ftdi_board_profiles() -> list[dict[str, Any]]:
    manifest = load_boards_manifest()
    profiles: list[dict[str, Any]] = []
    for board, metadata in manifest.get("boards", {}).items():
        host = metadata.get("host_interfaces", {}).get("wsl2_ftdi")
        if not isinstance(host, dict):
            continue
        local = host.get("local_override", {})
        expected_vid_pid = host.get("expected_vid_pid", "")
        expected_tty_ports = list(host.get("expected_tty_ports", []))
        preferred_vid_pid = local.get("preferred_vid_pid", "") or expected_vid_pid
        preferred_tty_ports = list(local.get("preferred_tty_ports", [])) or expected_tty_ports
        preferred_serial = local.get("preferred_serial", "")
        local_override_active = (
            bool(preferred_serial)
            or (preferred_vid_pid != expected_vid_pid)
            or (preferred_tty_ports != expected_tty_ports)
        )
        profiles.append(
            {
                "board": board,
                "display_name": metadata.get("display_name", board),
                "bridge_type": host.get("bridge_type", ""),
                "expected_vid_pid": expected_vid_pid,
                "expected_channel_count": host.get("expected_channel_count"),
                "expected_roles": list(host.get("expected_roles", [])),
                "expected_tty_ports": expected_tty_ports,
                "preferred_vid_pid": preferred_vid_pid,
                "preferred_tty_ports": preferred_tty_ports,
                "preferred_serial": preferred_serial,
                "notes": local.get("notes", ""),
                "local_override_active": local_override_active,
            }
        )
    return profiles


def _matches_profile(device: dict[str, Any], profile: dict[str, Any]) -> bool:
    preferred_serial = profile.get("preferred_serial", "")
    preferred_vid_pid = profile.get("preferred_vid_pid", "")
    if preferred_serial and device.get("serial", "") != preferred_serial:
        return False
    if preferred_vid_pid and device.get("vid_pid", "") != preferred_vid_pid:
        return False
    return bool(preferred_serial or preferred_vid_pid)


def print_status() -> None:
    profiles = wsl2_ftdi_board_profiles()
    devices = detect_serial_devices()

    print(f"Boards local manifest: {BOARDS_LOCAL_MANIFEST_PATH}")
    print(f"Boards local manifest present: {'yes' if BOARDS_LOCAL_MANIFEST_PATH.exists() else 'no'}")
    print()
    print("Known WSL2 FTDI board profiles:")
    if not profiles:
        print("  (none)")
    for profile in profiles:
        roles = ", ".join(profile.get("expected_roles", [])) or "(unspecified)"
        tty_ports = ", ".join(profile.get("preferred_tty_ports", [])) or "(none)"
        override_state = "yes" if profile.get("local_override_active") else "no"
        print(
            f"  - {profile['display_name']} [{profile['board']}]: "
            f"VID:PID={profile.get('preferred_vid_pid') or '(unknown)'}, "
            f"roles={roles}, tty={tty_ports}, local_override_active={override_state}"
        )
        if profile.get("preferred_serial"):
            print(f"      preferred_serial={profile['preferred_serial']}")
        if profile.get("notes"):
            print(f"      notes={profile['notes']}")
    print()
    print("Detected serial devices:")
    if not devices:
        print("  (none)")
        return
    for device in devices:
        matches = [profile["board"] for profile in profiles if _matches_profile(device, profile)]
        match_text = ", ".join(matches) if matches else "(no manifest match)"
        print(
            f"  - {device['dev_path']}: VID:PID={device.get('vid_pid') or '(unknown)'}, "
            f"product={device.get('product') or '(unknown)'}, "
            f"interface={device.get('interface') or '(unknown)'}, "
            f"serial={device.get('serial') or '(none)'}"
        )
        if device.get("by_id"):
            print(f"      by-id={', '.join(device['by_id'])}")
        print(f"      manifest_matches={match_text}")


def main() -> int:
    parser = argparse.ArgumentParser(description="WSL2 FTDI manifest helpers")
    parser.add_argument("command", choices=("ensure-local", "status"))
    args = parser.parse_args()

    if args.command == "ensure-local":
        path = ensure_boards_local_manifest()
        print(path)
        return 0

    ensure_boards_local_manifest()
    print_status()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
