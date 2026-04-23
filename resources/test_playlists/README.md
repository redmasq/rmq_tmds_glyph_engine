# Test Playlists

Hardware-facing regression playlists live here.

The initial format is JSON so the runner can stay dependency-light. Each
playlist contains ordered `steps` such as:

- `send`: transmit UART bytes
- `sleep`: wait for a fixed duration
- `dump`: trigger a UART debug dump and assert expected fields

Result artifacts are written under `tests/results/`.
