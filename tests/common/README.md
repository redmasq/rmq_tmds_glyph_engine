# Tests Common

Shared Python helpers for hardware-facing regression flows live here.

The initial focus is UART-driven validation with playlist-based steps and
timestamped result capture under `tests/results/`.

The shared runner is intended to be executed with the repo-managed Python
virtualenv under `build_system/python/.venv`.
