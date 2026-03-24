/* verilator lint_off UNUSEDPARAM */
module CLKDIV #(parameter DIV_MODE = "5") (
    input wire HCLKIN,
    input wire RESETN,
    input wire CALIB,
    output wire CLKOUT
);
endmodule
/* verilator lint_on UNUSEDPARAM */

/* verilator lint_off UNUSEDPARAM */
module OSER10 #(parameter GSREN = "false", parameter LSREN = "true") (
    input wire PCLK,
    input wire FCLK,
    input wire RESET,
    output wire Q,
    input wire D0,
    input wire D1,
    input wire D2,
    input wire D3,
    input wire D4,
    input wire D5,
    input wire D6,
    input wire D7,
    input wire D8,
    input wire D9
);
endmodule
/* verilator lint_on UNUSEDPARAM */

module TLVDS_OBUF (
    input wire I,
    output wire O,
    output wire OB
);
endmodule

/* verilator lint_off UNUSEDPARAM */
module rPLL #(
    parameter FCLKIN = "27",
    parameter DYN_IDIV_SEL = "false",
    parameter IDIV_SEL = 0,
    parameter DYN_FBDIV_SEL = "false",
    parameter FBDIV_SEL = 0,
    parameter DYN_ODIV_SEL = "false",
    parameter ODIV_SEL = 0,
    parameter PSDA_SEL = "0000",
    parameter DYN_DA_EN = "false",
    parameter DUTYDA_SEL = "1000",
    parameter CLKOUT_FT_DIR = 1'b1,
    parameter CLKOUTP_FT_DIR = 1'b1,
    parameter CLKOUT_DLY_STEP = 0,
    parameter CLKOUTP_DLY_STEP = 0,
    parameter CLKFB_SEL = "internal",
    parameter CLKOUT_BYPASS = "false",
    parameter CLKOUTP_BYPASS = "false",
    parameter CLKOUTD_BYPASS = "false",
    parameter DYN_SDIV_SEL = 2,
    parameter CLKOUTD_SRC = "CLKOUT",
    parameter CLKOUTD3_SRC = "CLKOUT",
    parameter DEVICE = "GW2AR-18C"
) (
    output wire CLKOUT,
    output wire LOCK,
    output wire CLKOUTP,
    output wire CLKOUTD,
    output wire CLKOUTD3,
    input wire RESET,
    input wire RESET_P,
    input wire CLKIN,
    input wire CLKFB,
    input wire [5:0] FBDSEL,
    input wire [5:0] IDSEL,
    input wire [5:0] ODSEL,
    input wire [3:0] PSDA,
    input wire [3:0] DUTYDA,
    input wire [3:0] FDLY
);
endmodule
/* verilator lint_on UNUSEDPARAM */

/* verilator lint_off UNUSEDPARAM */
module pROM #(
    parameter READ_MODE = 1'b1,
    parameter BIT_WIDTH = 4,
    parameter RESET_MODE = "SYNC",
    parameter INIT_RAM_00 = 256'h0,
    parameter INIT_RAM_01 = 256'h0,
    parameter INIT_RAM_02 = 256'h0,
    parameter INIT_RAM_03 = 256'h0,
    parameter INIT_RAM_04 = 256'h0,
    parameter INIT_RAM_05 = 256'h0,
    parameter INIT_RAM_06 = 256'h0,
    parameter INIT_RAM_07 = 256'h0,
    parameter INIT_RAM_08 = 256'h0,
    parameter INIT_RAM_09 = 256'h0,
    parameter INIT_RAM_0A = 256'h0,
    parameter INIT_RAM_0B = 256'h0,
    parameter INIT_RAM_0C = 256'h0,
    parameter INIT_RAM_0D = 256'h0,
    parameter INIT_RAM_0E = 256'h0,
    parameter INIT_RAM_0F = 256'h0,
    parameter INIT_RAM_10 = 256'h0,
    parameter INIT_RAM_11 = 256'h0,
    parameter INIT_RAM_12 = 256'h0,
    parameter INIT_RAM_13 = 256'h0,
    parameter INIT_RAM_14 = 256'h0,
    parameter INIT_RAM_15 = 256'h0,
    parameter INIT_RAM_16 = 256'h0,
    parameter INIT_RAM_17 = 256'h0,
    parameter INIT_RAM_18 = 256'h0,
    parameter INIT_RAM_19 = 256'h0,
    parameter INIT_RAM_1A = 256'h0,
    parameter INIT_RAM_1B = 256'h0,
    parameter INIT_RAM_1C = 256'h0,
    parameter INIT_RAM_1D = 256'h0,
    parameter INIT_RAM_1E = 256'h0,
    parameter INIT_RAM_1F = 256'h0,
    parameter INIT_RAM_20 = 256'h0,
    parameter INIT_RAM_21 = 256'h0,
    parameter INIT_RAM_22 = 256'h0,
    parameter INIT_RAM_23 = 256'h0,
    parameter INIT_RAM_24 = 256'h0,
    parameter INIT_RAM_25 = 256'h0,
    parameter INIT_RAM_26 = 256'h0,
    parameter INIT_RAM_27 = 256'h0,
    parameter INIT_RAM_28 = 256'h0,
    parameter INIT_RAM_29 = 256'h0,
    parameter INIT_RAM_2A = 256'h0,
    parameter INIT_RAM_2B = 256'h0,
    parameter INIT_RAM_2C = 256'h0,
    parameter INIT_RAM_2D = 256'h0,
    parameter INIT_RAM_2E = 256'h0,
    parameter INIT_RAM_2F = 256'h0,
    parameter INIT_RAM_30 = 256'h0,
    parameter INIT_RAM_31 = 256'h0,
    parameter INIT_RAM_32 = 256'h0,
    parameter INIT_RAM_33 = 256'h0,
    parameter INIT_RAM_34 = 256'h0,
    parameter INIT_RAM_35 = 256'h0,
    parameter INIT_RAM_36 = 256'h0,
    parameter INIT_RAM_37 = 256'h0,
    parameter INIT_RAM_38 = 256'h0,
    parameter INIT_RAM_39 = 256'h0,
    parameter INIT_RAM_3A = 256'h0,
    parameter INIT_RAM_3B = 256'h0,
    parameter INIT_RAM_3C = 256'h0,
    parameter INIT_RAM_3D = 256'h0,
    parameter INIT_RAM_3E = 256'h0,
    parameter INIT_RAM_3F = 256'h0
) (
    output wire [31:0] DO,
    input wire CLK,
    input wire OCE,
    input wire CE,
    input wire RESET,
    input wire [13:0] AD
);
endmodule
/* verilator lint_on UNUSEDPARAM */
