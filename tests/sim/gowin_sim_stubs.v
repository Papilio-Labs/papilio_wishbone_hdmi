// gowin_sim_stubs.v
// Behavioral simulation stubs for Gowin FPGA primitives.
// These replace proprietary DPB / TMDS primitives so iverilog can
// elaborate and simulate the Wishbone register logic.
//
// NOT for synthesis — include only in simulation builds.

// --------------------------------------------------------------------------
// DPB: Gowin dual-port block RAM
// --------------------------------------------------------------------------
module DPB #(
    parameter READ_MODE0  = 1'b0,
    parameter READ_MODE1  = 1'b0,
    parameter WRITE_MODE0 = 2'b00,
    parameter WRITE_MODE1 = 2'b00,
    parameter BIT_WIDTH_0 = 16,
    parameter BIT_WIDTH_1 = 16,
    parameter BLK_SEL_0   = 3'b000,
    parameter BLK_SEL_1   = 3'b000,
    parameter RESET_MODE  = "SYNC"
) (
    input  wire        CLKA, OCEA, CEA, RESETA, WREA,
    input  wire [13:0] ADA,
    input  wire [15:0] DIA,
    output reg  [15:0] DOA,

    input  wire        CLKB, OCEB, CEB, RESETB, WREB,
    input  wire [13:0] ADB,
    input  wire [15:0] DIB,
    output reg  [15:0] DOB,

    input  wire [2:0]  BLKSELA,
    input  wire [2:0]  BLKSELB
);
    reg [15:0] mem [0:1023];

    // Port A (read/write)
    always @(posedge CLKA) begin
        if (CEA) begin
            if (WREA)
                mem[ADA[10:1]] <= DIA;
            DOA <= mem[ADA[10:1]];
        end
    end

    // Port B (read-only in our usage, but support write too)
    always @(posedge CLKB) begin
        if (CEB) begin
            if (WREB)
                mem[ADB[10:1]] <= DIB;
            DOB <= mem[ADB[10:1]];
        end
    end
endmodule

// --------------------------------------------------------------------------
// video_top_wb: stub for the Gowin TMDS top-level used by wb_video_ctrl
// --------------------------------------------------------------------------
module video_top_wb (
    input  wire       I_clk,
    input  wire       I_rst_n,
    input  wire [1:0] I_pattern_mode,
    input  wire [7:0] I_text_char_data,
    output wire [11:0] O_text_char_addr,
    input  wire       I_custom_font_we,
    input  wire [5:0] I_custom_font_addr,
    input  wire [7:0] I_custom_font_data,
    output wire       O_tmds_clk_p,
    output wire       O_tmds_clk_n,
    output wire [2:0] O_tmds_data_p,
    output wire [2:0] O_tmds_data_n
);
    // Behavioral stub — outputs driven to known values
    assign O_text_char_addr = 12'h000;
    assign O_tmds_clk_p     = 1'b0;
    assign O_tmds_clk_n     = 1'b1;
    assign O_tmds_data_p    = 3'b000;
    assign O_tmds_data_n    = 3'b111;
endmodule
