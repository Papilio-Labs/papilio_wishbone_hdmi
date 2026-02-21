// wb_hdmi_colorbar.v
// Wishbone slave for HDMI color bar generator
// Register map:
// 0x10: Control register (bit 0: enable color bars)

module wb_hdmi_colorbar (
    input wire clk,
    input wire clk_pixel,  // Pixel clock for HDMI (25.175 MHz or approximation)
    input wire rst,
    
    // Wishbone interface
    input wire [7:0] wb_adr_i,
    input wire [7:0] wb_dat_i,
    output reg [7:0] wb_dat_o,
    input wire wb_cyc_i,
    input wire wb_stb_i,
    input wire wb_we_i,
    output reg wb_ack_o,
    
    // HDMI outputs
    output wire hdmi_clk_p,
    output wire hdmi_clk_n,
    output wire hdmi_d0_p,
    output wire hdmi_d0_n,
    output wire hdmi_d1_p,
    output wire hdmi_d1_n,
    output wire hdmi_d2_p,
    output wire hdmi_d2_n
);

    // Control register
    reg enable;
    
    // Wishbone interface
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            enable <= 1'b1;  // Enable by default
            wb_ack_o <= 0;
            wb_dat_o <= 0;
        end else begin
            wb_ack_o <= wb_cyc_i && wb_stb_i && !wb_ack_o;
            
            if (wb_cyc_i && wb_stb_i && wb_we_i && !wb_ack_o) begin
                // Write
                if (wb_adr_i == 8'h10)
                    enable <= wb_dat_i[0];
            end else if (wb_cyc_i && wb_stb_i && !wb_we_i && !wb_ack_o) begin
                // Read
                if (wb_adr_i == 8'h10)
                    wb_dat_o <= {7'b0, enable};
                else
                    wb_dat_o <= 8'h00;
            end
        end
    end
    
    // HDMI timing generator
    wire hsync, vsync, video_active;
    wire [9:0] pixel_x, pixel_y;
    
    hdmi_timing u_timing (
        .clk_pixel(clk_pixel),
        .rst(rst),
        .hsync(hsync),
        .vsync(vsync),
        .video_active(video_active),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y)
    );
    
    // Color bar generator
    wire [7:0] red, green, blue;
    
    color_bar_generator u_colorbar (
        .clk(clk_pixel),
        .video_active(video_active),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .enable(enable),
        .red(red),
        .green(green),
        .blue(blue)
    );
    
    // TMDS encoders
    wire [9:0] tmds_ch0, tmds_ch1, tmds_ch2;
    
    tmds_encoder u_encoder_ch0 (
        .clk(clk_pixel),
        .rst(rst),
        .video_active(video_active),
        .data_in(blue),
        .c0(hsync),
        .c1(vsync),
        .tmds_out(tmds_ch0)
    );
    
    tmds_encoder u_encoder_ch1 (
        .clk(clk_pixel),
        .rst(rst),
        .video_active(video_active),
        .data_in(green),
        .c0(1'b0),
        .c1(1'b0),
        .tmds_out(tmds_ch1)
    );
    
    tmds_encoder u_encoder_ch2 (
        .clk(clk_pixel),
        .rst(rst),
        .video_active(video_active),
        .data_in(red),
        .c0(1'b0),
        .c1(1'b0),
        .tmds_out(tmds_ch2)
    );
    
    // TMDS shift registers for serialization (10:1)
    // We need 10x pixel clock for proper TMDS serialization
    // For simplicity, we'll output parallel data here and would need
    // a proper serializer (OSERDES) in a real implementation
    
    // For now, just output the LSB of TMDS data as a placeholder
    // In production, you'd use LVDS OSERDES primitives
    reg [9:0] shift_ch0, shift_ch1, shift_ch2, shift_clk;
    reg [3:0] bit_counter;
    
    always @(posedge clk_pixel or posedge rst) begin
        if (rst) begin
            shift_ch0 <= 10'b1101010100;
            shift_ch1 <= 10'b1101010100;
            shift_ch2 <= 10'b1101010100;
            shift_clk <= 10'b0000011111;
            bit_counter <= 0;
        end else begin
            if (bit_counter == 9) begin
                shift_ch0 <= tmds_ch0;
                shift_ch1 <= tmds_ch1;
                shift_ch2 <= tmds_ch2;
                shift_clk <= 10'b0000011111;
                bit_counter <= 0;
            end else begin
                shift_ch0 <= {1'b0, shift_ch0[9:1]};
                shift_ch1 <= {1'b0, shift_ch1[9:1]};
                shift_ch2 <= {1'b0, shift_ch2[9:1]};
                shift_clk <= {1'b0, shift_clk[9:1]};
                bit_counter <= bit_counter + 1;
            end
        end
    end
    
    // Output differential pairs
    // Note: For proper HDMI, you'd need LVDS output buffers (TLVDS_OBUF or similar)
    assign hdmi_d0_p = shift_ch0[0];
    assign hdmi_d0_n = ~shift_ch0[0];
    assign hdmi_d1_p = shift_ch1[0];
    assign hdmi_d1_n = ~shift_ch1[0];
    assign hdmi_d2_p = shift_ch2[0];
    assign hdmi_d2_n = ~shift_ch2[0];
    assign hdmi_clk_p = shift_clk[0];
    assign hdmi_clk_n = ~shift_clk[0];
    
endmodule
