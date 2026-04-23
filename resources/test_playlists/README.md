# Test Playlists

Hardware-facing regression playlists live here.

The initial format is JSON so the runner can stay dependency-light. Each
playlist contains ordered `steps` such as:

- `send`: transmit UART bytes
- `sleep`: wait for a fixed duration
- `dump`: trigger a UART debug dump and assert expected fields

The current shared reset smoke test is `reset_validation.json`. Its accepted
post-reinit contract is intentionally narrow: once `I` returns the system to
demo mode, exact cursor position/shape are not treated as stable UART
assertions because demo motion may advance before the dump is observed.

Result artifacts are written under `tests/results/`.
