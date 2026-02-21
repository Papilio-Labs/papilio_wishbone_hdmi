// simple_hdmi_tx.v
// Simple HDMI/DVI transmitter using external timing and TMDS encoders
// Takes video timing and RGB data, outputs TMDS differential pairs

module simple_hdmi_tx (
    input wire clk_pixel,      // Pixel clock (74.25 MHz for 720p)
    input wire clk_serial,     // Serial clock (5x pixel clock = 371.25 MHz)
    input wire rst_n,
    
    // Video input with timing
    input wire [7:0] video_r,
    input wire [7:0] video_g,
    input wire [7:0] video_b,
    input wire video_de,       // Data enable (active video)
    input wire video_hsync,
    input wire video_vsync,
    
    // TMDS differential outputs
    output wire tmds_clk_p,
    output wire tmds_clk_n,
    output wire [2:0] tmds_data_p,
    output wire [2:0] tmds_data_n
);

    // TMDS encoded data (10-bit per channel)
    wire [9:0] tmds_r, tmds_g, tmds_b;
    
    // TMDS encoders for each color channel
    tmds_encoder enc_r (
        .clk(clk_pixel),
        .rst(~rst_n),
        .video_active(video_de),
        .data_in(video_r),
        .c0(1'b0),
        .c1(1'b0),
        .tmds_out(tmds_r)
    );
    
    tmds_encoder enc_g (
        .clk(clk_pixel),
        .rst(~rst_n),
        .video_active(video_de),
        .data_in(video_g),
        .c0(1'b0),
        .c1(1'b0),
        .tmds_out(tmds_g)
    );
    
    tmds_encoder enc_b (
        .clk(clk_pixel),
        .rst(~rst_n),
        .video_active(video_de),
        .data_in(video_b),
        .c0(video_hsync),  // Blue channel carries sync signals
        .c1(video_vsync),
        .tmds_out(tmds_b)
    );
    
    // Serialize the 10-bit TMDS data (using OSER10 primitives)
    wire [2:0] tmds_serial;
    wire tmds_clk_serial;
    
    // Serializer for red channel
    OSER10 oser_r (
        .D0(tmds_r[0]),
        .D1(tmds_r[1]),
        .D2(tmds_r[2]),
        .D3(tmds_r[3]),
        .D4(tmds_r[4]),
        .D5(tmds_r[5]),
        .D6(tmds_r[6]),
        .D7(tmds_r[7]),
        .D8(tmds_r[8]),
        .D9(tmds_r[9]),
        .PCLK(clk_pixel),
        .FCLK(clk_serial),
        .RESET(~rst_n),
        .Q(tmds_serial[2])  // Red = data[2]
    );
    
    // Serializer for green channel
    OSER10 oser_g (
        .D0(tmds_g[0]),
        .D1(tmds_g[1]),
        .D2(tmds_g[2]),
        .D3(tmds_g[3]),
        .D4(tmds_g[4]),
        .D5(tmds_g[5]),
        .D6(tmds_g[6]),
        .D7(tmds_g[7]),
        .D8(tmds_g[8]),
        .D9(tmds_g[9]),
        .PCLK(clk_pixel),
        .FCLK(clk_serial),
        .RESET(~rst_n),
        .Q(tmds_serial[1])  // Green = data[1]
    );
    
    // Serializer for blue channel
    OSER10 oser_b (
        .D0(tmds_b[0]),
        .D1(tmds_b[1]),
        .D2(tmds_b[2]),
        .D3(tmds_b[3]),
        .D4(tmds_b[4]),
        .D5(tmds_b[5]),
        .D6(tmds_b[6]),
        .D7(tmds_b[7]),
        .D8(tmds_b[8]),
        .D9(tmds_b[9]),
        .PCLK(clk_pixel),
        .FCLK(clk_serial),
        .RESET(~rst_n),
        .Q(tmds_serial[0])  // Blue = data[0]
    );
    
    // TMDS clock is just the pixel clock (no serialization needed)
    // Differential output buffers
    ELVDS_OBUF tmds_clk_obuf (
        .I(clk_pixel),
        .O(tmds_clk_p),
        .OB(tmds_clk_n)
    );
    
    ELVDS_OBUF tmds_d0_obuf (
        .I(tmds_serial[0]),
        .O(tmds_data_p[0]),
        .OB(tmds_data_n[0])
    );
    
    ELVDS_OBUF tmds_d1_obuf (
        .I(tmds_serial[1]),
        .O(tmds_data_p[1]),
        .OB(tmds_data_n[1])
    );
    
    ELVDS_OBUF tmds_d2_obuf (
        .I(tmds_serial[2]),
        .O(tmds_data_p[2]),
        .OB(tmds_data_n[2])
    );

endmodule
