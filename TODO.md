# TODO

Jira-backed snapshot for `rmq_tmds_glyph_engine` as of April 23, 2026.

This file is a repo-facing view of the current Jira state. It is not authoritative over Jira, but it is meant to make the current backlog easier to scan from the working tree.

## In Progress

- `TMDS-1` Repo and platform framework
- `TMDS-2` Text mode core engine (Mode 7 baseline)
- `TMDS-4` Display pipeline, timing, and TMDS output
- `TMDS-6` HAL, build automation, and board support

## Done

- `TMDS-9` Core/platform directory split
- `TMDS-10` Tang Nano 20K platform wrapper extraction
- `TMDS-11` Board manifest and target naming scheme
- `TMDS-12` Per-board constraint and project layout
- `TMDS-13` Python HAL/build entrypoint scaffold
- `TMDS-14` Build flow abstraction for Gowin backend
- `TMDS-15` Build flow abstraction for Vivado backend (PA200-FL-KFB)
- `TMDS-16` Multi-board development documentation pass
- `TMDS-20` Open source readiness and licensing cleanup
- `TMDS-27` RGB888 pixel row ping-pong buffers and scanout model
- `TMDS-28` Frame-domain blink counters and shadow register commit model
- `TMDS-29` Attribute blink control and render path

## Backlog

- `TMDS-3` Cursor, blink, and attribute system
- `TMDS-30` Cursor control registers and blink policy
- `TMDS-31` Cursor shape template and render modes
- `TMDS-5` SDRAM / DDR integration and snapshot system
- `TMDS-7` Multi-mode text and scaling system
- `TMDS-8` Verification, simulation, and test infrastructure
- `TMDS-32` Attribute blink cross-board validation and regression coverage
- `TMDS-35` Spike: evaluate Yosys-based Gowin CI path for Tang Nano 20K and Tang Primer 20K
- `TMDS-36` Shared simulation harness foundation for core and platform-owned RTL
- `TMDS-37` Gowin simulation workflow with waveform export and GtkWave usability
- `TMDS-38` Artix and Vivado simulation feasibility and primitive strategy
- `TMDS-39` Core text-engine submodule unit-test coverage
- `TMDS-40` Golden-output regression coverage for text rendering behavior
- `TMDS-33` Hardware debug-input interface standard for live cursor tuning
- `TMDS-43` Define shared UART/debug seam and optional status-text region for cross-board text-mode integration
- `TMDS-44` Add Python UART integration/regression harness for text-mode debug flows
- `TMDS-45` Extract common top, sidecar mode, and shared debug-buffer architecture from UART seam follow-up
- `TMDS-17` Spike: evaluate deeper repo subdivision after initial split
- `TMDS-18` Manifest-driven board file generation from boards.json
- `TMDS-19` Evaluate Python-first cross-platform build runner for WSL2, MinGW/MSYS2, and native PowerShell
- `TMDS-21` VGA analog output support and legacy font mode expansion
- `TMDS-22` TUI UX polish for menuconfig and projectmenu
- `TMDS-23` TUI logic cleanup and config/menuconfig parity
- `TMDS-24` Extract build_system into its own repository
- `TMDS-25` Reintegrate standalone build_system as a submodule
- `TMDS-26` Glyph row buffer pipeline split-out

## Probably Next

With `TMDS-27`, `TMDS-28`, and `TMDS-29` now done, the most natural follow-on tickets look like:

- `TMDS-32` to finish cross-board validation and add regression coverage for attribute blink
- `TMDS-35` to determine how much of the Gowin verification path can move into Yosys-backed GitHub Actions
- `TMDS-36` to establish a shared simulation harness before per-module and per-platform tests branch too far apart
- `TMDS-37` to make the Gowin path practical for waveform-oriented local debug in GtkWave
- `TMDS-39` to start landing vendor-neutral unit coverage in `core/`
- `TMDS-40` to add repeatable golden-output renderer regression checks
- `TMDS-30` to separate cursor visibility from cursor blink-enable control
- `TMDS-31` to add horizontal/vertical cursor templates and final render modes
- `TMDS-33` to finish the physical trigger and board-local debug-input closeout after cross-board validation
- `TMDS-43` to finish the shared UART/debug seam closeout, mainly Puhzi validation
- `TMDS-44` to add a Python `SEND` / `EXPECT` / `WAIT` / `ABORT` regression harness against the shared UART/debug contract
- `TMDS-45` to carry the common-top, sidecar-mode, demo-flag, build-system, and richer shared debug-buffer follow-up
- `TMDS-18` to make `resources/boards.json` drive selected generated artifacts
- `TMDS-19` to extend that toward a host-agnostic Python-first runner

## Repo State Notes

What the current tree already reflects:

- row-buffered RGB888 scanout is in place in `core/text_plane.v`, matching the completed `TMDS-27` work
- frame-domain shadow register promotion and blink counters are implemented in `core/text_frame_ctrl.v`, matching `TMDS-28`
- attribute blink is wired through the renderer and demo fixture in `core/text_mode_source.v` and `core/text_init_writer.v`, matching `TMDS-29`
- the current branch now carries the TMDS-30 cursor control path end-to-end: frame-coherent cursor shadow registers, committed row/column/orientation state, cursor-visible versus blink-enable policy, and demo-driven register exercise through `core/text_init_writer.v`
- the TMDS-31 cursor shape/render-mode behavior is now present in `core/text_mode_source.v`, including horizontal/vertical template coverage, zero-to-full 8-step geometry control, and `replace`/`OR`/`XOR` composition driven through the frame-coherent cursor control path
- the active UART/manual cursor command path lives in `aux/uart_text_cursor_console.v`, and the richer UART debug dump now uses the shared `aux/text_mode_uart_debug_dump.v` seam
- Tang Primer 20K, Tang Nano 20K, and Puhzi PA200-FL-KFB have all passed shared UART/debug smoke tests
- the demo path has had two recent control-path regressions fixed locally: shared cursor-shape packing now matches the frame-control contract, demo update requests now survive long enough to emit through the normal shadow-register write pathway, and demo mode is functional again through that same committed control seam
- cursor alignment is improved and currently usable, but it is still slightly off and should be treated as a tolerable interim state rather than fully closed
- SDRAM-backed snapshot loading remains a placeholder in `core/text_snapshot_loader.v`, so `TMDS-5` is still genuinely backlog work
- verification is still lightweight: the practical structural check is a direct Verilator lint over the Tang Nano 20K top because `make lint` currently trips over a repo-local generated-file permission issue, and the Python build-system tests pass via `PYTHONPATH=build_system/python/src python3 -m unittest discover -s build_system/python/tests`

## TMDS-3 Split Notes

`TMDS-3` now tracks the following child-task state in the repo:

- `TMDS-30` Cursor control registers and blink policy
  Cursor enable must be separated into a visible on/off flag and a blink-enable flag so cursor blink can be disabled without changing the programmed blink rate.
- `TMDS-31` Cursor shape template and render modes
  Cursor shape must support horizontal and vertical modes plus a cursor template field that expresses height or width respectively as 8 steps from none to full coverage. Blink gating must apply across all cursor render modes. `replace` means direct overwrite, `OR` applies the cursor color bitwise OR after considering the pixel content already being rendered, and `XOR` does the same with bitwise XOR. The planned transparent palette entry behavior should not suppress cursor rendering even if it eventually suppresses glyph rendering when precopied row pixels are reused.

Current implementation note:

- `TMDS-30` is effectively implemented in the working tree, but this file still leaves it in backlog until Jira status is updated during ticket closeout
- `TMDS-31` is effectively implemented and locally validated; remaining closeout work is Jira status hygiene rather than additional RTL behavior

## Validation Follow-Up

- `TMDS-35` Spike: evaluate Yosys-based Gowin CI path for Tang Nano 20K and Tang Primer 20K
  This spike explores whether the open Yosys/apicula-style stack can cover both Gowin boards well enough to move linting and some verification into GitHub Actions, with estimated coverage reporting but no strict lower-bound gate.
- `TMDS-36` Shared simulation harness foundation for core and platform-owned RTL
  This defines the reusable directory layout, runner shape, and vendor-neutral versus vendor-specific boundaries for simulation work under the `TMDS-8` umbrella.
- `TMDS-37` Gowin simulation workflow with waveform export and GtkWave usability
  This is the practical Gowin-first simulation path, including waveform generation for local inspection and a documented approach for representing PLL and SERDES behavior in tests.
- `TMDS-38` Artix and Vivado simulation feasibility and primitive strategy
  This captures the Artix-side verification plan so Gowin-first simulation work does not paint the wider multi-board strategy into a corner.
- `TMDS-39` Core text-engine submodule unit-test coverage
  This covers fast, mostly vendor-neutral unit tests for reusable `core/` modules such as frame control, renderer behavior, plane orchestration, and initialization logic.
- `TMDS-40` Golden-output regression coverage for text rendering behavior
  This adds repeatable renderer regression checks using stable expected output before board-specific PHY details enter the picture.
- `TMDS-32` Attribute blink cross-board validation and regression coverage
  Follow-up validation for `TMDS-29` under the `TMDS-8` verification umbrella. This covers non-Tang board checks, re-verifying the blink fixture, and adding a repeatable non-hardware verification path.

## Debug and Seam Follow-Up

- `TMDS-33` Hardware debug-input interface standard for live cursor tuning
  This is now the narrower physical-trigger and board-local debug-input ticket. Primer, Nano, and Puhzi all have live trigger paths working through the shared dump seam, and the remaining work is primarily closeout hygiene plus any minimal cleanup needed to declare the physical trigger story stable.
- `TMDS-43` Shared UART/debug seam and status-text region
  This is now the narrower shared UART/debug seam closeout ticket. The shared command path, shared dump formatter, multiple trigger support, and per-board HAL wiring are landed; remaining work is any seam-validation cleanup worth doing before closure plus ticket hygiene.
- `TMDS-44` Python UART integration/regression harness
  This tracks the future `SEND` / `EXPECT` / `WAIT` / `ABORT` style regression runner and any JSON-driven UART assertion format layered on top of the now-shared UART/debug contract.
- `TMDS-45` Common top, sidecar mode, and richer shared debug-buffer follow-up
  This now owns the broader architecture that was intentionally split away from `TMDS-43`: common/compatible top-interface work, additive common-top wrapper ideas, sidecar mode, demo build-flag behavior, build-system adjustments for those flows, and any richer shared debug-buffer behavior beyond the current bounded append hook.
