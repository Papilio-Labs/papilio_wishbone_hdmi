// ==============================================================================
// video_top_modular.v - Example modular HDMI video system integration
// ==============================================================================
// This example shows how to use the modular video components:
//   - hdmi_phy_720p.v   - Shared HDMI physical layer with open-source TMDS
//   - wb_video_testpattern.v - Test pattern generator (optional)
//   - wb_video_text.v   - Text mode 80x26 (optional)
//   - wb_video_framebuffer.v - 160x120 RGB332 framebuffer (optional)
//
// Users can pick and choose which video modes to include in their design.
// The video mode mux allows runtime switching between modes via Wishbone.
//
// This is an EXAMPLE - modify for your specific needs.
// ==============================================================================

module video_top_modular
(
    // System
    input             I_clk           , // 27MHz system clock
    input             I_rst_n         ,
    
    // Wishbone slave interface (directly from SPI bridge or MCU)
    input             I_wb_clk        ,
    input      [15:0] I_wb_adr        , // 16-bit address space
    input      [7:0]  I_wb_dat        ,
    input             I_wb_we         ,
    input             I_wb_stb        ,
    input             I_wb_cyc        ,
    output reg        O_wb_ack        ,
    output reg [7:0]  O_wb_dat        ,
    
    // HDMI output
    output            O_tmds_clk_p    ,
    output            O_tmds_clk_n    ,
    output     [2:0]  O_tmds_data_p   ,
    output     [2:0]  O_tmds_data_n   
);

// ==============================================================================
// Address decoding for video sub-modules
// ==============================================================================
// Address map:
//   0x0000-0x000F : Mode control (this module)
//   0x0010-0x001F : Test pattern registers
//   0x0020-0x00FF : Text mode registers + char RAM
//   0x0100-0x7FFF : Framebuffer (word-aligned: pixel_addr * 4)

localparam ADDR_MODE_CTRL   = 16'h0000;
localparam ADDR_TP_BASE     = 16'h0010;
localparam ADDR_TEXT_BASE   = 16'h0020;
localparam ADDR_FB_BASE     = 16'h0100;

// ==============================================================================
// Video mode control register
// ==============================================================================
// Mode register at 0x0000:
//   [1:0] = Video mode select:
//           0 = Test pattern
//           1 = Text mode
//           2 = Framebuffer
//           3 = Reserved

reg [1:0] video_mode;

wire wb_mode_sel = (I_wb_adr < ADDR_TP_BASE);
wire wb_tp_sel   = (I_wb_adr >= ADDR_TP_BASE) && (I_wb_adr < ADDR_TEXT_BASE);
wire wb_text_sel = (I_wb_adr >= ADDR_TEXT_BASE) && (I_wb_adr < ADDR_FB_BASE);
wire wb_fb_sel   = (I_wb_adr >= ADDR_FB_BASE);

// ==============================================================================
// Instantiate HDMI PHY (always needed)
// ==============================================================================
wire pix_clk;
wire pix_clk_5x;
wire hdmi_rst_n;
wire [11:0] h_cnt, v_cnt;
wire [11:0] active_x, active_y;
wire phy_de, phy_hs, phy_vs;

// Video input to PHY (selected by mode mux)
reg [7:0] rgb_r, rgb_g, rgb_b;
reg       rgb_de, rgb_hs, rgb_vs;

hdmi_phy_720p u_hdmi_phy
(
    .I_clk          (I_clk          ),
    .I_rst_n        (I_rst_n        ),
    
    .I_rgb_r        (rgb_r          ),
    .I_rgb_g        (rgb_g          ),
    .I_rgb_b        (rgb_b          ),
    .I_rgb_de       (rgb_de         ),
    .I_rgb_hs       (rgb_hs         ),
    .I_rgb_vs       (rgb_vs         ),
    
    .O_pix_clk      (pix_clk        ),
    .O_pix_clk_5x   (pix_clk_5x     ),
    .O_hdmi_rst_n   (hdmi_rst_n     ),
    .O_h_cnt        (h_cnt          ),
    .O_v_cnt        (v_cnt          ),
    .O_de           (phy_de         ),
    .O_hs           (phy_hs         ),
    .O_vs           (phy_vs         ),
    .O_active_x     (active_x       ),
    .O_active_y     (active_y       ),
    
    .O_tmds_clk_p   (O_tmds_clk_p   ),
    .O_tmds_clk_n   (O_tmds_clk_n   ),
    .O_tmds_data_p  (O_tmds_data_p  ),
    .O_tmds_data_n  (O_tmds_data_n  )
);

// ==============================================================================
// Test Pattern Generator (Mode 0)
// ==============================================================================
wire tp_ack;
wire [7:0] tp_dat;
wire [7:0] tp_rgb_r, tp_rgb_g, tp_rgb_b;
wire tp_rgb_de, tp_rgb_hs, tp_rgb_vs;

wb_video_testpattern u_testpattern
(
    .I_wb_clk       (I_wb_clk       ),
    .I_wb_rst       (~I_rst_n       ),
    .I_wb_adr       (I_wb_adr[7:0] - ADDR_TP_BASE[7:0]),
    .I_wb_dat       (I_wb_dat       ),
    .I_wb_we        (I_wb_we        ),
    .I_wb_stb       (I_wb_stb && wb_tp_sel),
    .I_wb_cyc       (I_wb_cyc       ),
    .O_wb_ack       (tp_ack         ),
    .O_wb_dat       (tp_dat         ),
    
    .I_pix_clk      (pix_clk        ),
    .I_rst_n        (hdmi_rst_n     ),
    .I_active_x     (active_x       ),
    .I_active_y     (active_y       ),
    .I_de           (phy_de         ),
    .I_hs           (phy_hs         ),
    .I_vs           (phy_vs         ),
    
    .O_rgb_r        (tp_rgb_r       ),
    .O_rgb_g        (tp_rgb_g       ),
    .O_rgb_b        (tp_rgb_b       ),
    .O_rgb_de       (tp_rgb_de      ),
    .O_rgb_hs       (tp_rgb_hs      ),
    .O_rgb_vs       (tp_rgb_vs      )
);

// ==============================================================================
// Text Mode (Mode 1)
// ==============================================================================
wire text_ack;
wire [7:0] text_dat;
wire [7:0] text_rgb_r, text_rgb_g, text_rgb_b;
wire text_rgb_de, text_rgb_hs, text_rgb_vs;

wb_video_text u_text_mode
(
    .I_wb_clk       (I_wb_clk       ),
    .I_wb_rst       (~I_rst_n       ),
    .I_wb_adr       (I_wb_adr[7:0] - ADDR_TEXT_BASE[7:0]),
    .I_wb_dat       (I_wb_dat       ),
    .I_wb_we        (I_wb_we        ),
    .I_wb_stb       (I_wb_stb && wb_text_sel),
    .I_wb_cyc       (I_wb_cyc       ),
    .O_wb_ack       (text_ack       ),
    .O_wb_dat       (text_dat       ),
    
    .I_pix_clk      (pix_clk        ),
    .I_rst_n        (hdmi_rst_n     ),
    .I_active_x     (active_x       ),
    .I_active_y     (active_y       ),
    .I_de           (phy_de         ),
    .I_hs           (phy_hs         ),
    .I_vs           (phy_vs         ),
    
    .O_rgb_r        (text_rgb_r     ),
    .O_rgb_g        (text_rgb_g     ),
    .O_rgb_b        (text_rgb_b     ),
    .O_rgb_de       (text_rgb_de    ),
    .O_rgb_hs       (text_rgb_hs    ),
    .O_rgb_vs       (text_rgb_vs    )
);

// ==============================================================================
// Framebuffer Mode (Mode 2)
// ==============================================================================
wire fb_ack;
wire [7:0] fb_dat;
wire [7:0] fb_rgb_r, fb_rgb_g, fb_rgb_b;
wire fb_rgb_de, fb_rgb_hs, fb_rgb_vs;

wb_video_framebuffer u_framebuffer
(
    .I_wb_clk       (I_wb_clk       ),
    .I_wb_rst       (~I_rst_n       ),
    .I_wb_adr       (I_wb_adr[14:0] - ADDR_FB_BASE[14:0]),
    .I_wb_dat       (I_wb_dat       ),
    .I_wb_we        (I_wb_we        ),
    .I_wb_stb       (I_wb_stb && wb_fb_sel),
    .I_wb_cyc       (I_wb_cyc       ),
    .O_wb_ack       (fb_ack         ),
    .O_wb_dat       (fb_dat         ),
    
    .I_pix_clk      (pix_clk        ),
    .I_rst_n        (hdmi_rst_n     ),
    .I_h_cnt        (h_cnt          ),
    .I_v_cnt        (v_cnt          ),
    .I_active_x     (active_x       ),
    .I_active_y     (active_y       ),
    .I_de           (phy_de         ),
    .I_hs           (phy_hs         ),
    .I_vs           (phy_vs         ),
    
    .O_rgb_r        (fb_rgb_r       ),
    .O_rgb_g        (fb_rgb_g       ),
    .O_rgb_b        (fb_rgb_b       ),
    .O_rgb_de       (fb_rgb_de      ),
    .O_rgb_hs       (fb_rgb_hs      ),
    .O_rgb_vs       (fb_rgb_vs      )
);

// ==============================================================================
// Video Mode Multiplexer
// ==============================================================================
reg [1:0] video_mode_sync;
always @(posedge pix_clk or negedge hdmi_rst_n) begin
    if (!hdmi_rst_n)
        video_mode_sync <= 2'd0;
    else
        video_mode_sync <= video_mode;
end

always @(posedge pix_clk or negedge hdmi_rst_n) begin
    if (!hdmi_rst_n) begin
        rgb_r  <= 8'd0;
        rgb_g  <= 8'd0;
        rgb_b  <= 8'd0;
        rgb_de <= 1'b0;
        rgb_hs <= 1'b0;
        rgb_vs <= 1'b0;
    end else begin
        case (video_mode_sync)
            2'd0: begin  // Test pattern
                rgb_r  <= tp_rgb_r;
                rgb_g  <= tp_rgb_g;
                rgb_b  <= tp_rgb_b;
                rgb_de <= tp_rgb_de;
                rgb_hs <= tp_rgb_hs;
                rgb_vs <= tp_rgb_vs;
            end
            2'd1: begin  // Text mode
                rgb_r  <= text_rgb_r;
                rgb_g  <= text_rgb_g;
                rgb_b  <= text_rgb_b;
                rgb_de <= text_rgb_de;
                rgb_hs <= text_rgb_hs;
                rgb_vs <= text_rgb_vs;
            end
            2'd2: begin  // Framebuffer
                rgb_r  <= fb_rgb_r;
                rgb_g  <= fb_rgb_g;
                rgb_b  <= fb_rgb_b;
                rgb_de <= fb_rgb_de;
                rgb_hs <= fb_rgb_hs;
                rgb_vs <= fb_rgb_vs;
            end
            default: begin  // Default to test pattern
                rgb_r  <= tp_rgb_r;
                rgb_g  <= tp_rgb_g;
                rgb_b  <= tp_rgb_b;
                rgb_de <= tp_rgb_de;
                rgb_hs <= tp_rgb_hs;
                rgb_vs <= tp_rgb_vs;
            end
        endcase
    end
end

// ==============================================================================
// Wishbone Response Multiplexer
// ==============================================================================
wire mode_ack = wb_mode_sel && I_wb_stb && I_wb_cyc;

always @(posedge I_wb_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
        video_mode <= 2'd0;
        O_wb_ack <= 1'b0;
        O_wb_dat <= 8'd0;
    end else begin
        // Mode register access
        if (wb_mode_sel && I_wb_stb && I_wb_cyc) begin
            if (I_wb_we)
                video_mode <= I_wb_dat[1:0];
            O_wb_dat <= {6'b0, video_mode};
            O_wb_ack <= !O_wb_ack;
        end
        // Mux sub-module responses
        else if (wb_tp_sel) begin
            O_wb_ack <= tp_ack;
            O_wb_dat <= tp_dat;
        end
        else if (wb_text_sel) begin
            O_wb_ack <= text_ack;
            O_wb_dat <= text_dat;
        end
        else if (wb_fb_sel) begin
            O_wb_ack <= fb_ack;
            O_wb_dat <= fb_dat;
        end
        else begin
            O_wb_ack <= 1'b0;
            O_wb_dat <= 8'd0;
        end
    end
end

endmodule
