// video_top_wb.v
// Wrapper for video_top with Wishbone pattern mode control
// Mode 0-2: Test patterns, Mode 3: Text mode (80x30 character display)

module video_top_wb
(
    input             I_clk           , //27Mhz
    input             I_rst_n         ,
    input [1:0]       I_pattern_mode  , // Pattern selection from Wishbone (0-3)
    
    // Text mode character RAM interface (connected externally to wb_char_ram)
    input      [7:0]  I_text_char_data,  // Character data from RAM
    output wire [10:0] O_text_char_addr,  // Address to character RAM (0-2047)
    
    // Custom font RAM interface (for LCD createChar support)
    input wire        I_custom_font_we,
    input wire [5:0]  I_custom_font_addr,
    input wire [7:0]  I_custom_font_data,
    
    output            O_tmds_clk_p    ,
    output            O_tmds_clk_n    ,
    output     [2:0]  O_tmds_data_p   ,//{r,g,b}
    output     [2:0]  O_tmds_data_n   
);

    // Internal wires
    reg  [31:0] run_cnt;
    wire        running;
    
    wire        tp0_vs_in  ;
    wire        tp0_hs_in  ;
    wire        tp0_de_in ;
    wire [ 7:0] tp0_data_r;
    wire [ 7:0] tp0_data_g;
    wire [ 7:0] tp0_data_b;
    
    // Text mode outputs
    wire [7:0] text_data_r;
    wire [7:0] text_data_g;
    wire [7:0] text_data_b;
    
    // Video mux - select between test pattern and text mode
    wire text_mode_active = (I_pattern_mode == 2'b11);  // Mode 3
    wire [7:0] video_r = text_mode_active ? text_data_r : tp0_data_r;
    wire [7:0] video_g = text_mode_active ? text_data_g : tp0_data_g;
    wire [7:0] video_b = text_mode_active ? text_data_b : tp0_data_b;
    
    reg         vs_r;
    reg  [9:0]  cnt_vs;
    
    wire serial_clk;
    wire pll_lock;
    wire hdmi4_rst_n;
    wire pix_clk;
    
    // LED test counter
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n)
            run_cnt <= 32'd0;
        else if(run_cnt >= 32'd27_000_000)
            run_cnt <= 32'd0;
        else
            run_cnt <= run_cnt + 1'b1;
    end
    
    assign running = (run_cnt < 32'd14_000_000) ? 1'b1 : 1'b0;
    
    // Test pattern generator with Wishbone mode control (modes 0-2)
    testpattern testpattern_inst
    (
        .I_pxl_clk   (pix_clk            ),
        .I_rst_n     (hdmi4_rst_n        ),
        .I_mode      ({1'b0, text_mode_active ? 2'b00 : I_pattern_mode}),  // Default to color bars in text mode
        .I_single_r  (8'd0               ),
        .I_single_g  (8'd255             ),
        .I_single_b  (8'd0               ),
        .I_h_total   (12'd1650           ),
        .I_h_sync    (12'd40             ),
        .I_h_bporch  (12'd220            ),
        .I_h_res     (12'd1280           ),
        .I_v_total   (12'd750            ),
        .I_v_sync    (12'd5              ),
        .I_v_bporch  (12'd20             ),
        .I_v_res     (12'd720            ),
        .I_hs_pol    (1'b1               ),
        .I_vs_pol    (1'b1               ),
        .O_de        (tp0_de_in          ),   
        .O_hs        (tp0_hs_in          ),
        .O_vs        (tp0_vs_in          ),
        .O_data_r    (tp0_data_r         ),   
        .O_data_g    (tp0_data_g         ),
        .O_data_b    (tp0_data_b         )
    );
    
    // Text mode generator (mode 3)
    // Create pixel counters for active video area (1280x720)
    reg [11:0] pixel_x;
    reg [11:0] pixel_y;
    reg        de_prev;
    reg        vs_prev;
    
    always @(posedge pix_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            pixel_x <= 0;
            pixel_y <= 0;
            de_prev <= 0;
            vs_prev <= 1;
        end else begin
            de_prev <= tp0_de_in;
            vs_prev <= tp0_vs_in;
            
            // Handle vertical sync - reset on falling edge
            if (vs_prev && !tp0_vs_in) begin
                pixel_y <= 0;
            end
            
            // Handle horizontal pixels
            if (tp0_de_in) begin
                // During active video, increment X
                if (pixel_x < 1279) begin
                    pixel_x <= pixel_x + 1;
                end else begin
                    pixel_x <= 0;
                end
            end else if (de_prev && !tp0_de_in) begin
                // Falling edge of DE - end of active line
                pixel_x <= 0;
                if (pixel_y < 719)
                    pixel_y <= pixel_y + 1;
            end
        end
    end
    
    // Text mode generator
    wire text_valid;
    wb_text_mode text_mode_inst (
        .clk(pix_clk),
        .rst_n(hdmi4_rst_n),
        .enable(text_mode_active),
        
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .video_active(tp0_de_in),
        
        .char_addr(O_text_char_addr),
        .char_data(I_text_char_data),
        
        .custom_font_we(I_custom_font_we),
        .custom_font_addr(I_custom_font_addr),
        .custom_font_data(I_custom_font_data),
        
        .text_r(text_data_r),
        .text_g(text_data_g),
        .text_b(text_data_b),
        .text_valid(text_valid)
    );
    
    always@(posedge pix_clk) begin
        vs_r <= tp0_vs_in;
    end
    
    always@(posedge pix_clk or negedge hdmi4_rst_n) begin
        if(!hdmi4_rst_n)
            cnt_vs <= 0;
        else if(vs_r && !tp0_vs_in)
            cnt_vs <= cnt_vs + 1'b1;
    end 
    
    // PLL for HDMI clocking
    TMDS_rPLL u_tmds_rpll
    (
        .clkin     (I_clk     ),
        .clkout    (serial_clk),
        .lock      (pll_lock  )
    );
    
    assign hdmi4_rst_n = I_rst_n & pll_lock;
    
    // Clock divider
    CLKDIV u_clkdiv
    (
        .RESETN(hdmi4_rst_n),
        .HCLKIN(serial_clk),
        .CLKOUT(pix_clk),
        .CALIB (1'b1)
    );
    defparam u_clkdiv.DIV_MODE="5";
    defparam u_clkdiv.GSREN="false";
    
    // Simple HDMI/DVI transmitter using our timing
    simple_hdmi_tx hdmi_tx (
        .clk_pixel(pix_clk),
        .clk_serial(serial_clk),
        .rst_n(hdmi4_rst_n),
        .video_r(video_r),
        .video_g(video_g),
        .video_b(video_b),
        .video_de(tp0_de_in),
        .video_hsync(tp0_hs_in),
        .video_vsync(tp0_vs_in),
        .tmds_clk_p(O_tmds_clk_p),
        .tmds_clk_n(O_tmds_clk_n),
        .tmds_data_p(O_tmds_data_p),
        .tmds_data_n(O_tmds_data_n)
    );

endmodule
