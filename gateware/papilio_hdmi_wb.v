// papilio_hdmi_wb.v — Standard Wishbone wrapper for video_top_modular
//
// Adapts video_top_modular to the standard Papilio Wishbone peripheral
// interface so it can be connected with the EXT_CONNECT macro in top.v:
//
//   `EXT_CONNECT(papilio_hdmi_wb #(.BASE_ADDR(16'h2000)), u_hdmi),
//       .O_tmds_clk_p (O_tmds_clk_p),
//       .O_tmds_clk_n (O_tmds_clk_n),
//       .O_tmds_data_p(O_tmds_data_p),
//       .O_tmds_data_n(O_tmds_data_n)
//   );
//
// Adaptations performed by this wrapper:
//   1. Port naming: I_*/O_* → clk/rst/wb_*_i/wb_*_o
//   2. Reset polarity: active-high rst → active-low I_rst_n
//   3. Data width: 32-bit wb_dat_i/o → 8-bit I/O_wb_dat (lower byte only)
//   4. Base address: BASE_ADDR is subtracted from wb_adr_i before forwarding
//
// Parameters:
//   BASE_ADDR  – main-bus address of this peripheral (default 0x2000)
//                Subtracted from wb_adr_i to give video_top_modular's
//                internal 0x0000-based address space.

`default_nettype none

module papilio_hdmi_wb #(
    parameter [15:0] BASE_ADDR = 16'h2000
) (
    // Standard Papilio Wishbone interface (matches EXT_CONNECT macro)
    input  wire        clk,
    input  wire        rst,
    input  wire [15:0] wb_adr_i,
    input  wire [31:0] wb_dat_i,
    output wire [31:0] wb_dat_o,
    input  wire [3:0]  wb_sel_i,
    input  wire        wb_we_i,
    input  wire        wb_cyc_i,
    input  wire        wb_stb_i,
    output wire        wb_ack_o,

    // HDMI TMDS differential outputs
    output wire        O_tmds_clk_p,
    output wire        O_tmds_clk_n,
    output wire [2:0]  O_tmds_data_p,
    output wire [2:0]  O_tmds_data_n
);

    // -------------------------------------------------------------------------
    // Address: strip BASE_ADDR offset before forwarding to video_top_modular
    // -------------------------------------------------------------------------
    wire [15:0] local_adr = wb_adr_i - BASE_ADDR;

    // -------------------------------------------------------------------------
    // Data: video_top_modular is 8-bit; lower byte only on writes;
    //       zero-extend on reads.
    // -------------------------------------------------------------------------
    wire [7:0] dat_s2m_8;
    assign wb_dat_o = {24'h000000, dat_s2m_8};

    // -------------------------------------------------------------------------
    // video_top_modular instantiation
    // -------------------------------------------------------------------------
    video_top_modular u_video (
        .I_clk        (clk),
        .I_rst_n      (~rst),          // active-low reset
        .I_wb_clk     (clk),
        .I_wb_adr     (local_adr),
        .I_wb_dat     (wb_dat_i[7:0]), // lower byte only
        .I_wb_we      (wb_we_i),
        .I_wb_stb     (wb_stb_i),
        .I_wb_cyc     (wb_cyc_i),
        .O_wb_ack     (wb_ack_o),
        .O_wb_dat     (dat_s2m_8),
        .O_tmds_clk_p (O_tmds_clk_p),
        .O_tmds_clk_n (O_tmds_clk_n),
        .O_tmds_data_p(O_tmds_data_p),
        .O_tmds_data_n(O_tmds_data_n)
    );

endmodule

`default_nettype wire
