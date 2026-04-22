# Tang Primer 20K PMOD0 Keypad Reference

This note captures the Tang Primer 20K portion of `TMDS-33` as the first
board-local reference for the shared live cursor-tuning debug input.

This is a hardware-interface reference only. It does not add RTL, constraints,
debounce logic, keypad scanning, or cursor shadow-register writes.

Current temporary implementation note:

- board tops expose a temporary `debug_pmod_pins[7:0]` array
- the array is ordered by the eight signal-bearing PMOD header positions:
  `pin1`, `pin2`, `pin3`, `pin4`, `pin7`, `pin8`, `pin9`, `pin10`
- Tang Primer contributes a partial temporary mapping into that array rather
  than a direct 8-pin passthrough
- `debug_pmod_pins[3]` is intentionally unavailable on Tang Primer because
  PMOD0 pin 4 lands on `T9`, which Gowin identifies as `IOR38A/DIN/CLKHOLD_N`
- `debug_pmod_pins[7]` is intentionally unavailable on Tang Primer because
  PMOD0 pin 10 lands on `P9`, which Gowin identifies as `IOR38B/DOUT/WE_N`
- this pass-through seam is intentionally temporary and should be removed once a
  proper board-local debug-input interface lands

## Scope

- board: Tang Primer 20K
- connector: ext Dock `PMOD0`
- reference device: 4x4 PMOD-compatible keypad
- purpose: establish the shared logical signal naming and the tested PMOD0 pin
  order that later board-local and RTL work must consume

## Tested PMOD0 Order

The currently tested Tang Primer 20K `PMOD0` pin order is:

| PMOD0 pin | Keypad signal | FPGA pin |
| --- | --- | --- |
| 1 | `COL4` | `P6` |
| 2 | `COL3` | `T7` |
| 3 | `COL2` | `P8` |
| 4 | `COL1` | `T9` |
| 5 | `GND` | `GND` |
| 6 | `3v3` | `3v3` |
| 7 | `ROW4` | `T5` |
| 8 | `ROW3` | `R6` |
| 9 | `ROW2` | `T8` |
| 10 | `ROW1` | `P9` |
| 11 | `GND` | `GND` |
| 12 | `3v3` | `3v3` |

## Discrepancy To Preserve

The back-of-board ext Dock labeling used during local testing disagrees with an
online image that shows this alternate sequence:

`P6 R8 P8 T9 GND 3v3 T6 T7 T8 P9 GND 3v3`

For `TMDS-33`, the tested sequence above is the working reference. The
discrepancy should remain visible until the exact physical board revision and
silkscreen documentation are re-verified.

## Shared Logical Signal Set

Tang Primer 20K is the first board-local reference for the shared PMOD-facing
logical signal set that other boards will adapt into later:

- `COL1`
- `COL2`
- `COL3`
- `COL4`
- `ROW1`
- `ROW2`
- `ROW3`
- `ROW4`
- `3v3`
- `GND`

This ticket treats the row and column names above as the board-agnostic logical
interface for the keypad connector. Future adapter work for Puhzi and Tang Nano
20K should target this same naming and pin order.

## Temporary Array Ordering

The temporary generic board-top array maps as follows on Tang Primer:

| `debug_pmod_pins` index | PMOD signal position | Tang Primer `PMOD0` signal | FPGA pin |
| --- | --- | --- | --- |
| `0` | pin 1 | `COL4` | `P6` |
| `1` | pin 2 | `COL3` | `T7` |
| `2` | pin 3 | `COL2` | `P8` |
| `3` | pin 4 | unavailable | `T9` excluded as `IOR38A/DIN/CLKHOLD_N` |
| `4` | pin 7 | `ROW4` | `T5` |
| `5` | pin 8 | `ROW3` | `R6` |
| `6` | pin 9 | `ROW2` | `T8` |
| `7` | pin 10 | unavailable | `P9` excluded as `IOR38B/DOUT/WE_N` |

This keeps the shared temporary array shape stable across boards while making
the Tang Primer implementation honest about the two PMOD0 positions that the
Gowin package reserves for configuration-related functions.

## Revision Conflict To Preserve

Current local evidence disagrees on how to name the Dock connector carrying the
observed PMOD0 wiring:

- the 3713 Dock schematic labels `J14` as the mic-array connector
- local hardware observation says `PMOD0` is `J14`
- the Sipeed wiki confirms the Dock has four PMOD interfaces, but does not
  resolve this connector-name conflict directly

Keep this conflict visible in notes rather than guessing at a final connector
name until the exact Dock revision is fully re-verified.

## Dock Switch Note

The current Sipeed wiki and the 3713 Dock schematic agree on two useful points:

- DIP switch position 1 is the core-board enable precondition
- `SW1` through `SW5` in the 3713 Dock schematic feed the on-board key nets and
  are not a PMOD-routing mux for this temporary input path

Additional 3709 and 3711 Dock artifacts exist under
`/mnt/v/FPGA/docs/vendors/gowin/sipeed/Primer_20K/` and may explain revision
drift, but they are not required to unblock this build-safe temporary fix.

## Reference Keypad Layout

The intended 4x4 keypad legend is:

| Row | Keys |
| --- | --- |
| 1 | `1 2 3 A` |
| 2 | `4 5 6 B` |
| 3 | `7 8 9 C` |
| 4 | `0 F E D` |

## Shared Semantic Target

The current shared keypad behavior target is:

| Key | Action |
| --- | --- |
| `2` | move cursor up |
| `4` | move cursor left |
| `6` | move cursor right |
| `8` | move cursor down |
| `A` | toggle cursor orientation |
| `F` | decrease blink rate |
| `E` | increase blink rate |
| `C` | increase cursor size in the active orientation |
| `D` | decrease cursor size in the active orientation |
| `B` | toggle demo mode versus manual control |
| `1` | cycle ASCII backward at the cursor |
| `3` | cycle ASCII forward at the cursor |
| `7` | cycle attribute backward at the cursor |
| `9` | cycle attribute forward at the cursor |
| `5` | toggle blink attribute at the cursor |

Power-up behavior should remain the existing demo mode until manual control is
selected.

## Electrical Assumptions To Verify Later

These are not yet implemented here, but later board and RTL work should verify:

- keypad voltage compatibility with Tang Primer 20K `3v3` IO
- required pull-up or pull-down behavior on row and column lines
- active-high versus active-low pressed-state convention
- whether the chosen keypad exposes a passive row/column matrix that requires
  scan logic, or an onboard controller that presents already-decoded signals

## Current WSL UART Capture Workflow

The current temporary Tang Primer debug build includes a UART logger on `M11`
and a capture trigger on `T10`. Because the Primer's JTAG cable and UART share
the same FTDI bridge in WSL, use them in two phases:

1. switch to `program` mode so Gowin can own the FTDI device
2. load the SRAM bitstream
3. switch to `uart` mode so `/dev/ttyUSB0` and `/dev/ttyUSB1` appear in WSL
4. open `minicom` on each channel until the debug logger output appears
5. use `T2` to advance the intended capture target when needed
6. press `T10` once per captured keypad sample

Helper script:

```bash
scripts/wsl2_ftdi_mode.sh program
make tang-primer-tmds-program-sram VIDEO_MODE=720p
scripts/wsl2_ftdi_mode.sh uart
scripts/wsl2_ftdi_mode.sh status
minicom -D /dev/ttyUSB0 -b 115200
minicom -D /dev/ttyUSB1 -b 115200
```

Each `T10` press emits one fixed-width ASCII line:

```text
Sss Ggg Kk Pp Rr Mmm Dd Wmm Qq Yy Cc Aa Tddddddd
```

This keeps the capture log parseable even when the raw PMOD panel is hard to
transcribe by eye. `K` names the intended sample (`I,1,2,3,A,4,5,6,B,7,8,9,C,0,F,E,D`),
`G00`/`KI` is the idle target, `R8` represents the extra all-off `D7` state
where `M00`, and the `T` field makes low-interval bounce captures easy to
reject later. The currently selected `K` character is also shown in the
bottom-right corner of the text buffer so the display and UART stream stay in
sync.

## Explicitly Out Of Scope For This Note

The following belong to a later RTL-focused ticket, not this Tang Primer
reference note:

- top-level RTL ports for keypad signals
- `tang-primer-20k.cst` pin assignments for keypad IO
- debounce and edge handling
- row/column scan or keypad decode logic
- demo/manual arbitration logic
- writes into the existing cursor shadow-register path
