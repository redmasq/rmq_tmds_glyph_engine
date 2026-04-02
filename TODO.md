# TODO

Jira-backed snapshot for `rmq_tmds_glyph_engine` as of April 2, 2026.

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

## Backlog

- `TMDS-3` Cursor, blink, and attribute system
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
- `TMDS-27` RGB888 pixel row ping-pong buffers and scanout model

## Probably Next

With the Python entrypoint scaffold now done, the most natural follow-on tickets look like:

- `TMDS-18` to make `resources/boards.json` drive selected generated artifacts
- `TMDS-19` to extend that toward a host-agnostic Python-first runner
- `TMDS-27` to formalize the RGB888 scanline buffer model for concurrent render and scanout
