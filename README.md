# rmq_tmds_glyph_engine

TMDS TX with a simple glyph engine, currently brought up on the Tang Nano 20K, Tang Primer 20K, and Puhzi PA200-FL-KFB.

Current repo state as of April 23, 2026: row-buffered RGB888 scanout, frame-domain shadow register commit, attribute blink, cursor control, and cursor shape/render-mode behavior are all landed in the main RTL. The active manual cursor/UART command path now lives in `aux/uart_text_cursor_console.v`; demo mode is functional again through the shared shadow-register path; the richer UART debug dump now lives in a shared `aux` seam and is validated on Tang Primer 20K, Tang Nano 20K, and Puhzi PA200-FL-KFB. SDRAM-backed snapshot loading remains future work.

## Quick Start

This repo is meant to be driven from WSL with vendor tools installed on the Windows side.

Before the first build:

```bash
git submodule update --init --recursive
make resources/cp437_8x16.mem
make lint
```

Quick local verification:

```bash
make lint
PYTHONPATH=build_system/python/src python3 -m unittest discover -s build_system/python/tests
```

Quick TMDS build and program examples:

```bash
# Tang Nano 20K
make tang-nano-tmds-build
make tang-nano-tmds-program-sram

# Tang Primer 20K
make tang-primer-tmds-build
make tang-primer-tmds-program-sram

# Puhzi PA200-FL-KFB
make puhzi-tmds-build
make puhzi-tmds-program
```

Quick bring-up examples:

```bash
make tang-nano-blinky-build
make tang-primer-blinky-build
make puhzi-blinky-build
```

## Tool Overrides

Default tool locations expected by the helper scripts:

- `GOWIN_ROOT=/mnt/x/Gowin/Gowin_V1.9.11.03_Education_x64`
- `VIVADO_ROOT=/mnt/y/AMDDesignTools/2025.2/Vivado`

When present, the scripts now prefer a local WSL2 Gowin install at `/opt/gowin` by default and fall back to the Windows-side `GOWIN_ROOT` layout otherwise.

Override them per invocation when needed:

```bash
make tang-nano-tmds-build GOWIN_ROOT=/mnt/c/path/to/Gowin
make tang-nano-tmds-build GOWIN_ROOT=/opt/gowin
make puhzi-tmds-build VIVADO_ROOT=/mnt/c/path/to/Vivado
```

Useful common overrides:

- `VIDEO_MODE=480p|720p`
- `RUN_PROCESS=all|syn|pnr`
- `DEVICE=<gowin-part>`
- `TANG_PRIMER_DEVICE=<gowin-part>`

Examples:

```bash
make tang-nano-tmds-build RUN_PROCESS=syn VIDEO_MODE=720p
make tang-primer-tmds-program-sram TANG_PRIMER_DEVICE=GW2A-18C
```

### WSL2 FTDI Workflow

Known board-side FTDI bridge expectations live in `resources/boards.json`, and
machine-local FTDI matching hints live in `resources/boards.local.json`. The
local file is auto-created on first use by the WSL2 FTDI helper and is ignored
by git.

Tang Primer's JTAG programmer and debug UART currently share the same FTDI
bridge in WSL. Use only one mode at a time:

```bash
# Release FTDI serial drivers so Gowin can program SRAM/flash.
scripts/wsl2_ftdi_mode.sh program
make tang-primer-tmds-program-sram VIDEO_MODE=720p

# Prefer `*-program-sram` after any successful fresh build when the bitstream
# is already current. Use `*-deploy-sram` only when you also need the rebuild.

# Rebind FTDI serial drivers so WSL exposes /dev/ttyUSB0 and /dev/ttyUSB1.
scripts/wsl2_ftdi_mode.sh uart

# Inspect detected FTDI mappings or test both UART channels for the current debug logger.
scripts/wsl2_ftdi_mode.sh status
minicom -D /dev/ttyUSB0 -b 115200
minicom -D /dev/ttyUSB1 -b 115200
```

The current UART/debug bring-up path uses the shared command module in
`aux/uart_text_cursor_console.v` plus the shared dump seam in
`aux/text_mode_uart_debug_dump.v`. Board tops now contribute only the physical
UART pins and local dump trigger wiring. Demo mode remains the default reset
behavior and is currently functional again after the latest control-path fixes.
In manual mode, the shared UART commands are:

- `2`, `4`, `6`, `8` move the cursor
- `A` toggles horizontal vs vertical cursor shape
- `C`, `D` increase/decrease cursor template size
- `0` cycles cursor mode `REPLACE -> OR -> XOR`
- `^` forces cursor template `7`
- `_` forces cursor template `1`
- `#` toggles cursor visibility without changing shape or blink policy
- `+`, `-` do fine blink-period speed changes
- `E`, `F` do coarse blink-period speed changes
- `<` forces blink period `0` (cursor stays on while visible)
- `>` forces blink period `1` (fastest blink)
- `B` toggles demo vs manual mode
- `R` restores the startup cursor state in manual mode without touching text RAM
- `L` clears the text buffer to blanks without forcing demo mode
- `I` performs a full reinit: clear, startup redraw, startup cursor restore, demo re-enable, and glyph-preview update re-enable
- `G` enables glyph-preview corner updates
- `H` disables glyph-preview corner updates without erasing the current corner glyphs
- `1`, `3` cycle the glyph at the cursor backward / forward
- `7`, `9` cycle the attribute at the cursor backward / forward
- `5` toggles the blink attribute at the cursor
- `*` emits a debug dump line over UART

Board-local full reinit buttons now follow the same shared behavior as UART `I`:

- Tang Primer 20K uses `T2`
- Tang Nano 20K uses `S2`
- Puhzi PA200-FL-KFB keeps the parity full-reinit path in RTL, but the default checked-in build ties it off internally unless an explicit future build enables `PUHZI_ENABLE_FULL_REINIT_INPUT`

### UART Reset Harness

The shared UART reset harness stores playlists under `resources/test_playlists/`
and writes timestamped reports under `tests/results/`.

Use the repo venv for the Python dependency path:

```bash
./build_system/create-venv.sh
make tang-primer-uart-reset-test
make tang-nano-uart-reset-test
make puhzi-uart-reset-test
```

If the Puhzi CH340 is already attached into WSL but no `/dev/ttyUSB*` node is
visible yet, use:

```bash
make puhzi-uart-wsl-help
make puhzi-uart-wsl-load
```

That helper summarizes current `usbipd` state, local `/dev/ttyUSB*` visibility,
recent `dmesg` lines, and the `modprobe` steps to try before rerunning the
reset test with an explicit `TEST_TTY=/dev/ttyUSB0`.

When you want to release those WSL-side serial modules again, use:

```bash
make puhzi-uart-wsl-release
```

Current bring-up note: cursor alignment is improved and usable, but still
slightly off and should be treated as a tolerable interim state rather than
fully closed.

```text
DBG Dn Xcc Yrr Tt Vv Mm Cc Bb Ppppp Apppp Ggg Uaa Ff Nn Ll Wwwww Hhhhh Ss Kkkkk Rxx Qxx Jj Zz Ohhhh Tt Vv Mm GBg XOxx
```

Where the current shared dump reports committed demo/manual state (`D/X/Y/T/V/M/C/B/P/A/G/U/F/N/L/W/H/S/K`), UART telemetry (`R/Q/J/Z/O` plus emitted `T/V/M`), and current cursor-alignment debug inputs (`GB` for `GLYPH_BIT_BASE`, `XO` for the effective cursor x-offset adjustment). The dump contract is now shared across boards, with current hardware validation complete on Tang Primer 20K, Tang Nano 20K, and Puhzi PA200-FL-KFB.

## Submodule Notes

This repo uses `third_party/pcface` as a submodule for reproducible CP437 font asset generation.

If the submodule is missing:

```bash
git submodule update --init --recursive
```

To refresh the local font source artifacts:

```bash
make resources/cp437_8x16.mem
```

That regenerates both `resources/cp437_8x16.mem` and `resources/cp437_8x16.mi` from `third_party/pcface/out/moderndos-8x16/graph.txt`.

## Important Notes

- The repository license target is Apache-2.0. See [LICENSE.md](LICENSE.md).
- This repo does not redistribute Gowin or Vivado. Building vendor-backed outputs assumes you obtain and use those tools under their own licenses.
- `make lint` is a structural sanity check. It is not a replacement for vendor timing closure or hardware validation.

## Other Docs

- [BOOTSTRAP.md](BOOTSTRAP.md) explains environment setup, variables, and the build/program commands in more detail.
- [NOTES.md](NOTES.md) keeps the longer-form project notes, structure rationale, provenance notes, and planning context that used to live in the README.
- [TODO.md](TODO.md) is a Jira-backed snapshot of the current backlog as of April 23, 2026.
- [NOTICE.md](NOTICE.md) summarizes third-party attribution and redistribution notes for the repository.
- [LICENSE.md](LICENSE.md) contains the Apache-2.0 license text plus project-specific licensing notes.
