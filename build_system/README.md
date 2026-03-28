# Build System

`build_system/` is the TMDS-13 workspace for the Python-first build and deployment system.

Goals of this scaffold:

- replace the top-level `Makefile` over time with a Python CLI
- support Windows-native, Linux-native, and mixed environments such as WSL2
- keep the current shell-driven vendor flows usable during the transition
- prepare room for open-source backends, a JSON global tooling config, a menu-driven Textual UI, and unit tests

## Layout

- `build_system/build-system.sh` Linux/WSL launcher
- `build_system/build-system.ps1` PowerShell launcher
- `build_system/build-system.bat` `cmd.exe` launcher
- `build_system/create-venv.*` helper launchers for creating a local venv
- `build_system/tooling.template.json` baseline tooling config
- `build_system/tooling.json` optional user-owned config copied from the template
- `build_system/python/` Python package, tests, and docs

## Python Version

This build system targets Python 3 only. Python 2 is explicitly out of scope.

## Quick Start

Linux / WSL:

```bash
./build_system/create-venv.sh
./build_system/build-system.sh tang-nano-20k check
./build_system/build-system.sh tang-nano-20k build VIDEO_MODE=720p
```

PowerShell:

```powershell
./build_system/create-venv.ps1
./build_system/build-system.ps1 tang-nano-20k check
```

`cmd.exe`:

```bat
build_system\create-venv.bat
build_system\build-system.bat tang-nano-20k check
```

## Current Scope

The initial scaffold focuses on:

- JSON-backed tooling configuration
- TOML-backed project-local configuration
- host and package-manager discovery
- tool accessibility checks with install suggestions
- delegated build/program/deploy commands that bridge to the existing repo scripts
- menu-driven `menuconfig` and `projectmenu` entrypoints

Open-source backends are modeled in config and sanity-checks, but some board-specific flows are still expected to mature after the first scaffold lands.

## CLI Shape

The main CLI is board-first and shell-friendly:

```text
build-system [-p <path=.>] <target-board> <action> [NAME=value ...]
```

Actions:

- `build`
- `program-sram`
- `program-flash`
- `deploy`
- `check`

Additional entry commands:

- `config`
- `menuconfig`
- `projectmenu`

Examples:

```bash
./build_system/build-system.sh tang-nano-20k build VIDEO_MODE=720p
./build_system/build-system.sh tang-nano-20k deploy VIDEO_MODE=720p
./build_system/build-system.sh -p bringup/blinky-tang-nano-20k tang-nano-20k deploy
./build_system/build-system.sh -p platform/artix/boards/puhzi-pa200-fl-kfb puhzi-pa200-fl-kfb build VIDEO_MODE=720p
./build_system/build-system.sh config
./build_system/build-system.sh menuconfig
./build_system/build-system.sh -p bringup/blinky-tang-nano-20k projectmenu
```

`deploy` currently means `build` followed by `program-sram` unless overridden with `LOAD_TARGET=flash`.

## Interactive UI

The Textual entrypoint is menu-driven, intentionally closer to old dialog / DOS automenu / kernel-menuconfig flows than to a form editor:

```bash
./build_system/create-venv.sh
./build_system/python/.venv/bin/rmq-tmds-build-tui
```

Current UI capabilities:

- `menuconfig` starts in global configuration mode unless `-p` is provided
- `projectmenu` starts in project-selection mode unless `-p` is provided
- project and workspace discovery from folder roots, including `.`
- global toolchain-family configuration for `yosys`, `gowin`, and `vivado`
- project-local overrides with explicit default-vs-override behavior
- warning-only toolchain validation on `projectmenu` startup
- writing `default.project.toml` from the currently resolved project
- a reusable filesystem browser for toolchain paths, executables, and projects outside the current repo path
- a scrollable execution log view for project actions, with log save support
- configurable text-editor and hex-viewer launchers from the file browser

Useful TUI keys:

- `l` toggle the retained execution log view
- `w` write the retained execution log to `build_system/logs/`
- in the filesystem browser: `s` selects the current directory, `e` opens the text editor for a file, `h` opens the hex viewer for a file, `Esc` cancels

Command intent:

- `build-system config`
  Starts a prompt-style configuration flow with the same global/project concepts as `menuconfig`.
- `build-system menuconfig`
  Launches the config-focused Textual UI. Without `-p` it starts in global configuration mode. With `-p` it goes directly to that project's configuration menu.
- `build-system projectmenu`
  Launches the project-focused Textual UI. It expects a project path from `-p` when provided, otherwise it starts from project/workspace selection before showing build/program actions.

## Global vs Project Config

Global config lives in:

- `build_system/tooling.json`

This is where you set things like:

- official Gowin toolchain location
- official Vivado toolchain location
- auto-detected or overridden open-source tool locations
- environment-wide defaults

Project config lives in:

- `<project-root>/default.project.toml`

This is where you can pin things like:

- preferred project file
- preferred toolchain for that project or board
- per-toolchain path and executable overrides for that project or board
- future project-local metadata as the build system grows

This is useful when the normal environment prefers one toolchain, but a specific project should prefer another one because of IP, timing, or bring-up requirements.

### `-p` Project Resolution

When `-p` is provided, the CLI resolves the project context using this order:

1. `<path>/default.project.toml` `project_file`
2. a single `.gprj` in `<path>`
3. a single board-owned `.gprj` under `<path>/platform/*/boards/<related-board-name>/`
4. path-shape inference for `bringup/...` vs `platform/...`
5. workspace discovery when `<path>` is a broader folder such as `.`

If multiple plausible project files exist, the CLI fails instead of guessing.

### `default.project.toml`

`default.project.toml` is the project-local build-system file in the selected `-p` directory. It replaces the older plain text marker and can hold more than just the preferred project file.

Example:

```toml
project_file = "blinky-tang-nano-20k.gprj"
preferred_toolchain = ""

[toolchains.gowin]
base_path = ""

[toolchains.gowin.executables]
ide_bin = ""
programmer_bin = ""
```

or:

```toml
[boards.tang-nano-20k]
project_file = "platform/gowin/boards/tang-nano-20k/tang-nano-20k.gprj"
preferred_toolchain = "gowin"

[boards.tang-nano-20k.toolchains.gowin]
base_path = "/opt/gowin"
```

This is mainly useful when a directory has more than one plausible project file and you want the CLI, `config`, `menuconfig`, and `projectmenu` to resolve the same project deterministically. Project design remains inferred from the selected project/workspace layout; it is not a user-configurable override.
