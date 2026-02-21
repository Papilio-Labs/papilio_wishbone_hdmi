// ==============================================================================
// video_top_framebuffer.v - HDMI output with built-in 160x120 framebuffer
// ==============================================================================
// Drop-in replacement for HQVGA VGA output, but outputs 720p HDMI directly.
// Maintains same Wishbone interface as HQVGA for ESP32 compatibility.
//
// Features:
// - 160x120 pixel framebuffer (19,200 bytes, RGB332 format)
// - Scaled 6x to 960x720, centered in 1280x720 with 160px black bars each side
// - 720p@60Hz HDMI output using DVI_TX_Top IP
// - Wishbone slave interface compatible with HQVGA library
//
// Memory Map:
// - Address 0x0000-0x4AFF: Pixel data (160*120 = 19,200 pixels)
// - Pixel at (x,y) = address y*160 + x
// - Each pixel is 8-bit RGB332: RRRGGGBB
// ==============================================================================

module video_top_framebuffer
(
    // Reference clock
    input             I_clk           , // 27MHz reference clock
    input             I_rst_n         ,
    
    // Wishbone slave interface (directly from SPI bridge, no decoder needed)
    input             I_wb_clk        , // Wishbone clock
    input             I_wb_rst        , // Wishbone reset
    input      [14:0] I_wb_adr        , // Address (15-bit for 19,200 pixels)
    input      [7:0]  I_wb_dat        , // Write data (8-bit RGB332)
    input             I_wb_we         , // Write enable
    input             I_wb_stb        , // Strobe
    input             I_wb_cyc        , // Cycle
    output reg        O_wb_ack        , // Acknowledge
    output     [7:0]  O_wb_dat        , // Read data
    
    // HDMI TMDS outputs
    output            O_tmds_clk_p    ,
    output            O_tmds_clk_n    ,
    output     [2:0]  O_tmds_data_p   , // {r,g,b}
    output     [2:0]  O_tmds_data_n   ,
    
    // Debug outputs (directly readable status)
    output     [31:0] O_debug_status  , // {frame_count[15:0], v_cnt[7:0], h_cnt[7:0]}
    output     [31:0] O_debug_wb      , // {write_count[15:0], last_addr[15:0]}
    output     [31:0] O_debug_read      // {read_count[15:0], last_read_addr[15:0]}
);

// ==============================================================================
// Parameters
// ==============================================================================
// 720p timing
localparam H_TOTAL    = 12'd1650;
localparam H_SYNC     = 12'd40;
localparam H_BPORCH   = 12'd220;
localparam H_ACTIVE   = 12'd1280;
localparam V_TOTAL    = 12'd750;
localparam V_SYNC     = 12'd5;
localparam V_BPORCH   = 12'd20;
localparam V_ACTIVE   = 12'd720;

// Framebuffer parameters
localparam FB_WIDTH   = 160;
localparam FB_HEIGHT  = 120;
localparam FB_SIZE    = FB_WIDTH * FB_HEIGHT;  // 19,200 pixels
localparam SCALE      = 6;                      // 160x6=960, 120x6=720
localparam SCALED_W   = FB_WIDTH * SCALE;       // 960
localparam SCALED_H   = FB_HEIGHT * SCALE;      // 720
localparam H_OFFSET   = (H_ACTIVE - SCALED_W) / 2;  // 160

// ==============================================================================
// PLL and clock generation - 720p timing (74.25 MHz pixel clock)
// ==============================================================================
wire serial_clk;
wire pll_lock;
wire pix_clk;
wire hdmi_rst_n;

TMDS_rPLL u_tmds_rpll
(
    .clkin  (I_clk      ),
    .clkout (serial_clk ),
    .lock   (pll_lock   )
);

assign hdmi_rst_n = I_rst_n & pll_lock;

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
// Dual-port framebuffer RAM
// Port A: Wishbone write/read (ESP32 access)
// Port B: HDMI read (pixel clock domain)
// ==============================================================================

// Gowin SDPB (Simple Dual Port Block RAM) - one write port, one read port
// For 19,200 x 8-bit we need ~20KB = multiple BSRAM blocks

// Declare framebuffer as register array (synthesizer will infer BRAM)
reg [7:0] framebuffer [0:FB_SIZE-1];

// RAM initializes to 0 by default (black screen)

// Port A: Wishbone interface
wire wb_valid = I_wb_stb && I_wb_cyc;
// HQVGA library uses word-aligned addressing (pixel * 4), so divide by 4
wire [14:0] wb_pixel_addr = I_wb_adr[14:2];  // Shift right by 2 = divide by 4

// Wishbone write
always @(posedge I_wb_clk) begin
    if (wb_valid && I_wb_we && wb_pixel_addr < FB_SIZE) begin
        framebuffer[wb_pixel_addr] <= I_wb_dat;
    end
end

// Wishbone read
reg [7:0] wb_read_data;
always @(posedge I_wb_clk) begin
    if (wb_valid && !I_wb_we && wb_pixel_addr < FB_SIZE) begin
        wb_read_data <= framebuffer[wb_pixel_addr];
    end
end
assign O_wb_dat = wb_read_data;

// Wishbone ACK - one cycle delay for reads, immediate for writes
reg wb_valid_d;
always @(posedge I_wb_clk or posedge I_wb_rst) begin
    if (I_wb_rst) begin
        O_wb_ack <= 1'b0;
        wb_valid_d <= 1'b0;
    end else begin
        wb_valid_d <= wb_valid && !I_wb_we;  // Track reads
        // ACK immediately for writes, delayed for reads
        O_wb_ack <= (wb_valid && I_wb_we) || wb_valid_d;
    end
end

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

always @(posedge pix_clk or negedge hdmi_rst_n) begin
    if (!hdmi_rst_n) begin
        hdmi_hs <= 1'b0;
        hdmi_vs <= 1'b0;
        hdmi_de <= 1'b0;
    end else begin
        hdmi_hs <= (h_cnt < H_SYNC);
        hdmi_vs <= (v_cnt < V_SYNC);
        hdmi_de <= (h_cnt >= H_SYNC + H_BPORCH) && 
                   (h_cnt < H_SYNC + H_BPORCH + H_ACTIVE) &&
                   (v_cnt >= V_SYNC + V_BPORCH) && 
                   (v_cnt < V_SYNC + V_BPORCH + V_ACTIVE);
    end
end

// ==============================================================================
// Framebuffer read and scaling for HDMI output
// Uses counter-based approach (like original HQVGA) to avoid timing issues
// ==============================================================================

// Framebuffer display region within 1280x720 active area
// We center 960x720 (160x120 scaled 6x) with 160 pixel borders on each side
localparam FB_X_START = 160;   // Start X position in active area
localparam FB_X_END   = 1120;  // End X position (160 + 960)
localparam FB_Y_END   = 720;   // Full height used

// Counter-based scaling: count 0-5 for each source pixel
reg [2:0] h_scale_cnt;   // Horizontal scale counter (0-5)
reg [2:0] v_scale_cnt;   // Vertical scale counter (0-5)
reg [7:0] src_x;         // Source framebuffer X (0-159)
reg [6:0] src_y;         // Source framebuffer Y (0-119)

// Calculate active area position
wire in_active = (h_cnt >= H_SYNC + H_BPORCH) && (h_cnt < H_SYNC + H_BPORCH + H_ACTIVE) &&
                 (v_cnt >= V_SYNC + V_BPORCH) && (v_cnt < V_SYNC + V_BPORCH + V_ACTIVE);

wire [11:0] active_x = h_cnt - 12'd260;  // H_SYNC + H_BPORCH = 40 + 220 = 260

// Check if we're in the scaled framebuffer region
wire in_fb_region = in_active && 
                    (active_x >= FB_X_START) && (active_x < FB_X_END);

// Track if we're about to enter framebuffer region (for lookahead)
wire fb_region_start = in_active && (active_x == FB_X_START);

// Horizontal pixel counter with 6x scaling
always @(posedge pix_clk or negedge hdmi_rst_n) begin
    if (!hdmi_rst_n) begin
        h_scale_cnt <= 3'd0;
        src_x <= 8'd0;
    end else begin
        // Reset at end of each line (before framebuffer region)
        if (h_cnt == H_SYNC + H_BPORCH + FB_X_START - 1) begin
            // Reset at start of framebuffer region
            h_scale_cnt <= 3'd0;
            src_x <= 8'd0;
        end else if (in_fb_region && src_x < 8'd160) begin
            if (h_scale_cnt == 3'd5) begin
                h_scale_cnt <= 3'd0;
                src_x <= src_x + 1'b1;
            end else begin
                h_scale_cnt <= h_scale_cnt + 1'b1;
            end
        end
    end
end

// Track horizontal sync for vertical counter
reg h_sync_prev;
wire h_sync_tick = !hdmi_hs && h_sync_prev;  // Falling edge of hsync
always @(posedge pix_clk) h_sync_prev <= hdmi_hs;

// Vertical pixel counter with 6x scaling
always @(posedge pix_clk or negedge hdmi_rst_n) begin
    if (!hdmi_rst_n) begin
        v_scale_cnt <= 3'd0;
        src_y <= 7'd0;
    end else begin
        if (v_cnt == V_SYNC + V_BPORCH - 1 && h_cnt == 0) begin
            // Reset at start of active video
            v_scale_cnt <= 3'd0;
            src_y <= 7'd0;
        end else if (h_sync_tick && (v_cnt >= V_SYNC + V_BPORCH) && (v_cnt < V_SYNC + V_BPORCH + V_ACTIVE)) begin
            if (v_scale_cnt == 3'd5) begin
                v_scale_cnt <= 3'd0;
                if (src_y < 7'd119) begin
                    src_y <= src_y + 1'b1;
                end
            end else begin
                v_scale_cnt <= v_scale_cnt + 1'b1;
            end
        end
    end
end

// Calculate framebuffer address using shift-add instead of multiply
// fb_addr = src_y * 160 + src_x
// 160 = 128 + 32 = (1 << 7) + (1 << 5)
// This avoids potential synthesis issues with multipliers
wire [14:0] y_times_128 = {1'b0, src_y, 7'b0};  // src_y << 7
wire [14:0] y_times_32  = {3'b0, src_y, 5'b0};  // src_y << 5
wire [14:0] fb_addr = y_times_128 + y_times_32 + {7'b0, src_x};

// Pipeline stage 1: Register the address and region flag
reg [14:0] fb_addr_p1;
reg in_fb_region_p1;
always @(posedge pix_clk) begin
    fb_addr_p1 <= fb_addr;
    in_fb_region_p1 <= in_fb_region;
end

// Read pixel from framebuffer (Port B - HDMI read)
reg [7:0] pixel_data;
always @(posedge pix_clk) begin
    if (in_fb_region_p1 && fb_addr_p1 < FB_SIZE)
        pixel_data <= framebuffer[fb_addr_p1];
    else
        pixel_data <= 8'd0;
end

// Pipeline stage 2: Track region for output mux
reg in_fb_region_p2;
always @(posedge pix_clk) begin
    in_fb_region_p2 <= in_fb_region_p1;
end

// Expand RGB332 to RGB888
wire [7:0] rgb_r = {pixel_data[7:5], pixel_data[7:5], pixel_data[7:6]};
wire [7:0] rgb_g = {pixel_data[4:2], pixel_data[4:2], pixel_data[4:3]};
wire [7:0] rgb_b = {pixel_data[1:0], pixel_data[1:0], pixel_data[1:0], pixel_data[1:0]};

// Pipeline hdmi_de to match pixel_data latency (2 cycles)
reg hdmi_de_p1, hdmi_de_p2;
reg hdmi_hs_p1, hdmi_hs_p2;
reg hdmi_vs_p1, hdmi_vs_p2;
always @(posedge pix_clk) begin
    hdmi_de_p1 <= hdmi_de;
    hdmi_de_p2 <= hdmi_de_p1;
    hdmi_hs_p1 <= hdmi_hs;
    hdmi_hs_p2 <= hdmi_hs_p1;
    hdmi_vs_p1 <= hdmi_vs;
    hdmi_vs_p2 <= hdmi_vs_p1;
end

// Final output - framebuffer data in center, black borders
wire [7:0] out_r = (hdmi_de_p2 && in_fb_region_p2) ? rgb_r : 8'd0;
wire [7:0] out_g = (hdmi_de_p2 && in_fb_region_p2) ? rgb_g : 8'd0;
wire [7:0] out_b = (hdmi_de_p2 && in_fb_region_p2) ? rgb_b : 8'd0;

// ==============================================================================
// Debug counters and status
// ==============================================================================

// Frame counter (increments at vsync)
reg [15:0] frame_count;
reg vs_prev;
always @(posedge pix_clk or negedge hdmi_rst_n) begin
    if (!hdmi_rst_n) begin
        frame_count <= 16'd0;
        vs_prev <= 1'b0;
    end else begin
        vs_prev <= hdmi_vs;
        if (hdmi_vs && !vs_prev)  // Rising edge of vsync
            frame_count <= frame_count + 1'b1;
    end
end

// Wishbone write counter (counts writes to framebuffer)
reg [15:0] wb_write_count;
reg [15:0] wb_last_addr;
always @(posedge I_wb_clk or posedge I_wb_rst) begin
    if (I_wb_rst) begin
        wb_write_count <= 16'd0;
        wb_last_addr <= 16'd0;
    end else begin
        if (wb_valid && I_wb_we && wb_pixel_addr < FB_SIZE) begin
            wb_write_count <= wb_write_count + 1'b1;
            wb_last_addr <= {1'b0, wb_pixel_addr};
        end
    end
end

// Framebuffer read counter (counts pixel reads)
reg [15:0] fb_read_count;
reg [15:0] fb_last_read_addr;
always @(posedge pix_clk or negedge hdmi_rst_n) begin
    if (!hdmi_rst_n) begin
        fb_read_count <= 16'd0;
        fb_last_read_addr <= 16'd0;
    end else begin
        if (in_fb_region) begin
            fb_read_count <= fb_read_count + 1'b1;
            fb_last_read_addr <= {1'b0, fb_addr};
        end
    end
end

// Synchronize h_cnt and v_cnt snapshots to Wishbone clock for reading
// Take snapshot at start of frame
reg [11:0] h_cnt_snap;
reg [11:0] v_cnt_snap;
always @(posedge pix_clk) begin
    // Continuously update - just sample current values
    h_cnt_snap <= h_cnt;
    v_cnt_snap <= v_cnt;
end

// Debug output assignments
assign O_debug_status = {frame_count, 4'd0, v_cnt_snap[11:4], 4'd0, h_cnt_snap[11:4]};
assign O_debug_wb = {wb_write_count, wb_last_addr};
assign O_debug_read = {fb_read_count, fb_last_read_addr};

// ==============================================================================
// DVI TX output
// ==============================================================================
DVI_TX_Top DVI_TX_Top_inst
(
    .I_rst_n       (hdmi_rst_n    ),
    .I_serial_clk  (serial_clk    ),
    .I_rgb_clk     (pix_clk       ),
    .I_rgb_vs      (hdmi_vs_p2    ),   // Pipelined to match pixel data
    .I_rgb_hs      (hdmi_hs_p2    ),   // Pipelined to match pixel data
    .I_rgb_de      (hdmi_de_p2    ),   // Pipelined to match pixel data
    .I_rgb_r       (out_r         ),  
    .I_rgb_g       (out_g         ),  
    .I_rgb_b       (out_b         ),  
    .O_tmds_clk_p  (O_tmds_clk_p  ),
    .O_tmds_clk_n  (O_tmds_clk_n  ),
    .O_tmds_data_p (O_tmds_data_p ),
    .O_tmds_data_n (O_tmds_data_n )
);

endmodule
