#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path

from common.hardware_uart_validation import (
    REPO_ROOT,
    ValidationError,
    load_playlist,
    resolve_uart_target,
    run_playlist,
)


def main() -> int:
    parser = argparse.ArgumentParser(description="Run UART-driven hardware validation playlists")
    parser.add_argument("--board", required=True, help="Board key from resources/boards.json")
    parser.add_argument(
        "--playlist",
        required=True,
        type=Path,
        help="Path to a JSON playlist, typically under resources/test_playlists/",
    )
    parser.add_argument("--tty", help="Explicit UART tty override, e.g. /dev/ttyUSB0")
    parser.add_argument("--baud", type=int, default=115200, help="UART baud rate")
    parser.add_argument(
        "--results-dir",
        type=Path,
        default=REPO_ROOT / "tests" / "results",
        help="Directory for timestamped JSON result files",
    )
    parser.add_argument(
        "--no-auto-switch-uart",
        action="store_true",
        help="Do not call scripts/wsl2_ftdi_mode.sh uart when no tty is found on the first pass",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Validate board/playlist handling and emit a report without opening a serial port",
    )
    args = parser.parse_args()

    playlist_path = args.playlist
    if not playlist_path.is_absolute():
        playlist_path = (REPO_ROOT / playlist_path).resolve()
    playlist = load_playlist(playlist_path)

    tty = None
    if not args.dry_run:
        tty = resolve_uart_target(args.board, args.tty, auto_switch_uart=not args.no_auto_switch_uart)

    report_path = run_playlist(
        board=args.board,
        playlist=playlist,
        playlist_path=playlist_path,
        tty=tty,
        baud=args.baud,
        results_dir=args.results_dir,
        dry_run=args.dry_run,
    )
    print(report_path)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ValidationError as exc:
        print(f"error: {exc}")
        raise SystemExit(1)
