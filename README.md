# rmq_tmds_glyph_engine

TMDS TX with a simple glyph engine, currently brought up on the Tang Nano 20K and intended to expand to additional Gowin boards.

## Overview

This repository is currently set up around a Gowin project targeting the Tang Nano 20K (`GW2AR-18C`). Development is intended to happen from WSL, while Gowin's vendor tools remain installed on the Windows side.

The longer-term expectation is to expand the project to support:

- Tang Nano 20K
- Tang Primer 20K
- Puhzi PA200-FL-KFB

At the moment, the checked-in project files and helper targets are centered on the Tang Nano 20K bring-up path, but the repo should be treated as the start of a broader multi-board TMDS text-mode platform.

The current workflow is:

- edit RTL from WSL
- run lightweight lint and sanity checks from WSL
- invoke Gowin build and programming tools from WSL through wrapper scripts

There is also a small standalone bring-up project under [bringup/blinky](/home/redmasq/src/rmq_tmds_glyph_engine/bringup/blinky) for board and programmer smoke testing.

## Expected Setup

### Environment

Expected host environment:

- WSL2
- Debian GNU/Linux
- `bash`
- one of the supported target boards connected over USB when programming hardware

### Supported And Planned Boards

Current bring-up target:

- Tang Nano 20K

Planned expansion targets:

- Tang Primer 20K
- Puhzi PA200-FL-KFB

The current helper scripts default to the Tang Nano 20K flow, but the intent is to generalize the project structure, constraints, and build/program wrappers as board support is added.

### Gowin Tooling

The default tool path expected by the helper scripts is:

```text
/mnt/x/Gowin/Gowin_V1.9.11.03_Education_x64
```

The wrappers expect these Windows-side executables to exist:

- `IDE/bin/gw_ide.exe`
- `IDE/bin/gw_sh.exe`
- `Programmer/bin/programmer.exe`
- `Programmer/bin/programmer_cli.exe`

If your Gowin install is somewhere else, override it when invoking `make`:

```bash
make tmds-build GOWIN_ROOT=/mnt/c/path/to/Gowin
```

### Local Board Documentation

Relevant board and device documentation is expected to live in a local archive outside the git repo. The canonical local documentation root for this setup is:

```text
/mnt/v/FPGA/docs
```

Useful paths within that archive currently include:

- `/mnt/v/FPGA/docs/boards/tang-nano-20k`
- `/mnt/v/FPGA/docs/boards/puhzi-pa200-fl-kfb/PA200-FL-KFB`
- `/mnt/v/FPGA/docs/vendors/gowin`
- `/mnt/v/FPGA/docs/reference-designs/SDRAM_Controller_GW2AR-18_RefDsign`

This documentation is treated as part of the expected local reference set when board support expands beyond the Tang Nano 20K, but it is not distributed in this repository.

### WSL Tools

Recommended WSL-side tools:

- `verilator`
- `gtkwave`
- `iverilog`
- optionally `nextpnr-gowin`
- optionally `sby` / `symbiyosys`

Install commands discussed for this environment:

```bash
sudo apt update
sudo apt install verilator gtkwave iverilog nextpnr-gowin boolector
python3 -m venv ~/.venvs/sby
~/.venvs/sby/bin/pip install --upgrade pip
~/.venvs/sby/bin/pip install git+https://github.com/YosysHQ/sby.git
```

If `DISPLAY` is unset in WSL and a Linux GUI tool needs it, `:1` is considered a safe default in this setup:

```bash
DISPLAY="${DISPLAY:-:1}" gtkwave
```

## What The Helpers Do

The repository includes WSL-friendly wrappers under [scripts](/home/redmasq/src/rmq_tmds_glyph_engine/scripts):

- [build_gowin.sh](/home/redmasq/src/rmq_tmds_glyph_engine/scripts/build_gowin.sh) launches Gowin IDE or batch build
- [program_gowin.sh](/home/redmasq/src/rmq_tmds_glyph_engine/scripts/program_gowin.sh) launches Gowin Programmer GUI or CLI
- [lint_verilator.sh](/home/redmasq/src/rmq_tmds_glyph_engine/scripts/lint_verilator.sh) runs Verilator lint with local primitive stubs from [verilator_gowin_prims.v](/home/redmasq/src/rmq_tmds_glyph_engine/scripts/verilator_gowin_prims.v)

These wrappers handle:

- WSL-to-Windows path conversion
- PowerShell-based Windows process launching
- Gowin Tcl batch invocation through `gw_sh.exe`
- programmer CLI invocation from the programmer bin directory so its modules resolve correctly

## Make Targets

Run `make help` to print the current target list.

### Validation

`make lint`

- Runs Verilator in lint-only mode on the main RTL set
- Uses local stub modules for Gowin-specific primitives
- This is a structural sanity check, not a full simulation or timing signoff
- Expects `verilator` to be installed in WSL

### Main TMDS Project

`make tmds-open`

- Opens [rmq_tmds_glyph_engine.gprj](/home/redmasq/src/rmq_tmds_glyph_engine/rmq_tmds_glyph_engine.gprj) in the Windows Gowin IDE

`make tmds-build`

- Runs a batch build of the main project through `gw_sh.exe`
- Defaults to `RUN_PROCESS=all`
- Expected output bitstream is [impl/pnr/rmq_tmds_glyph_engine.fs](/home/redmasq/src/rmq_tmds_glyph_engine/impl/pnr/rmq_tmds_glyph_engine.fs)

`make tmds-program`

- Opens the Gowin Programmer GUI for the main project flow

`make tmds-program-sram`

- Programs the main `.fs` bitstream into SRAM
- Requires the board to be connected and visible to Gowin Programmer

`make tmds-program-flash`

- Programs the main `.fs` bitstream into flash
- Use this when you want non-volatile persistence rather than a temporary SRAM load

`make tmds-deploy-sram`

- Builds the main project and then programs it to SRAM
- This is the fastest end-to-end development loop once the board is connected

`make tmds-deploy-flash`

- Builds the main project and then programs it to flash

### Main Project Aliases

These map to the same main-project flow:

- `make gowin-build`
- `make gowin-open`
- `make gowin-program`

These are mostly convenience and backward-compatibility aliases.

Current expectation:

- these targets are currently wired for the Tang Nano 20K project files already in the repo
- future Tang Primer 20K and PA200-FL-KFB support will likely add board-specific project files, constraints, and target names rather than overloading the current Tang Nano 20K defaults

### Gowin Discovery / Debug Targets

`make gowin-probe`

- Prints the Tcl command environment available through `gw_sh.exe`

`make gowin-run-probe`

- Opens the main project and probes the available `run` behavior in Gowin Tcl

`make gowin-program-probe`

- Prints `programmer_cli.exe --help`

`make gowin-scan-cables`

- Lists download cables visible to Gowin Programmer

`make gowin-scan-device`

- Scans the target chain for the configured device
- Defaults to `GW2AR-18C`

### Bring-Up Blinky Project

`make blinky-open`

- Opens the standalone bring-up project in Gowin IDE

`make blinky-build`

- Builds the standalone blinky project

`make blinky-program-sram`

- Programs the blinky bitstream into SRAM

`make blinky-program-flash`

- Programs the blinky bitstream into flash

`make blinky-deploy-sram`

- Builds blinky and then programs it to SRAM

`make blinky-deploy-flash`

- Builds blinky and then programs it to flash

The blinky project exists as a small known-good smoke test for:

- board connectivity
- cable detection
- programmer flow
- basic Tang Nano 20K pinout sanity

## Useful Variables

These can be overridden on the `make` command line:

`PROJECT_FILE=<path>`

- Override the `.gprj` used for the main project targets

`BITSTREAM_FILE=<path>`

- Override the `.fs` used for the main project programming targets

`DEVICE=<part>`

- Programmer target device
- Defaults to `GW2AR-18C`

`RUN_PROCESS=all|syn|pnr`

- Select which Gowin batch process to run during build targets

`GOWIN_ROOT=<path>`

- Override the Windows Gowin install root

`GOWIN_BUILD_ARGS=...`

- Extra arguments passed through to `gw_sh.exe`

`GOWIN_PROGRAM_ARGS=...`

- Extra arguments passed through to `programmer_cli.exe`

Example:

```bash
make tmds-build RUN_PROCESS=syn
make tmds-program-sram DEVICE=GW2AR-18C
make gowin-program-cli GOWIN_PROGRAM_ARGS='--scan-cables'
```

## Expectations And Limitations

- The implementation flow is currently Gowin-project-centric, not yet a fully tool-agnostic build system.
- Vendor synthesis, place-and-route, and hardware programming currently depend on the Windows-installed Gowin tools.
- WSL is the preferred shell and scripting environment for development.
- `make lint` is useful for fast structural checking, but it does not replace vendor timing closure or on-board validation.
- `gtkwave` may require a working GUI display path from WSL.
- Board support is currently real for Tang Nano 20K and still planned/document-driven for Tang Primer 20K and Puhzi PA200-FL-KFB.

## Generated Files

Generated Gowin output is intentionally ignored by git, including:

- `impl/`
- nested `impl/` directories such as the one under `bringup/blinky`
- `*.gprj.user`
- Windows `:Zone.Identifier` sidecar files
