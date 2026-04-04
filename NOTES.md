# Notes

Long-form project notes for `rmq_tmds_glyph_engine`.

This file is the home for the broader structure plan, provenance notes, development assumptions, and planning context that would otherwise make the top-level `README.md` too heavy.

## Current Snapshot

Repo state checked against Jira on April 4, 2026:

- the shared multi-board structure and Python-first build scaffold are in place and aligned with the `TMDS-1` and `TMDS-6` epic direction
- the active text pipeline now uses row-buffered RGB888 scanout in `core/text_plane.v`, reflecting completed `TMDS-27`
- frame-domain shadow register promotion plus cursor/attribute blink counters are in `core/text_frame_ctrl.v`, reflecting completed `TMDS-28`
- attribute blink is live through the renderer path and the demo text fixture, reflecting completed `TMDS-29`
- the TMDS-30 cursor control path is now present in the working tree: cursor row/column/orientation shadow registers commit on the frame boundary, cursor-visible versus blink-enable policy is explicit, and the renderer now applies cursor coverage on screen
- TMDS-31 still represents real follow-on work for final cursor-shape/render-mode signoff and broader integrated validation
- `core/text_snapshot_loader.v` remains a placeholder for future SDRAM/DDR-backed snapshot loading, so `TMDS-5` is still mostly untouched
- verification is still modest: the repo has a working Verilator lint pass plus Python unit coverage for the build system, but it does not yet have a broader RTL regression harness for text-mode behavior
- a new backlog follow-up, `TMDS-33`, now captures the physical debug-input interface standard for future live cursor tuning across Puhzi, Tang Primer 20K, and Tang Nano 20K without pulling that board-specific wiring into the core RTL yet

## Project Shape

This repository is currently set up around Gowin project flows for the Tang Nano 20K (`GW2AR-18C`) and Tang Primer 20K (`GW2A-18C`). Development is intended to happen from WSL, while Gowin's vendor tools remain installed on the Windows side.

Current working board targets:

- Tang Nano 20K
- Tang Primer 20K
- Puhzi PA200-FL-KFB

The checked-in project files and helper targets cover working TMDS paths for all three boards, but the repo should still be treated as the start of a broader multi-board TMDS text-mode platform.

## Structure Plan

Current intended directory ownership:

- `core/` for reusable vendor-agnostic text/video/TMDS logic
- `platform/gowin/` for shared Gowin-specific clocking, serializer, vendor IP, and glue
- `platform/gowin/boards/<board>/` for Gowin board-owned tops, constraints, and project files
- `platform/artix/` for shared Artix-specific MMCM/serializer/PHY and glue
- `platform/artix/boards/<board>/` for Artix board-owned tops, constraints, and project files
- `scripts/` for shared helper scripts that are not owned by one backend

Examples:

- `platform/gowin/boards/tang-nano-20k/`
- `platform/gowin/boards/tang-primer-20k/`
- `platform/artix/boards/puhzi-pa200-fl-kfb/`

Current checked-in shared Artix paths:

- `platform/artix/artix_video_pll.v`
- `platform/artix/artix_hdmi_phy.v`
- `platform/artix/artix_serializer_10to1.v`
- `platform/artix/pll/`

Current board metadata manifest:

- `resources/boards.json`

It records board and toolchain metadata, path ownership, supported video modes, and known pin mappings. It is still informational rather than generator-driven.

## Current Architecture Notes

Current status of the initial split:

- the first-pass `core/` plus `platform/<vendor>/boards/<board>/` boundary is in place
- reusable text/video/TMDS pieces have been separated from board-owned constraints and project assets
- the Tang Nano 20K path has been re-pointed to the board-owned `.gprj`
- a parallel Tang Primer 20K board path now exists and has been validated in hardware
- the Puhzi PA200-FL-KFB path exists as the current Artix target
- the scanout path now uses row-buffered RGB888 staging rather than direct immediate pixel generation during sink timing
- pre-active frame commit timing now exists so committed control state can promote before the next visible frame

Deferred follow-up questions:

- whether `core/` should later subdivide into `core/video`, `core/text`, and `core/tmds`
- whether each vendor platform should later gain `platform/<vendor>/build/`
- how much of the board metadata should move from hand-owned files into generated artifacts

## Tooling Notes

Default tooling paths currently assumed by the helper scripts:

```text
GOWIN_ROOT  = /mnt/x/Gowin/Gowin_V1.9.11.03_Education_x64
VIVADO_ROOT = /mnt/y/AMDDesignTools/2025.2/Vivado
```

Relevant local documentation is expected to live outside the repo under:

```text
/mnt/v/FPGA/docs
```

Useful paths in that archive currently include:

- `/mnt/v/FPGA/docs/boards/tang-nano-20k`
- `/mnt/v/FPGA/docs/boards/puhzi-pa200-fl-kfb/PA200-FL-KFB`
- `/mnt/v/FPGA/docs/vendors/gowin`
- `/mnt/v/FPGA/docs/reference-designs/SDRAM_Controller_GW2AR-18_RefDsign`

## Provenance Notes

### Video Timing References

The current video timing values follow standard timing references rather than ad hoc values.

- Project F timing reference:
  <https://projectf.io/posts/video-timings-vga-720p-1080p/>

### Resolution Strategy

Current intended native output strategy:

- primary support for `720x480p`
- primary support for `1280x720p`
- optional native support for `640x480p` when platform clocking makes it worthwhile

All other display modes are intended to be handled by scaling, padding, and centering rather than by adding a large set of independent native timings.

Longer-term clocking goal:

- treat `pixel_clk` and `pixel_clk_5x` as a coordinated pair
- support clean stop, switch, relock, and restart for mode changes
- keep current `VIDEO_MODE` selection as a build-time choice until runtime mode switching exists

### Font Source

The CP437-style font assets are intended to be regenerated from:

- `third_party/pcface/out/moderndos-8x16/graph.txt`

Upstream source:

- <https://github.com/susam/pcface/tree/main/out/moderndos-8x16>

This repo tracks `susam/pcface` as a submodule so the checked-in `resources/cp437_8x16.mem` and `resources/cp437_8x16.mi` files can be reproduced from an attributed upstream source instead of being hand-copied.

### HDMI Test Pattern Reference

The repository `juj/HDMI_testikuva` was referenced during the initial HDMI/TMDS bring-up work:

- <https://github.com/juj/HDMI_testikuva>

The test pattern used in this project was replicated from that reference because it was useful during early validation and display bring-up.

That repository's TMDS implementation was also immensely useful during the initial Gowin work, especially for understanding and cross-checking the Gowin primitive usage needed for the HDMI/TMDS output path.

### TMDS Encoder Reference

The LiteX TMDS encoder implementation was also referenced during early TMDS work:

- <https://github.com/enjoy-digital/litex/blob/master/litex/soc/cores/code_tmds.py>

That reference was useful as a known working software-side description of TMDS encoding behavior during initial implementation and cross-checking.

### Licensing Assumptions

- The repository license target is Apache-2.0.
- The `pcface` submodule remains under its own upstream license.
- Gowin and Vivado are not redistributed by this repository.
- Vendor-backed builds assume the user obtains and uses those tools under the vendors' own license terms.

## Development Expectations

- WSL is the preferred shell and scripting environment
- `make lint` is useful for fast structural checking but does not replace timing closure or hardware validation
- the current practical structural check is a direct Verilator lint over the Tang Nano 20K top because `make lint` currently hits a generated-file permission issue in the repo
- the direct Verilator lint still reports the existing width-expansion warnings in `core/text_init_writer.v`
- Python build-system tests can be run with `PYTHONPATH=build_system/python/src python3 -m unittest discover -s build_system/python/tests`
- board support is currently real for Tang Nano 20K, Tang Primer 20K, and Puhzi PA200-FL-KFB for the current TMDS text-mode path
- generated `impl/` directories and similar build outputs are intentionally kept out of tracked source

## TMDS-3 Planning Notes

`TMDS-3` is now split into smaller child tasks in Jira:

- `TMDS-28` Frame-domain blink counters and shadow register commit model
- `TMDS-29` Attribute blink control and render path
- `TMDS-30` Cursor control registers and blink policy
- `TMDS-31` Cursor shape template and render modes

Behavior constraints to preserve across those tasks:

- cursor blink and attribute blink are separate controls even if one default is derived from the other
- the default attribute blink rate should be half of the cursor blink rate
- cursor blink rate `0` must not disable attribute blink
- cursor visibility must have a separate on/off flag from any cursor blink-enable flag
- cursor geometry must support horizontal and vertical cursor modes
- the cursor template field represents cursor height for horizontal cursors and cursor width for vertical cursors
- template width or height is expressed as 8 steps from none to full coverage, interpreted as a percentage of the cell height or width respectively
- cursor and attribute blink timing are measured in frames, with counters incremented atomically on the `vsync` boundary
- shadow registers must be included so multi-field updates can commit coherently at the frame boundary rather than tearing mid-frame

## Debug Input Planning Notes

The live cursor-tuning path should keep the core cursor control contract sidecar-friendly and route any future physical debug controls through the same shadow-register surface rather than through a separate renderer-local path.

Current intended hardware direction for that follow-up:

- `TMDS-33` defines a shared physical debug-input interface before RTL integration work begins
- a PMOD-compatible multi-button module is the intended reusable endpoint
- Tang Primer 20K is the native PMOD reference target
- Puhzi uses a ribbon harness from the prototype board into a PMOD adapter
- Tang Nano 20K uses a ribbon drop-in to a PMOD adapter
- Puhzi and Tang Nano 20K should adapt into the same logical PMOD-facing signal set rather than growing custom per-board button semantics
- a later RTL-focused ticket should own board constraints, debounce, edge handling, and writes into the cursor shadow registers
