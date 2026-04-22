# rmq_tmds_glyph_engine

TMDS TX with a simple glyph engine, currently brought up on the Tang Nano 20K, Tang Primer 20K, and Puhzi PA200-FL-KFB.

Current repo state as of April 4, 2026: row-buffered RGB888 scanout, frame-domain shadow register commit, attribute blink, and the TMDS-30 cursor control path are all landed in the main RTL. Cursor shape/render-mode follow-on work is tracked under `TMDS-31`, and SDRAM-backed snapshot loading remains future work.

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

The current Primer keypad logger emits one ASCII line per `T10` press. `T2`
advances the manual target prompt through `I,1,2,3,A,4,5,6,B,7,8,9,C,0,F,E,D`,
`D7` advances the rotation/select state (including an extra all-off state where
`M00`), and `C7` changes pattern families. The default reset pattern is the
one-hot `*.......` family, and the currently selected target character is shown
in the bottom-right text cell in bright palette `F`.

```text
Sss Ggg Kk Pp Rr Mmm Dd Wmm Qq Yy Cc Aa Tddddddd
```

Where `S` is the step counter, `G` the manual target slot, `K` the intended
capture label (`I,1,2,3,A,4,5,6,B,7,8,9,C,0,F,E,D`), `P` the pattern index,
`R` the rotation/select state, `M` the current PMOD mask, `D` the raw scanner
drive nibble, `W` the raw PMOD bits, `Q` the raw row nibble before remap, `Y`
the logical row nibble, `C` the logical column nibble, `A` the any-active
flag, and `T` the saturating tick count since the last accepted capture.

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
- [TODO.md](TODO.md) is a Jira-backed snapshot of the current backlog as of April 4, 2026.
- [NOTICE.md](NOTICE.md) summarizes third-party attribution and redistribution notes for the repository.
- [LICENSE.md](LICENSE.md) contains the Apache-2.0 license text plus project-specific licensing notes.
