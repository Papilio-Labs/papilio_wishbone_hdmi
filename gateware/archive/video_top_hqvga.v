// ==============================================================================
// video_top_hqvga.v - HDMI output for HQVGA 160x120 content scaled to 720p
// ==============================================================================
// Takes HQVGA VGA signals (running at 50MHz, 800x600@72Hz) and outputs 720p HDMI
// HQVGA 160x120 is scaled 6x to 960x720, centered in 1280x720 (160px black bars)
//
// Architecture:
// - HQVGA outputs 800x600 but the actual content is 160x120 scaled 5x
// - We sample the HQVGA output and rescale for 720p
// - Uses line buffer to cross clock domains (50MHz → 74.25MHz)
// ==============================================================================

module video_top_hqvga
(
    input             I_clk           , // 27MHz reference clock
    input             I_rst_n         ,
    
    // HQVGA VGA input (active high signals, active region only)
    input             I_hqvga_clk     , // 50MHz pixel clock from HQVGA
    input             I_hqvga_de      , // Display enable
    input             I_hqvga_vs      , // VSync (active high)
    input             I_hqvga_hs      , // HSync (active high)
    input      [2:0]  I_hqvga_r       , // Red 3-bit
    input      [2:0]  I_hqvga_g       , // Green 3-bit  
    input      [1:0]  I_hqvga_b       , // Blue 2-bit
    
    // HDMI TMDS outputs
    output            O_tmds_clk_p    ,
    output            O_tmds_clk_n    ,
    output     [2:0]  O_tmds_data_p   , // {r,g,b}
    output     [2:0]  O_tmds_data_n   
);

// ==============================================================================
// Parameters for 720p output timing
// ==============================================================================
localparam H_TOTAL    = 12'd1650;  // Total horizontal pixels
localparam H_SYNC     = 12'd40;    // HSync width
localparam H_BPORCH   = 12'd220;   // Horizontal back porch
localparam H_ACTIVE   = 12'd1280;  // Active horizontal pixels
localparam V_TOTAL    = 12'd750;   // Total vertical lines
localparam V_SYNC     = 12'd5;     // VSync width
localparam V_BPORCH   = 12'd20;    // Vertical back porch
localparam V_ACTIVE   = 12'd720;   // Active vertical lines

// HQVGA content parameters
localparam HQVGA_WIDTH  = 160;
localparam HQVGA_HEIGHT = 120;
localparam SCALE        = 6;       // 160x6=960, 120x6=720
localparam SCALED_WIDTH = HQVGA_WIDTH * SCALE;  // 960
localparam SCALED_HEIGHT = HQVGA_HEIGHT * SCALE; // 720
localparam H_OFFSET     = (H_ACTIVE - SCALED_WIDTH) / 2; // 160 pixels black bar each side

// ==============================================================================
// PLL and clock generation - 720p timing (74.25 MHz pixel clock)
// ==============================================================================
wire serial_clk;
wire pll_lock;
wire pix_clk;
wire hdmi_rst_n;

// Generate 371.25 MHz serial clock from 27 MHz
TMDS_rPLL u_tmds_rpll
(
    .clkin  (I_clk      ),
    .clkout (serial_clk ),
    .lock   (pll_lock   )
);

assign hdmi_rst_n = I_rst_n & pll_lock;

// Divide by 5 to get 74.25 MHz pixel clock
CLKDIV u_clkdiv
(
    .RESETN (hdmi_rst_n ),
    .HCLKIN (serial_clk ),
    .CLKOUT (pix_clk    ),
    .CALIB  (1'b1       )
);
defparam u_clkdiv.DIV_MODE = "5";
defparam u_clkdiv.GSREN = "false";

// ==============================================================================
// 720p timing generator
// ==============================================================================
reg [11:0] h_cnt;
reg [11:0] v_cnt;
reg        hdmi_vs;
reg        hdmi_hs;
reg        hdmi_de;

always @(posedge pix_clk or negedge hdmi_rst_n) begin
    if (!hdmi_rst_n) begin
        h_cnt <= 12'd0;
        v_cnt <= 12'd0;
    end else begin
        if (h_cnt >= H_TOTAL - 1) begin
            h_cnt <= 12'd0;
            if (v_cnt >= V_TOTAL - 1)
                v_cnt <= 12'd0;
            else
                v_cnt <= v_cnt + 1'b1;
        end else begin
            h_cnt <= h_cnt + 1'b1;
        end
    end
end

// Generate sync signals (active high for 720p)
always @(posedge pix_clk or negedge hdmi_rst_n) begin
    if (!hdmi_rst_n) begin
        hdmi_hs <= 1'b0;
        hdmi_vs <= 1'b0;
        hdmi_de <= 1'b0;
    end else begin
        // HSync: active during h_cnt < H_SYNC
        hdmi_hs <= (h_cnt < H_SYNC);
        
        // VSync: active during v_cnt < V_SYNC  
        hdmi_vs <= (v_cnt < V_SYNC);
        
        // Display enable: active area
        hdmi_de <= (h_cnt >= H_SYNC + H_BPORCH) && 
                   (h_cnt < H_SYNC + H_BPORCH + H_ACTIVE) &&
                   (v_cnt >= V_SYNC + V_BPORCH) && 
                   (v_cnt < V_SYNC + V_BPORCH + V_ACTIVE);
    end
end

// ==============================================================================
// Line buffer for clock domain crossing
// Store one line of HQVGA (160 pixels, 8-bit RGB332)
// ==============================================================================
reg [7:0] line_buf [0:HQVGA_WIDTH-1];

// HQVGA input tracking (50 MHz domain)
reg [9:0] hqvga_x;      // X position in 800x600 space
reg [9:0] hqvga_y;      // Y position in 800x600 space
reg       hqvga_de_d;
reg       hqvga_vs_d;
wire      hqvga_de_rise = I_hqvga_de && !hqvga_de_d;
wire      hqvga_vs_fall = !I_hqvga_vs && hqvga_vs_d;

// Capture HQVGA position (sample every 5 pixels = 160 from 800)
always @(posedge I_hqvga_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
        hqvga_x <= 10'd0;
        hqvga_y <= 10'd0;
        hqvga_de_d <= 1'b0;
        hqvga_vs_d <= 1'b0;
    end else begin
        hqvga_de_d <= I_hqvga_de;
        hqvga_vs_d <= I_hqvga_vs;
        
        // VSync resets Y counter
        if (hqvga_vs_fall) begin
            hqvga_y <= 10'd0;
        end
        
        // Track X position during active video
        if (I_hqvga_de) begin
            hqvga_x <= hqvga_x + 1'b1;
        end else begin
            if (hqvga_de_d && !I_hqvga_de) begin
                // End of line - increment Y
                hqvga_y <= hqvga_y + 1'b1;
            end
            hqvga_x <= 10'd0;
        end
    end
end

// Write to line buffer - sample every 5th pixel to get 160 from 800
// HQVGA displays 160x120 scaled 5x to 800x600
wire [6:0] sample_x = hqvga_x[9:3]; // Divide by 5 approximation (using /8 for simplicity, will adjust)
wire sample_valid = I_hqvga_de && (hqvga_x[2:0] == 3'd2); // Sample in middle of each 5-pixel group

// Actually, let's be more precise: sample at x=2, 7, 12, 17... (every 5)
wire [7:0] hqvga_pixel = {I_hqvga_r, I_hqvga_g, I_hqvga_b};
reg [2:0] sample_cnt;
reg [7:0] write_addr;

always @(posedge I_hqvga_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
        sample_cnt <= 3'd0;
        write_addr <= 8'd0;
    end else begin
        if (!I_hqvga_de) begin
            sample_cnt <= 3'd0;
            write_addr <= 8'd0;
        end else begin
            if (sample_cnt == 3'd4) begin
                sample_cnt <= 3'd0;
                // Write pixel to line buffer
                if (write_addr < HQVGA_WIDTH) begin
                    line_buf[write_addr] <= hqvga_pixel;
                    write_addr <= write_addr + 1'b1;
                end
            end else begin
                sample_cnt <= sample_cnt + 1'b1;
            end
        end
    end
end

// ==============================================================================
// Read from line buffer and scale for 720p output
// ==============================================================================
wire [11:0] active_x = h_cnt - (H_SYNC + H_BPORCH);
wire [11:0] active_y = v_cnt - (V_SYNC + V_BPORCH);

// Check if we're in the scaled HQVGA region (960x720 centered)
wire in_hqvga_region = (active_x >= H_OFFSET) && (active_x < H_OFFSET + SCALED_WIDTH);

// Calculate source pixel from HQVGA buffer
// active_x - H_OFFSET = 0..959, divide by 6 = 0..159
wire [7:0] src_x = (active_x - H_OFFSET) / SCALE;
wire [6:0] src_y = active_y / SCALE;  // 0..119

// Read from line buffer (synchronous to pix_clk domain)
// Note: This is a simplified approach - proper CDC would need a dual-port RAM
reg [7:0] read_pixel;
always @(posedge pix_clk) begin
    if (hdmi_de && in_hqvga_region && src_x < HQVGA_WIDTH)
        read_pixel <= line_buf[src_x];
    else
        read_pixel <= 8'd0;
end

// Expand RGB332 to RGB888
wire [7:0] hdmi_r = {read_pixel[7:5], read_pixel[7:5], read_pixel[7:6]};
wire [7:0] hdmi_g = {read_pixel[4:2], read_pixel[4:2], read_pixel[4:3]};
wire [7:0] hdmi_b = {read_pixel[1:0], read_pixel[1:0], read_pixel[1:0], read_pixel[1:0]};

// DEBUG: Simple test pattern - color bars based on horizontal position
// This tests that the 720p timing and DVI_TX_Top are working
wire [7:0] test_r = (active_x < 160) ? 8'd255 :   // Red
                    (active_x < 320) ? 8'd0 :     // Green
                    (active_x < 480) ? 8'd0 :     // Blue
                    (active_x < 640) ? 8'd255 :   // Yellow
                    (active_x < 800) ? 8'd255 :   // Magenta
                    (active_x < 960) ? 8'd0 :     // Cyan
                    (active_x < 1120) ? 8'd255 :  // White
                    8'd0;                          // Black

wire [7:0] test_g = (active_x < 160) ? 8'd0 :     // Red
                    (active_x < 320) ? 8'd255 :   // Green
                    (active_x < 480) ? 8'd0 :     // Blue
                    (active_x < 640) ? 8'd255 :   // Yellow
                    (active_x < 800) ? 8'd0 :     // Magenta
                    (active_x < 960) ? 8'd255 :   // Cyan
                    (active_x < 1120) ? 8'd255 :  // White
                    8'd0;                          // Black

wire [7:0] test_b = (active_x < 160) ? 8'd0 :     // Red
                    (active_x < 320) ? 8'd0 :     // Green
                    (active_x < 480) ? 8'd255 :   // Blue
                    (active_x < 640) ? 8'd0 :     // Yellow
                    (active_x < 800) ? 8'd255 :   // Magenta
                    (active_x < 960) ? 8'd255 :   // Cyan
                    (active_x < 1120) ? 8'd255 :  // White
                    8'd0;                          // Black

// Synchronize HQVGA RGB signals to pix_clk domain (CDC)
// These are slow-changing signals (hold for 5 pixels at 50MHz = ~100ns)
reg [2:0] hqvga_r_sync1, hqvga_r_sync2;
reg [2:0] hqvga_g_sync1, hqvga_g_sync2;
reg [1:0] hqvga_b_sync1, hqvga_b_sync2;

always @(posedge pix_clk) begin
    hqvga_r_sync1 <= I_hqvga_r;
    hqvga_r_sync2 <= hqvga_r_sync1;
    hqvga_g_sync1 <= I_hqvga_g;
    hqvga_g_sync2 <= hqvga_g_sync1;
    hqvga_b_sync1 <= I_hqvga_b;
    hqvga_b_sync2 <= hqvga_b_sync1;
end

// Expand synchronized RGB332 to RGB888
wire [7:0] hqvga_r8 = {hqvga_r_sync2, hqvga_r_sync2, hqvga_r_sync2[2:1]};
wire [7:0] hqvga_g8 = {hqvga_g_sync2, hqvga_g_sync2, hqvga_g_sync2[2:1]};
wire [7:0] hqvga_b8 = {hqvga_b_sync2, hqvga_b_sync2, hqvga_b_sync2, hqvga_b_sync2};

// Use HQVGA data in the center, black borders on sides
// CHANGED: Use synchronized HQVGA signals instead of test pattern
wire [7:0] out_r = hdmi_de ? (in_hqvga_region ? hqvga_r8 : 8'd0) : 8'd0;
wire [7:0] out_g = hdmi_de ? (in_hqvga_region ? hqvga_g8 : 8'd0) : 8'd0;
wire [7:0] out_b = hdmi_de ? (in_hqvga_region ? hqvga_b8 : 8'd0) : 8'd0;

// ==============================================================================
// DVI TX output
// ==============================================================================
DVI_TX_Top DVI_TX_Top_inst
(
    .I_rst_n       (hdmi_rst_n    ),
    .I_serial_clk  (serial_clk    ),
    .I_rgb_clk     (pix_clk       ),
    .I_rgb_vs      (hdmi_vs       ), 
    .I_rgb_hs      (hdmi_hs       ),    
    .I_rgb_de      (hdmi_de       ), 
    .I_rgb_r       (out_r         ),  
    .I_rgb_g       (out_g         ),  
    .I_rgb_b       (out_b         ),  
    .O_tmds_clk_p  (O_tmds_clk_p  ),
    .O_tmds_clk_n  (O_tmds_clk_n  ),
    .O_tmds_data_p (O_tmds_data_p ),
    .O_tmds_data_n (O_tmds_data_n )
);

endmodule
