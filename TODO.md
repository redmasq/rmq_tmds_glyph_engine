# TODO

Jira-backed snapshot for `rmq_tmds_glyph_engine` as of April 3, 2026.

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
- `TMDS-28` Frame-domain blink counters and shadow register commit model

## Backlog

- `TMDS-3` Cursor, blink, and attribute system
- `TMDS-29` Attribute blink control and render path
- `TMDS-30` Cursor control registers and blink policy
- `TMDS-31` Cursor shape template and render modes
- `TMDS-5` SDRAM / DDR integration and snapshot system
- `TMDS-7` Multi-mode text and scaling system
- `TMDS-8` Verification, simulation, and test infrastructure
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

With the Python entrypoint scaffold now done, the most natural follow-on tickets look like:

- `TMDS-29` to add independent attribute blink behavior with the half-rate default
- `TMDS-30` to separate cursor visibility from cursor blink-enable control
- `TMDS-31` to add horizontal/vertical cursor templates and final render modes
- `TMDS-18` to make `resources/boards.json` drive selected generated artifacts
- `TMDS-19` to extend that toward a host-agnostic Python-first runner

## TMDS-3 Split Notes

`TMDS-3` now owns the following child tasks in Jira:

- `TMDS-28` Frame-domain blink counters and shadow register commit model
  Frame counters advance once per frame on the `vsync` boundary, and any blink-related state changes must latch atomically there. Shadow registers are part of this ticket so software-visible updates can commit coherently at frame boundaries.
- `TMDS-29` Attribute blink control and render path
  Attribute blink must remain independent from cursor blink. The default attribute blink rate should be half of the cursor blink rate, but cursor blink rate `0` must not implicitly disable attribute blink.
- `TMDS-30` Cursor control registers and blink policy
  Cursor enable must be separated into a visible on/off flag and a blink-enable flag so cursor blink can be disabled without changing the programmed blink rate.
- `TMDS-31` Cursor shape template and render modes
  Cursor shape must support horizontal and vertical modes plus a cursor template field that expresses height or width respectively as 8 steps from none to full coverage.
