// ==============================================================================
// video_top_testpattern_only.v - Minimal test pattern example
// ==============================================================================
// This example shows how to create a minimal design with only test patterns.
// No text or framebuffer resources are used.
// ==============================================================================

module video_top_testpattern_only
(
    // System
    input             I_clk           , // 27MHz system clock
    input             I_rst_n         ,
    
    // Wishbone slave interface 
    input             I_wb_clk        ,
    input      [7:0]  I_wb_adr        ,
    input      [7:0]  I_wb_dat        ,
    input             I_wb_we         ,
    input             I_wb_stb        ,
    input             I_wb_cyc        ,
    output            O_wb_ack        ,
    output     [7:0]  O_wb_dat        ,
    
    // HDMI output
    output            O_tmds_clk_p    ,
    output            O_tmds_clk_n    ,
    output     [2:0]  O_tmds_data_p   ,
    output     [2:0]  O_tmds_data_n   
);

// ==============================================================================
// HDMI PHY
// ==============================================================================
wire pix_clk;
wire pix_clk_5x;
wire hdmi_rst_n;
wire [11:0] active_x, active_y;
wire phy_de, phy_hs, phy_vs;

wire [7:0] rgb_r, rgb_g, rgb_b;
wire       rgb_de, rgb_hs, rgb_vs;

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
    .O_h_cnt        (               ), // Not used
    .O_v_cnt        (               ), // Not used
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
// Test Pattern Generator
// ==============================================================================
wb_video_testpattern u_testpattern
(
    .I_wb_clk       (I_wb_clk       ),
    .I_wb_rst       (~I_rst_n       ),
    .I_wb_adr       (I_wb_adr       ),
    .I_wb_dat       (I_wb_dat       ),
    .I_wb_we        (I_wb_we        ),
    .I_wb_stb       (I_wb_stb       ),
    .I_wb_cyc       (I_wb_cyc       ),
    .O_wb_ack       (O_wb_ack       ),
    .O_wb_dat       (O_wb_dat       ),
    
    .I_pix_clk      (pix_clk        ),
    .I_rst_n        (hdmi_rst_n     ),
    .I_active_x     (active_x       ),
    .I_active_y     (active_y       ),
    .I_de           (phy_de         ),
    .I_hs           (phy_hs         ),
    .I_vs           (phy_vs         ),
    
    .O_rgb_r        (rgb_r          ),
    .O_rgb_g        (rgb_g          ),
    .O_rgb_b        (rgb_b          ),
    .O_rgb_de       (rgb_de         ),
    .O_rgb_hs       (rgb_hs         ),
    .O_rgb_vs       (rgb_vs         )
);

endmodule
