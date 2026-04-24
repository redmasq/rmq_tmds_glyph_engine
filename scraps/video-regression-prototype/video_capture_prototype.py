from __future__ import annotations

import json
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]


class ValidationError(RuntimeError):
    pass


def load_video_config(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def resolve_scratch_dir(config: dict[str, Any], results_dir: Path) -> Path:
    raw = config.get("video", {}).get("scratch_dir", "./temp/test_scratch")
    path = Path(raw)
    if not path.is_absolute():
        path = REPO_ROOT / path
    path.mkdir(parents=True, exist_ok=True)
    return path


def dut_to_capture_rect(mode: dict[str, Any]) -> tuple[float, float, float, float]:
    cap_w = mode["capture_width"]
    cap_h = mode["capture_height"]
    dut_w = mode["active_width"]
    dut_h = mode["active_height"]

    sx = mode.get("scale_x", cap_w / dut_w)
    sy = mode.get("scale_y", cap_h / dut_h)

    if mode.get("centered", True):
        ox = (cap_w - dut_w * sx) / 2.0
        oy = (cap_h - dut_h * sy) / 2.0
    else:
        ox = float(mode.get("offset_x", 0))
        oy = float(mode.get("offset_y", 0))

    return ox, oy, sx, sy


def expected_text_rect(mode: dict[str, Any]) -> tuple[float, float, float, float]:
    ox, oy, sx, sy = dut_to_capture_rect(mode)
    active_w = mode["active_width"]
    active_h = mode["active_height"]
    text_w = mode["text_width"]
    text_h = mode["text_height"]

    tx = ox + (active_w - text_w) / 2.0 * sx
    ty = oy + (active_h - text_h) / 2.0 * sy
    return tx, ty, text_w * sx, text_h * sy


def capture_video_frame(
    *,
    video_config: dict[str, Any],
    mode_name: str,
    scratch_dir: Path,
    filename: str,
) -> Path:
    import cv2

    video = video_config["video"]
    capture = video["capture"]
    mode = video["dut_modes"][mode_name]

    dev = video.get("device", "/dev/video0")
    width = int(capture.get("width", mode.get("capture_width", mode["active_width"])))
    height = int(capture.get("height", mode.get("capture_height", mode["active_height"])))
    fps = int(capture.get("fps", 60))
    fourcc = str(capture.get("fourcc", "BGR3"))

    cap = cv2.VideoCapture(dev, cv2.CAP_V4L2)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, width)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, height)
    cap.set(cv2.CAP_PROP_FPS, fps)

    if fourcc:
        cap.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*fourcc))

    ok, frame = cap.read()
    cap.release()

    if not ok:
        raise ValidationError(f"failed to capture video frame from {dev}")

    out_path = scratch_dir / filename
    cv2.imwrite(str(out_path), frame)
    return out_path


def capture_step(
    *,
    step: dict[str, Any],
    step_record: dict[str, Any],
    video_config: dict[str, Any],
    video_scratch_dir: Path,
) -> None:
    label = step.get("label", "capture")
    video_mode = step.get("video_mode", "720p")
    frame_path = capture_video_frame(
        video_config=video_config,
        mode_name=video_mode,
        scratch_dir=video_scratch_dir,
        filename=step.get("output", f"{label}.png"),
    )
    step_record["frame"] = str(frame_path)
    step_record["video_mode"] = video_mode
    step_record["status"] = "passed"


def draw_expected_text_box(
    frame: Any,
    *,
    mode: dict[str, Any],
) -> Any:
    import cv2

    tx, ty, tw, th = expected_text_rect(mode)
    cv2.rectangle(
        frame,
        (int(tx), int(ty)),
        (int(tx + tw), int(ty + th)),
        (0, 255, 0),
        1,
    )
    return frame


def left_edge_error(mode: dict[str, Any], detected_left: float) -> float:
    tx, _, _, _ = expected_text_rect(mode)
    return detected_left - tx


if __name__ == "__main__":
    cfg_path = Path(__file__).with_name("sample_video_config.json")
    config = load_video_config(cfg_path)
    scratch_dir = resolve_scratch_dir(config, REPO_ROOT / "tests" / "results")
    mode = config["video"]["dut_modes"]["720p"]
    tx, ty, tw, th = expected_text_rect(mode)
    print(f"scratch_dir={scratch_dir}")
    print(f"expected_text_rect=({tx:.2f}, {ty:.2f}, {tw:.2f}, {th:.2f})")
