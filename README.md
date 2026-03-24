# rmq_tmds_glyph_engine

TMDS TX with a simple glyph engine, currently brought up on the Tang Nano 20K, Tang Primer 20K, and Puhzi PA200-FL-KFB.

## Quick Start

This repo is meant to be driven from WSL with vendor tools installed on the Windows side.

Before the first build:

```bash
git submodule update --init --recursive
make resources/cp437_8x16.mem
make lint
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

Override them per invocation when needed:

```bash
make tang-nano-tmds-build GOWIN_ROOT=/mnt/c/path/to/Gowin
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
- [TODO.md](TODO.md) is a Jira-backed snapshot of the current backlog as of March 24, 2026.
- [NOTICE.md](NOTICE.md) summarizes third-party attribution and redistribution notes for the repository.
- [LICENSE.md](LICENSE.md) contains the Apache-2.0 license text plus project-specific licensing notes.
