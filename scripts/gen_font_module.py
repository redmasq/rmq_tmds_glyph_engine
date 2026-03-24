#!/usr/bin/env python3
"""Generate vendor-friendly Verilog ROM wrappers from a canonical hex font."""

from __future__ import annotations

import argparse
from pathlib import Path


def load_bytes(path: Path) -> list[int]:
    values: list[int] = []
    for raw_line in path.read_text().splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        values.append(int(line, 16))
    if len(values) != 4096:
        raise SystemExit(f"expected 4096 bytes in {path}, found {len(values)}")
    return values


def emit_artix_verilog(module_name: str, values: list[int]) -> str:
    lines: list[str] = []
    lines.append(f"module {module_name}(")
    lines.append("  input  wire       clk,")
    lines.append("  input  wire [7:0] char_code,")
    lines.append("  input  wire [3:0] row,")
    lines.append("  output reg  [7:0] bits")
    lines.append(");")
    lines.append("")
    lines.append("  wire [11:0] addr = {char_code, row};")
    lines.append("")
    lines.append("  // Generated from resources/cp437_8x16.mem. Keep this file out of")
    lines.append("  // hand-edited flows and regenerate it from the canonical font source.")
    lines.append('  (* rom_style = "block" *) reg [7:0] rom [0:4095];')
    lines.append("")
    lines.append("  initial begin")
    for idx, value in enumerate(values):
        lines.append(f"    rom[12'h{idx:03X}] = 8'h{value:02X};")
    lines.append("  end")
    lines.append("")
    lines.append("  always @(posedge clk) begin")
    lines.append("    bits <= rom[addr];")
    lines.append("  end")
    lines.append("endmodule")
    lines.append("")
    return "\n".join(lines)


def emit_gowin_verilog(module_name: str, values: list[int]) -> str:
    def chunk_to_hex(chunk: list[int], nibble_shift: int) -> str:
        nibbles = [format((value >> nibble_shift) & 0xF, "X") for value in chunk]
        return "".join(reversed(nibbles))

    lines: list[str] = []
    lines.append("// Generated from resources/cp437_8x16.mem.")
    lines.append("// Do not edit by hand; regenerate with scripts/gen_font_module.py.")
    lines.append("")
    lines.append(f"module {module_name} (dout, clk, oce, ce, reset, ad);")
    lines.append("")
    lines.append("output [7:0] dout;")
    lines.append("input clk;")
    lines.append("input oce;")
    lines.append("input ce;")
    lines.append("input reset;")
    lines.append("input [11:0] ad;")
    lines.append("")
    lines.append("wire [27:0] prom_inst_0_dout_w;")
    lines.append("wire [27:0] prom_inst_1_dout_w;")
    lines.append("wire gw_gnd;")
    lines.append("")
    lines.append("assign gw_gnd = 1'b0;")
    lines.append("")
    for inst_idx, nibble_shift in ((0, 0), (1, 4)):
        lines.append(f"pROM prom_inst_{inst_idx} (")
        lines.append(f"    .DO({{prom_inst_{inst_idx}_dout_w[27:0],dout[{inst_idx * 4 + 3}:{inst_idx * 4}]}}),")
        lines.append("    .CLK(clk),")
        lines.append("    .OCE(oce),")
        lines.append("    .CE(ce),")
        lines.append("    .RESET(reset),")
        lines.append("    .AD({ad[11:0],gw_gnd,gw_gnd})")
        lines.append(");")
        lines.append("")
        lines.append(f"/* verilator lint_off DEFPARAM */" if inst_idx == 0 else "")
        lines.append(f"defparam prom_inst_{inst_idx}.READ_MODE = 1'b1;")
        lines.append(f"defparam prom_inst_{inst_idx}.BIT_WIDTH = 4;")
        lines.append(f'defparam prom_inst_{inst_idx}.RESET_MODE = "SYNC";')
        for init_idx in range(64):
            chunk = values[init_idx * 64:(init_idx + 1) * 64]
            init_hex = chunk_to_hex(chunk, nibble_shift)
            lines.append(
                f"defparam prom_inst_{inst_idx}.INIT_RAM_{init_idx:02X} = 256'h{init_hex};"
            )
        if inst_idx == 1:
            lines.append("/* verilator lint_on DEFPARAM */")
        lines.append("")
    lines.append(f"endmodule //{module_name}")
    lines.append("")
    return "\n".join(line for line in lines if line != "")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--module-name", required=True)
    parser.add_argument("--format", choices=("artix", "gowin"), default="artix")
    args = parser.parse_args()

    values = load_bytes(args.input)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    if args.format == "gowin":
        text = emit_gowin_verilog(args.module_name, values)
    else:
        text = emit_artix_verilog(args.module_name, values)
    args.output.write_text(text if text.endswith("\n") else text + "\n")


if __name__ == "__main__":
    main()
