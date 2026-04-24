# Notes

Long-form project notes for `rmq_tmds_glyph_engine`.

This file is the home for the broader structure plan, provenance notes, development assumptions, and planning context that would otherwise make the top-level `README.md` too heavy.

## Current Snapshot

Repo state checked against Jira and the working tree on April 23, 2026:

- the shared multi-board structure and Python-first build scaffold are in place and aligned with the `TMDS-1` and `TMDS-6` epic direction
- the active text pipeline now uses row-buffered RGB888 scanout in `core/text_plane.v`, reflecting completed `TMDS-27`
- frame-domain shadow register promotion plus cursor/attribute blink counters are in `core/text_frame_ctrl.v`, reflecting completed `TMDS-28`
- attribute blink is live through the renderer path and the demo text fixture, reflecting completed `TMDS-29`
- the TMDS-30 cursor control path is now present in the working tree: cursor row/column/orientation shadow registers commit on the frame boundary, cursor-visible versus blink-enable policy is explicit, and the renderer now applies cursor coverage on screen
- the TMDS-31 cursor shape/render-mode behavior is now in place in the working tree: horizontal and vertical geometry selection, 8-step template coverage, and `replace` / `OR` / `XOR` cursor composition are all wired through the frame-coherent control path
- the active shared UART/manual cursor command path lives in `aux/uart_text_cursor_console.v`, and the shared UART debug dump contract now lives in `aux/text_mode_uart_debug_dump.v`
- Tang Primer 20K, Tang Nano 20K, and Puhzi PA200-FL-KFB have all been smoke-tested against that shared dump seam using both a local physical trigger and UART `*`
- recent live bring-up fixed two real control-path regressions: cursor-shape words now pack consistently across manual and demo paths, and demo update requests now survive long enough to emit through the intended shadow-register write path; demo mode is now back to functioning through that common control seam
- cursor alignment is improved enough to use, but remains slightly off and should be treated as a cleanup/fidelity follow-up rather than fully closed
- `core/text_snapshot_loader.v` remains a placeholder for future SDRAM/DDR-backed snapshot loading, so `TMDS-5` is still mostly untouched
- verification is still modest: the repo has a working Verilator lint pass plus Python unit coverage for the build system, but it does not yet have a broader RTL regression harness for text-mode behavior
- the practical TMDS-31 closeout checks currently pass at the lightweight level: direct Verilator lint still succeeds with the known `core/text_init_writer.v` width-expansion warnings, and the Python build-system tests pass cleanly
- the `TMDS-33` backlog note is now narrowed to the physical debug-input and local trigger side of that work, while broader common-top, sidecar, demo-flag, and richer shared-buffer follow-up has been split into `TMDS-45`

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
- whether a repo-level additive dispatch wrapper should exist above the board-local `platform/.../top.v` entrypoints without replacing those standalone board synthesis roots

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

## TMDS-8 Planning Notes

`TMDS-8` is now split into focused child tasks rather than being treated as one large verification pass:

- `TMDS-32` Attribute blink cross-board validation and regression coverage
- `TMDS-35` Spike: evaluate Yosys-based Gowin CI path for Tang Nano 20K and Tang Primer 20K
- `TMDS-36` Shared simulation harness foundation for core and platform-owned RTL
- `TMDS-37` Gowin simulation workflow with waveform export and GtkWave usability
- `TMDS-38` Artix and Vivado simulation feasibility and primitive strategy
- `TMDS-39` Core text-engine submodule unit-test coverage
- `TMDS-40` Golden-output regression coverage for text rendering behavior

Current planning direction:

- keep the bulk of behavioral coverage in vendor-neutral `core/` tests whenever possible
- treat board-wrapper and PHY-adjacent simulation as a thinner integration layer above that
- make the Gowin path the first practical waveform-oriented simulation workflow because the repo already has Verilator-oriented Gowin lint support and primitive stubs
- ensure the Gowin simulation path can emit artifacts that are easy to inspect in GtkWave during local iteration
- investigate whether a Yosys/apicula-backed Gowin flow can move linting, synthesis sanity checks, and some regression work into GitHub Actions
- treat coverage in that open-tool CI path as informative and estimated rather than enforcing a hard minimum gate while the project is still bounded by vendor-specific gaps
- keep Artix in scope early so the simulation harness shape does not assume every platform can be treated like Gowin
- expect PLL, SERDES, MMCM, timing signoff, and hardware-only behavior to remain partly vendor-backed or board-backed even if open-tool CI becomes useful

Current `TMDS-35` findings as of April 23, 2026:

- manual open-tool synthesis works for both Tang Primer 20K and Tang Nano 20K when driven directly through Yosys rather than the repo's current Python front end
- the distro `nextpnr-gowin` package on this machine is too limited for this spike because it rejects the checked-in Gowin device names early
- the newer OSS CAD Suite path at `/opt/oss-cad-suite/bin/yosys` plus `/opt/oss-cad-suite/bin/nextpnr-himbaechel` is the right direction for continued Gowin evaluation
- `nextpnr-himbaechel` includes the `gowin` uarch and recognizes at least `GW2A-18C` plus `GW2AR-18C` chip databases locally
- Tang Primer currently gets as far as device/family acceptance under Himbaechel, but the run still fails on a speed-grade/database issue: `ERROR: Speed grade 'ES' not found in database.`
- the checked-in differential CST style does not currently fit nextpnr's expectations; lines such as `IO_LOC "hdmi_tx_p[0]" H14,H16;` need to be expanded into separate positive and negative constraints such as `IO_LOC "hdmi_tx_p[0]" H14;` and `IO_LOC "hdmi_tx_n[0]" H16;`
- the current open-tool flow also reports unconstrained negative-side TMDS outputs if the CST keeps the paired-pin shorthand, for example `ERROR: Unconstrained IO:hdmi_tx_n_OBUF_O_3`
- the vendor-style PLL placement constraint `INS_LOC "hdmi_pll/u_pll/rpll_inst" PLL_L[1];` does not currently appear to map cleanly through the open flow and should be treated as an unresolved follow-up rather than a blocker to documenting the spike
- near-term practical path: document the manual OSS CAD Suite probe flow, keep lint plus synth-sanity as the first likely CI slice, and treat full open-source Gowin place-and-route as still experimental until the CST and PLL constraint gaps are better understood

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

## TMDS-43 Current Closeout Scope

`TMDS-43` is no longer the umbrella ticket for every debug-side architecture
follow-up. The implemented seam now covers:

- shared UART/manual command handling in `aux/uart_text_cursor_console.v`
- shared UART debug dump formatting/transport in `aux/text_mode_uart_debug_dump.v`
- multiple trigger support via a shared dump-request input
- per-board UART HAL wiring and local trigger wiring in board-local tops
- the current bounded append-buffer hook in the shared dump contract

What still remains on `TMDS-43` after the recent ticket split:

- closeout hygiene after cross-board seam validation
- any narrow seam-validation cleanup still worth doing before ticket close

Items that used to sit here but now belong to `TMDS-45`:

- common/compatible top-interface normalization
- additive repo-level common-top wrapper work
- sidecar-mode architecture
- demo build-flag behavior
- build-system adjustments for common-top or sidecar flows
- richer shared debug-buffer behavior beyond the current bounded append hook

## Debug Input Planning Notes

The live cursor-tuning path should keep the core cursor control contract sidecar-friendly and route any future physical debug controls through the same shadow-register surface rather than through a separate renderer-local path.

Current shared-seam direction:

- shared UART/manual command handling belongs in common modules under `aux/`
- the richer UART debug dump contract is now shared under `aux/`, with board-local tops only owning physical UART and trigger wiring
- the broader follow-on design track for common top/interface, sidecar mode, and richer shared debug-buffer behavior now lives under `TMDS-45`
- if no status/debug producer is wired, that optional text-region sink should behave as a no-op rather than forcing board-local debug coupling
- both demo-driven updates and manual/UART-driven updates must continue to converge on the same shadow-register/control write pathway
- the current manual/UART path and restored demo path should be treated as evidence for that shared control seam, not as separate control architectures
- any future repo-level common wrapper must remain additive; board-local `platform/.../top.v` files still need to be directly usable when opening/building platform projects on their own

Current intended hardware direction for that follow-up:

- `TMDS-33` defines a shared physical debug-input interface before RTL integration work begins
- a PMOD-compatible multi-button module is the intended reusable endpoint
- Tang Primer 20K is the first board-local reference target, but not an authoritative 8-GPIO PMOD source for the temporary passthrough
- board-local Tang Primer PMOD0 reference note lives at `platform/gowin/boards/tang-primer-20k/PMOD0-keypad-reference.md`
- temporary implementation path uses a generic `debug_pmod_pins[7:0]` board-top array ordered as PMOD signal positions `1,2,3,4,7,8,9,10`
- current tested Tang Primer 20K ext Dock PMOD0 reference order is `P6 T7 P8 T9 GND 3v3 T5 R6 T8 P9 GND 3v3`
- Tang Primer currently backs only `debug_pmod_pins[0]`, `1`, `2`, `4`, `5`, and `6`; `debug_pmod_pins[3]` and `7` are intentionally unavailable because `T9` is `IOR38A/DIN/CLKHOLD_N` and `P9` is `IOR38B/DOUT/WE_N`
- the back-of-board ext Dock labeling disagrees with an online image that shows `P6 R8 P8 T9 GND 3v3 T6 T7 T8 P9 GND 3v3`, so that discrepancy should stay visible in the planning notes until the physical board revision is fully nailed down
- current local evidence also conflicts on connector naming: the 3713 Dock schematic labels `J14` as the mic-array connector, while local hardware observation says `PMOD0` is `J14`
- the Sipeed wiki confirms the Dock has four PMOD interfaces and that DIP switch 1 enables the core board, but does not resolve the `J14` naming conflict directly
- the 3713 Dock schematic shows `SW1` through `SW5` tied to the on-board key nets rather than acting as a PMOD-routing mux
- Puhzi uses a ribbon harness from the prototype board into a PMOD adapter
- Tang Nano 20K uses a ribbon drop-in to a PMOD adapter
- Puhzi and Tang Nano 20K should adapt into the same logical PMOD-facing signal set rather than growing custom per-board button semantics
- current shared keypad semantic target is:
- `2`, `4`, `6`, `8` for cursor motion
- `A` for cursor orientation swap
- `F` / `E` for blink-rate down / up
- `C` / `D` for cursor height-or-width up / down depending on orientation
- `B` for demo mode versus manual control
- `1` / `3` for ASCII cycle backward / forward at the current cursor location
- `7` / `9` for attribute cycle backward / forward at the current cursor location
- `5` for toggling the blink attribute at the current cursor location
- power-up behavior should remain the existing demo mode until manual control is selected
- current preferred Puhzi source is the `JM1` 40-pin 2.54mm expansion header because the user manual marks it as BANK15 at 3.3V
- current preferred Puhzi candidate GPIO set is `JM1-5` through `JM1-12`:
- `JM1-5` `IO_L17P_15` (`N18`)
- `JM1-6` `IO_L18P_15` (`N20`)
- `JM1-7` `IO_L17N_15` (`N19`)
- `JM1-8` `IO_L18N_15` (`M20`)
- `JM1-9` `IO_L15P_15` (`N22`)
- `JM1-10` `IO_L16P_15` (`M18`)
- `JM1-11` `IO_L15N_15` (`M22`)
- `JM1-12` `IO_L16N_15` (`L18`)
- current preferred Tang Nano 20K direction is to avoid the SDIO header signals and instead use breakout-accessible LCD and sidecar peripheral GPIOs
- current Tang Nano 20K first-pass candidate set is `PIN42_LCD_R3`, `PIN41_LCD_R4`, `PIN56_I2S_BCLK`, `PIN54_I2S_DIN`, `PIN48_LCD_DE`, `PIN55_I2S_LRCK`, `PIN49_LCD_BL`, plus one extra non-SDIO sidecar GPIO chosen from `PIN51_PA_~{SD}/EN`, `PIN72_HSPI_DIN1`, or `PIN71_HSPI_DIN0`
- if the onboard audio-amp enable path should stay untouched, prefer `PIN72_HSPI_DIN1` or `PIN71_HSPI_DIN0` over `PIN51_PA_~{SD}/EN`
- current temporary board-top passthrough maps `debug_pmod_pins[0:7]` onto the Puhzi `JM1-5` through `JM1-12` sequence and the Tang Nano set `PIN42`, `PIN41`, `PIN56`, `PIN54`, `PIN48`, `PIN55`, `PIN49`, `PIN72`
- additional 3709 and 3711 Tang Primer Dock artifacts under `/mnt/v/FPGA/docs/vendors/gowin/sipeed/Primer_20K/` may explain naming drift across revisions, but are not required to unblock the current build-safe temporary fix
- a later RTL-focused ticket should own board constraints, debounce, edge handling, keypad scan or decode if needed, demo/manual arbitration, and writes into the cursor shadow registers
