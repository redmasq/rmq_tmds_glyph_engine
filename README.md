# rmq_tmds_glyph_engine

TMDS TX with a simple glyph engine, currently brought up on the Tang Nano 20K, Tang Primer 20K, and Puhzi PA200-FL-KFB, and intended to expand to additional boards.

## Overview

This repository is currently set up around Gowin project flows for the Tang Nano 20K (`GW2AR-18C`) and Tang Primer 20K (`GW2A-18C`). Development is intended to happen from WSL, while Gowin's vendor tools remain installed on the Windows side.

The longer-term expectation is to expand the project to support:

- Tang Nano 20K
- Tang Primer 20K
- Puhzi PA200-FL-KFB

At the moment, the checked-in project files and helper targets cover working TMDS paths for Tang Nano 20K, Tang Primer 20K, and Puhzi PA200-FL-KFB, but the repo should still be treated as the start of a broader multi-board TMDS text-mode platform.

The current workflow is:

- edit RTL from WSL
- run lightweight lint and sanity checks from WSL
- invoke Gowin build and programming tools from WSL through wrapper scripts

There are also small standalone bring-up projects under [bringup/blinky-tang-nano-20k](/home/redmasq/src/rmq_tmds_glyph_engine/bringup/blinky-tang-nano-20k) and [bringup/blinky-tang-primer-20k](/home/redmasq/src/rmq_tmds_glyph_engine/bringup/blinky-tang-primer-20k) for board and programmer smoke testing.

## Expected Setup

### Environment

Expected host environment:

- WSL2
- Debian GNU/Linux
- `bash`
- one of the supported target boards connected over USB when programming hardware

### Supported And Planned Boards

Current bring-up targets:

- Tang Nano 20K
- Tang Primer 20K
- Puhzi PA200-FL-KFB

Planned expansion targets:

- an Artix-based board

The current helper scripts still default to the Tang Nano 20K flow when no board-specific target is selected, but explicit build/program targets now exist for Tang Nano 20K, Tang Primer 20K, and the `Puhzi PA200-FL-KFB`.

Current planning note for future Xilinx/AMD work:

- the current planned Artix target is the `Puhzi PA200-FL-KFB`
- the local Puhzi board manual says the core board provides two active differential reference clocks:
  - `200 MHz` for the logic side
  - `125 MHz` for the GTX interface
- the same manual maps those clocks to:
  - `200 MHz`: `R4/T4` on `BANK34`
  - `125 MHz`: `F10/E10` on `BANK216`
- the local manual also confirms the `PA200T-FL` variant uses `XC7A200T-2FBG484I`
- PLL/MMCM planning for the Artix path should still be checked against the exact AMD Artix-7 device documentation rather than inferred only from board notes

### Structure Plan

The current repo structure plan is:

- `core/` for reusable vendor-agnostic text/video/TMDS logic
- `platform/gowin/` for shared Gowin-specific clocking, serializer, vendor IP, and related glue
- `platform/gowin/boards/<board>/` for Gowin-board-owned tops, constraints, project files, and board notes
- `platform/artix/` for shared Artix-specific MMCM/serializer/PHY and related glue
- `platform/artix/boards/<board>/` for Artix-board-owned tops, constraints, project files, and board notes
- root `scripts/` for shared helper scripts that are common across platforms or not owned by a specific backend build flow

This means boards are expected to live under the vendor/platform they depend on rather than under one top-level shared `boards/` directory.

Examples of the intended board placement:

- `platform/gowin/boards/tang-nano-20k/`
- `platform/gowin/boards/tang-primer-20k/`
- `platform/artix/boards/puhzi-pa200-fl-kfb/`

Current checked-in Gowin board-owned paths:

- `platform/gowin/boards/tang-nano-20k/`
- `platform/gowin/boards/tang-primer-20k/`

Current checked-in shared Artix paths:

- `platform/artix/artix_video_pll.v`
- `platform/artix/artix_hdmi_phy.v`
- `platform/artix/artix_serializer_10to1.v`
- `platform/artix/generated/` for build-generated Artix support RTL such as generated font ROM wrappers
- `platform/artix/pll/`

Current checked-in Artix board-owned paths:

- `platform/artix/boards/puhzi-pa200-fl-kfb/`

Current board metadata manifest:

- `resources/boards.json`
- records the current board catalog for Tang Nano 20K, Tang Primer 20K, and Puhzi PA200-FL-KFB
- includes board/toolchain identifiers, path metadata, supported video modes, PLL/MMCM parameters, and known pin mappings
- is currently informational and preparatory; it is not yet consumed automatically by the build flow

Current intent for the initial split:

- land the first explicit `core/` plus `platform/<vendor>/boards/<board>/` boundary
- keep the Tang Nano 20K path working while the ownership split becomes real
- update project files, lint paths, Make defaults, and other path-based references as part of the same reorganization rather than leaving them behind on old paths
- avoid over-designing the deeper internal structure before the first split is proven in use

Current status of the initial split:

- the first-pass `core/` plus `platform/gowin/boards/tang-nano-20k/` structure has been landed locally
- reusable text/video/TMDS pieces have been separated from Tang Nano board-owned constraints and project assets
- the Tang Nano 20K path has been re-pointed to the board-owned `.gprj`
- the reorganized path has been validated by successful build and SRAM programming on hardware
- a parallel `platform/gowin/boards/tang-primer-20k/` board path now exists and has been validated by successful build, SRAM programming, and visible TMDS output on hardware

Deferred follow-up structure questions are tracked separately for later evaluation:

- whether `core/` should later subdivide further, for example into `core/video`, `core/text`, and `core/tmds`
- whether each vendor platform should later gain `platform/<vendor>/build/`
- keeping root `scripts/` reserved for shared/common helpers even if vendor-specific build directories are added later

### Gowin Tooling

The default tool path expected by the helper scripts is:

```text
/mnt/x/Gowin/Gowin_V1.9.11.03_Education_x64
```

The default Vivado path expected by the Artix helper scripts is:

```text
/mnt/y/AMDDesignTools/2025.2/Vivado
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
- `/mnt/v/FPGA/docs/boards/puhzi-pa200-fl-kfb/README.md`
- `/mnt/v/FPGA/docs/vendors/gowin`
- `/mnt/v/FPGA/docs/reference-designs/SDRAM_Controller_GW2AR-18_RefDsign`

This documentation is treated as part of the expected local reference set when board support expands beyond the Tang Nano 20K, but it is not distributed in this repository.

## Provenance Notes

### Board Manifest

The checked-in board metadata manifest currently lives at:

- [boards.json](/home/redmasq/src/rmq_tmds_glyph_engine/resources/boards.json)

This file is intended to make board naming, toolchain selection, pin ownership, and current PLL/MMCM settings explicit in one place.

At the moment it is a catalog, not a generator input. Future manifest-driven generation work is expected to be handled separately so that project-file templating, constraint generation, and clock-derivation policy can be evaluated deliberately rather than folded into the first naming/manifest pass.

### Video Timing References

The current video timing values used in this project follow standard timing references rather than being invented ad hoc.

- Project F timing reference:
  <https://projectf.io/posts/video-timings-vga-720p-1080p/>

### Resolution Strategy

The intended native output resolution strategy for this project is:

- primary support for `720x480p`
- primary support for `1280x720p`
- optional native support for `640x480p` when the selected board has enough PLL/MMCM headroom to justify it cleanly

All other display modes are expected to be presented by reusing one of the native timing modes above and applying scaling, padding, and centering in the image path rather than by adding a large set of separate native video timings.

Planned clocking behavior:

- the design is intended to grow a clock mux / clock-selection path that can stop video output, switch to a different video clock, and then restart video cleanly
- the long-term goal is to support this on both Gowin and Artix targets by treating `pixel_clk` and `pixel_clk_5x` as a coordinated clock pair rather than as independently switched clocks
- the initial clock-pair targets for that future runtime path are:
  - `27 MHz` plus `135 MHz` for `720x480p`
  - `74.25 MHz` plus `371.25 MHz` for `1280x720p`
- the intended runtime sequence is:
  - cut or blank video output
  - switch or reconfigure the selected `pixel_clk` / `pixel_clk_5x` pair
  - wait for the new clock pair to stabilize and lock
  - restart the video pipeline in the new mode
- this is intended to support resolution changes without treating every mode switch as a static build-time choice
- until that path exists, clocking and mode selection should be treated as implementation-constrained per platform

This is the reference used for common mode values such as `1280x720p60`, including the familiar totals and porch/sync widths:

- pixel clock `74.25 MHz`
- horizontal total `1650`
- vertical total `750`

### Font Source

The bitmap font source for the CP437-style font ROM came from:

- `susam/pcface` output directory:
  <https://github.com/susam/pcface/tree/main/out>

That provenance should be preserved if the font ROM is regenerated or replaced in the future.

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
- [build_vivado.sh](/home/redmasq/src/rmq_tmds_glyph_engine/scripts/build_vivado.sh) runs a small Vivado non-project flow or opens a generated project in Vivado Tcl GUI mode
- [program_vivado.sh](/home/redmasq/src/rmq_tmds_glyph_engine/scripts/program_vivado.sh) programs a Vivado bitstream over JTAG through Hardware Manager
- [lint_verilator.sh](/home/redmasq/src/rmq_tmds_glyph_engine/scripts/lint_verilator.sh) runs Verilator lint with local primitive stubs from [verilator_gowin_prims.v](/home/redmasq/src/rmq_tmds_glyph_engine/scripts/verilator_gowin_prims.v)

These wrappers handle:

- WSL-to-Windows path conversion
- PowerShell-based Windows process launching
- Gowin Tcl batch invocation through `gw_sh.exe`
- Vivado batch invocation through `vivado.bat`
- programmer CLI invocation from the programmer bin directory so its modules resolve correctly

## Make Targets

Run `make help` to print the current target list.

### Validation

`make lint`

- Runs Verilator in lint-only mode on the main RTL set

Current TMDS make variables:

- `VIDEO_MODE=480p|720p` selects the active TMDS timing mode across Gowin and Artix, default `480p`
- `PUHZI_VIDEO_MODE=480p|720p` is a compatibility alias for the Artix path
- `PUZHI_VIDEO_MODE=480p|720p` is a tolerated spelling-variant alias for the Artix path
- `ARTIX_FONT_ROM_SOURCE_FILE=<path>` overrides the generated Artix CP437 font ROM wrapper path
- Uses local stub modules for Gowin-specific primitives
- This is a structural sanity check, not a full simulation or timing signoff
- Expects `verilator` to be installed in WSL

### Main TMDS Project

`make tang-nano-tmds-open`

- Opens [tang-nano-20k.gprj](/home/redmasq/src/rmq_tmds_glyph_engine/platform/gowin/boards/tang-nano-20k/tang-nano-20k.gprj) in the Windows Gowin IDE

`make tang-nano-tmds-build`

- Runs a batch build of the main project through `gw_sh.exe`
- Defaults to `RUN_PROCESS=all`
- Expected output bitstream is [tang-nano-20k.fs](/home/redmasq/src/rmq_tmds_glyph_engine/platform/gowin/boards/tang-nano-20k/impl/pnr/tang-nano-20k.fs)

`make tang-nano-tmds-program`

- Opens the Gowin Programmer GUI for the main project flow

`make tang-nano-tmds-program-sram`

- Programs the main `.fs` bitstream into SRAM
- Requires the board to be connected and visible to Gowin Programmer

`make tang-nano-tmds-program-flash`

- Programs the main `.fs` bitstream into flash
- Use this when you want non-volatile persistence rather than a temporary SRAM load

`make tang-nano-tmds-deploy-sram`

- Builds the main project and then programs it to SRAM
- This is the fastest end-to-end development loop once the board is connected

`make tang-nano-tmds-deploy-flash`

- Builds the main project and then programs it to flash

### Main Project Aliases

Explicit board-specific TMDS targets:

- `make tang-nano-tmds-build`
- `make tang-primer-tmds-build`
- `make puhzi-tmds-build`

Compatibility aliases:

- `make tmds-build`
- `make tang-primer-build`
- `make gowin-build`
- `make gowin-open`
- `make gowin-program`

These are mostly convenience and backward-compatibility aliases.

Current expectation:

- `tang-nano-tmds-*` targets are wired for the Tang Nano 20K project files already in the repo
- `tang-primer-tmds-*` targets point at the Tang Primer board-owned project files
- a Tang Primer 20K board path now exists beside Tang Nano 20K and is intended to stay as a separate board-owned variant
- the Tang Primer path is based on local board notes and the Sipeed HDMI example, and is now validated through successful build, SRAM programming, and visible HDMI/TMDS output
- `puhzi-tmds-*` targets point at the Artix board-owned path for the Puhzi PA200-FL-KFB
- the Puhzi Artix path is validated on hardware for both `480p` and `720p`

### Gowin Utility Targets

`make gowin-scan-cables`

- Lists download cables visible to Gowin Programmer

`make gowin-scan-device`

- Scans the target chain for the configured device
- Defaults to `GW2AR-18C`

### Bring-Up Blinky Projects

`make tang-nano-blinky-open`

- Opens the Tang Nano 20K standalone bring-up project in Gowin IDE

`make tang-nano-blinky-build`

- Builds the Tang Nano 20K standalone blinky project

`make tang-nano-blinky-program-sram`

- Programs the Tang Nano 20K blinky bitstream into SRAM

`make tang-nano-blinky-program-flash`

- Programs the Tang Nano 20K blinky bitstream into flash

`make tang-nano-blinky-deploy-sram`

- Builds Tang Nano 20K blinky and then programs it to SRAM

`make tang-nano-blinky-deploy-flash`

- Builds Tang Nano 20K blinky and then programs it to flash

The Tang Nano 20K blinky project exists as a small known-good smoke test for:

- board connectivity
- cable detection
- programmer flow
- basic Tang Nano 20K pinout sanity

There is also a Tang Primer Dock variant under [bringup/blinky-tang-primer-20k](/home/redmasq/src/rmq_tmds_glyph_engine/bringup/blinky-tang-primer-20k) that reuses the same simple HDL with Tang Primer-specific device and pin assignments.

There is also a first Artix bring-up variant under [bringup/blinky-puhzi-pa200-fl-kfb](/home/redmasq/src/rmq_tmds_glyph_engine/bringup/blinky-puhzi-pa200-fl-kfb), based on the local Puhzi LED reference but kept in the same repo-owned bring-up style rather than importing a full generated Vivado project tree.

Recommended explicit target names:

- `make tang-nano-blinky-build`
- `make tang-nano-blinky-program-sram`
- `make tang-primer-blinky-build`
- `make tang-primer-blinky-program-sram`
- `make puhzi-blinky-build`
- `make puhzi-blinky-program`

Shorter compatibility aliases still exist for now:

- `make blinky-build`
- `make blinky-program-sram`
- `make blinky-primer-build`
- `make blinky-primer-program-sram`

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
make tang-nano-tmds-build RUN_PROCESS=syn
make tang-nano-tmds-program-sram DEVICE=GW2AR-18C
make tang-primer-tmds-build
make gowin-program-cli GOWIN_PROGRAM_ARGS='--scan-cables'
```

## Expectations And Limitations

- The implementation flow is currently Gowin-project-centric, not yet a fully tool-agnostic build system.
- Vendor synthesis, place-and-route, and hardware programming currently depend on the Windows-installed Gowin tools.
- WSL is the preferred shell and scripting environment for development.
- `make lint` is useful for fast structural checking, but it does not replace vendor timing closure or on-board validation.
- `gtkwave` may require a working GUI display path from WSL.
- Board support is currently real for Tang Nano 20K, Tang Primer 20K, and the Puhzi PA200-FL-KFB blinky bring-up path.
- Board support is currently real for Tang Nano 20K, Tang Primer 20K, and Puhzi PA200-FL-KFB for the current TMDS text-mode path.
- Runtime video-mode switching is still a planned follow-up rather than a completed feature; today `VIDEO_MODE` is still a build-time selection.

## Generated Files

Generated Gowin output is intentionally ignored by git, including:

- `impl/`
- nested `impl/` directories such as the ones under `bringup/blinky-tang-nano-20k` and `bringup/blinky-tang-primer-20k`
- `*.gprj.user`
- Windows `:Zone.Identifier` sidecar files
