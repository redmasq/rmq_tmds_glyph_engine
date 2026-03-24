rmq_tmds_glyph_engine

Third-party notices and attribution summary for this repository.

## Repository License

This repository is intended to be distributed under the Apache License, Version 2.0.

See [LICENSE.md](LICENSE.md) for the full license text and project-specific licensing notes.

## Included Third-Party Components

### PC Face Submodule

This repository includes the `third_party/pcface` git submodule for reproducible font asset generation.

Upstream project:

- `susam/pcface`
- <https://github.com/susam/pcface>

This submodule remains under its own upstream license terms.

The local CP437 font assets in:

- `resources/cp437_8x16.mem`
- `resources/cp437_8x16.mi`

are intended to be regenerated from:

- `third_party/pcface/out/moderndos-8x16/graph.txt`

The current project preference is to use the permissive `moderndos-8x16` PC Face source so the main repository license can remain Apache-2.0 compatible.

## Generated Font Assets

The checked-in CP437 asset files are generated from the attributed upstream graph source using:

- `scripts/gen_font_module.py`
- `make resources/cp437_8x16.mem`

The generated Gowin font wrapper at:

- `platform/gowin/gowin_prom_cp437_8x16/gowin_prom_cp437_8x16.v`

is derived from the canonical local `.mem` file rather than copied from an opaque binary artifact.

## Vendor Tooling

This repository does not redistribute:

- Gowin EDA
- Gowin Programmer
- AMD Vivado

Building vendor-backed outputs from this repository assumes the end user separately obtains and uses the required vendor tools under the applicable vendor license terms.

Vendor-generated HDL wrappers and primitive references present in the repository are included for interoperability with those external toolchains and should be understood in that context.

## Local Documentation

Some board and vendor reference material may be used during development from local documentation archives outside this git repository. Those external documents are not redistributed as part of this source tree.
