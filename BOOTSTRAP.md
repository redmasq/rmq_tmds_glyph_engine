# Bootstrap

This document covers initial environment setup, important configuration variables, and the current command surface in detail.

## Expected Host Environment

Current expected setup:

- WSL2
- Debian GNU/Linux
- `bash`
- vendor tools installed on the Windows side
- supported target board connected over USB when programming hardware

Recommended WSL-side tools:

- `verilator`
- `gtkwave`
- `iverilog`
- optionally `nextpnr-gowin`
- optionally `boolector`
- optionally `sby` / `symbiyosys`

Suggested install sequence:

```bash
sudo apt update
sudo apt install verilator gtkwave iverilog nextpnr-gowin boolector
python3 -m venv ~/.venvs/sby
~/.venvs/sby/bin/pip install --upgrade pip
~/.venvs/sby/bin/pip install git+https://github.com/YosysHQ/sby.git
```

If a Linux GUI tool needs a display path from WSL:

```bash
DISPLAY="${DISPLAY:-:1}" gtkwave
```

## Vendor Tool Locations

Current defaults:

```text
GOWIN_ROOT=/mnt/x/Gowin/Gowin_V1.9.11.03_Education_x64
VIVADO_ROOT=/mnt/y/AMDDesignTools/2025.2/Vivado
```

If `/opt/gowin/IDE/bin` exists, the helper scripts prefer `/opt/gowin` as the default Gowin install and only fall back to the Windows-side `GOWIN_ROOT` layout when the local WSL2 copy is absent.

Expected Gowin-side executables:

- `IDE/bin/gw_ide.exe`
- `IDE/bin/gw_sh.exe`
- `Programmer/bin/programmer.exe`
- `Programmer/bin/programmer_cli.exe`

For a local WSL2 Gowin install, the corresponding expected executables are:

- `IDE/bin/gw_ide`
- `IDE/bin/gw_sh`
- `Programmer/bin/programmer`
- `Programmer/bin/programmer_cli`

Expected Vivado-side executable:

- `bin/vivado.bat`

Override tool paths per command:

```bash
make tang-nano-tmds-build GOWIN_ROOT=/mnt/c/path/to/Gowin
make tang-nano-tmds-build GOWIN_ROOT=/opt/gowin
make puhzi-tmds-build VIVADO_ROOT=/mnt/c/path/to/Vivado
```

## First-Time Repo Setup

After cloning:

```bash
git submodule update --init --recursive
make resources/cp437_8x16.mem
make lint
```

What that does:

- initializes the `third_party/pcface` submodule
- regenerates `resources/cp437_8x16.mem` and `resources/cp437_8x16.mi`
- runs the current Verilator structural lint flow

## Key Configuration Variables

Common variables:

- `VIDEO_MODE=480p|720p`
- `RUN_PROCESS=all|syn|pnr`
- `GOWIN_ROOT=<path>`
- `VIVADO_ROOT=<path>`

Gowin project selection variables:

- `PROJECT_FILE=<path>`
- `BITSTREAM_FILE=<path>`
- `DEVICE=<part>`
- `TANG_PRIMER_DEVICE=<part>`
- `GOWIN_BUILD_ARGS=...`
- `GOWIN_PROGRAM_ARGS=...`

Artix-related variables:

- `PUHZI_VIDEO_MODE=480p|720p`
- `PUZHI_VIDEO_MODE=480p|720p`
- `ARTIX_FONT_ROM_SOURCE_FILE=<path>`

Font/provenance variables:

- `CP437_GRAPH_SOURCE_FILE=<path>`
- `CP437_GRAPH_SOURCE_NOTE=<text>`

Examples:

```bash
make tang-nano-tmds-build RUN_PROCESS=syn VIDEO_MODE=720p
make tang-primer-tmds-program-sram TANG_PRIMER_DEVICE=GW2A-18C
make resources/cp437_8x16.mem CP437_GRAPH_SOURCE_FILE="$PWD/third_party/pcface/out/moderndos-8x16/graph.txt"
```

## Main Validation Command

Lint:

```bash
make lint
```

This runs Verilator in lint-only mode across the main RTL set using local stubs for Gowin-specific primitives.

## Main TMDS Commands

Tang Nano 20K:

```bash
make tang-nano-tmds-open
make tang-nano-tmds-build
make tang-nano-tmds-program
make tang-nano-tmds-program-sram
make tang-nano-tmds-program-flash
make tang-nano-tmds-deploy-sram
make tang-nano-tmds-deploy-flash
```

Tang Primer 20K:

```bash
make tang-primer-tmds-open
make tang-primer-tmds-build
make tang-primer-tmds-program
make tang-primer-tmds-program-sram
make tang-primer-tmds-program-flash
make tang-primer-tmds-deploy-sram
make tang-primer-tmds-deploy-flash
```

Puhzi PA200-FL-KFB:

```bash
make puhzi-tmds-open
make puhzi-tmds-build
make puhzi-tmds-program
make puhzi-tmds-deploy
```

Typical workflows:

```bash
make tang-nano-tmds-build
make tang-nano-tmds-program-sram

make tang-primer-tmds-build VIDEO_MODE=720p
make tang-primer-tmds-program-sram

make puhzi-tmds-build VIDEO_MODE=720p
make puhzi-tmds-program
```

## Bring-Up Commands

Tang Nano 20K:

```bash
make tang-nano-blinky-open
make tang-nano-blinky-build
make tang-nano-blinky-program-sram
make tang-nano-blinky-program-flash
make tang-nano-blinky-deploy-sram
make tang-nano-blinky-deploy-flash
```

Tang Primer 20K:

```bash
make tang-primer-blinky-open
make tang-primer-blinky-build
make tang-primer-blinky-program-sram
make tang-primer-blinky-program-flash
make tang-primer-blinky-deploy-sram
make tang-primer-blinky-deploy-flash
```

Puhzi PA200-FL-KFB:

```bash
make puhzi-blinky-open
make puhzi-blinky-build
make puhzi-blinky-program
make puhzi-blinky-deploy
```

## Utility Commands

Gowin helper targets:

```bash
make gowin-scan-cables
make gowin-scan-device
make gowin-program-cli GOWIN_PROGRAM_ARGS='--scan-cables'
```

Font asset regeneration:

```bash
make resources/cp437_8x16.mem
```

## Compatibility Aliases

Shorter aliases still exist:

- `make tmds-build`
- `make tmds-open`
- `make gowin-build`
- `make gowin-open`
- `make gowin-program`
- `make tang-primer-build`
- `make blinky-build`
- `make blinky-primer-build`

Prefer the explicit board-specific targets for new docs and day-to-day use.

## Limitations

- The implementation flow is still shell/make-centric rather than fully tool-agnostic
- vendor synthesis and programming depend on locally installed Gowin or Vivado
- runtime video-mode switching is still planned work; `VIDEO_MODE` remains a build-time selection
- this repo does not redistribute vendor tools
