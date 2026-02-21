// ==============================================================================
// video_top_combined.v - HDMI output with framebuffer, text mode, and test patterns
// ==============================================================================
// Combined video module supporting multiple display modes:
//   Mode 0: Color bars test pattern
//   Mode 1: Grid test pattern  
//   Mode 2: Grayscale test pattern
//   Mode 3: Text mode (80x26 characters)
//   Mode 4: Framebuffer mode (160x120 scaled to 720p)
//
// Wishbone Address Map:
//   0x0000-0x4AFF: Framebuffer pixels (when in framebuffer mode)
//   0x8000-0x800F: Video control registers
//   0x8010-0x801F: Reserved
//   0x8020-0x802F: Character RAM control (text mode)
//
// Control Register (0x8000):
//   [2:0] = Video mode (0-4)
//   [7:3] = Reserved
// ==============================================================================

module video_top_combined
(
    // Reference clock
    input             I_clk           , // 27MHz reference clock
    input             I_rst_n         ,
    
    // Wishbone slave interface
    input             I_wb_clk        , // Wishbone clock
    input             I_wb_rst        , // Wishbone reset
    input      [15:0] I_wb_adr        , // Address (16-bit)
    input      [7:0]  I_wb_dat        , // Write data
    input             I_wb_we         , // Write enable
    input             I_wb_stb        , // Strobe
    input             I_wb_cyc        , // Cycle
    output reg        O_wb_ack        , // Acknowledge
    output reg [7:0]  O_wb_dat        , // Read data
    
    // HDMI TMDS outputs
    output            O_tmds_clk_p    ,
    output            O_tmds_clk_n    ,
    output     [2:0]  O_tmds_data_p   , // {r,g,b}
    output     [2:0]  O_tmds_data_n   
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

// Video modes
localparam MODE_COLOR_BARS = 3'd0;
localparam MODE_GRID       = 3'd1;
localparam MODE_GRAYSCALE  = 3'd2;
localparam MODE_TEXT       = 3'd3;
localparam MODE_FRAMEBUFFER = 3'd4;

// ==============================================================================
// Control Registers
// ==============================================================================
reg [2:0] video_mode;  // Current video mode

// Address decoding
wire wb_valid = I_wb_stb && I_wb_cyc;
wire ctrl_reg_sel = (I_wb_adr[15:8] == 8'h80);  // 0x80xx = control registers
wire framebuffer_sel = (I_wb_adr[15] == 1'b0);  // 0x0000-0x7FFF = framebuffer
wire charram_sel = (I_wb_adr[15:4] == 12'h802); // 0x8020-0x802F = char RAM control

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
// Control Register Access
// ==============================================================================
always @(posedge I_wb_clk or posedge I_wb_rst) begin
    if (I_wb_rst) begin
        video_mode <= MODE_FRAMEBUFFER;  // Default to framebuffer mode
    end else begin
        if (wb_valid && I_wb_we && ctrl_reg_sel) begin
            case (I_wb_adr[3:0])
                4'h0: video_mode <= I_wb_dat[2:0];
                default: ;
            endcase
        end
    end
end

// ==============================================================================
// Framebuffer RAM - Simple Dual Port (1 write port, 1 read port)
// Write port: I_wb_clk domain (Wishbone writes)
// Read port: pix_clk domain (HDMI display)
// Note: Wishbone readback not supported to keep it as simple dual-port
// ==============================================================================
reg [7:0] framebuffer [0:FB_SIZE-1];

// Wishbone pixel address (HQVGA uses word-aligned addressing)
wire [14:0] wb_pixel_addr = I_wb_adr[14:2];

// Wishbone write to framebuffer
always @(posedge I_wb_clk) begin
    if (wb_valid && I_wb_we && framebuffer_sel && wb_pixel_addr < FB_SIZE) begin
        framebuffer[wb_pixel_addr] <= I_wb_dat;
    end
end

// ==============================================================================
// Character RAM for Text Mode
// ==============================================================================
(* ram_style = "registers" *)  // Use distributed RAM for smaller char RAM
reg [7:0] char_ram [0:2399];  // 80x30 characters
(* ram_style = "registers" *)
reg [7:0] attr_ram [0:2399];  // Attributes (color)

// Character RAM control registers
reg [6:0] cursor_x;
reg [4:0] cursor_y;
reg [7:0] default_attr;
reg [11:0] ram_addr_ptr;

wire [11:0] cursor_addr = (cursor_y * 80) + cursor_x;

// Character RAM Wishbone interface
always @(posedge I_wb_clk or posedge I_wb_rst) begin
    if (I_wb_rst) begin
        cursor_x <= 7'd0;
        cursor_y <= 5'd0;
        default_attr <= 8'h0F;  // White on black
        ram_addr_ptr <= 12'd0;
    end else begin
        if (wb_valid && I_wb_we && charram_sel) begin
            case (I_wb_adr[3:0])
                4'h1: cursor_x <= I_wb_dat[6:0];
                4'h2: cursor_y <= I_wb_dat[4:0];
                4'h3: default_attr <= I_wb_dat;
                4'h4: begin  // Write character at cursor
                    if (cursor_addr < 2400) begin
                        char_ram[cursor_addr] <= I_wb_dat;
                        attr_ram[cursor_addr] <= default_attr;
                        // Auto-advance cursor
                        if (cursor_x < 79)
                            cursor_x <= cursor_x + 1;
                        else begin
                            cursor_x <= 0;
                            if (cursor_y < 29)
                                cursor_y <= cursor_y + 1;
                        end
                    end
                end
                4'h6: ram_addr_ptr[11:8] <= I_wb_dat[3:0];
                4'h7: ram_addr_ptr[7:0] <= I_wb_dat;
                4'h8: begin  // Direct RAM write
                    if (ram_addr_ptr < 2400) begin
                        char_ram[ram_addr_ptr] <= I_wb_dat;
                        ram_addr_ptr <= ram_addr_ptr + 1;
                    end
                end
                4'h9: begin  // Direct attr write
                    if (ram_addr_ptr < 2400) begin
                        attr_ram[ram_addr_ptr] <= I_wb_dat;
                        ram_addr_ptr <= ram_addr_ptr + 1;
                    end
                end
                default: ;
            endcase
        end
    end
end

// ==============================================================================
// Wishbone ACK and Read Data
// ==============================================================================
reg [7:0] wb_read_data;
reg wb_valid_d;

always @(posedge I_wb_clk) begin
    if (wb_valid && !I_wb_we) begin
        if (ctrl_reg_sel) begin
            case (I_wb_adr[3:0])
                4'h0: wb_read_data <= {5'b0, video_mode};
                default: wb_read_data <= 8'h00;
            endcase
        end else if (charram_sel) begin
            case (I_wb_adr[3:0])
                4'h1: wb_read_data <= {1'b0, cursor_x};
                4'h2: wb_read_data <= {3'b0, cursor_y};
                4'h3: wb_read_data <= default_attr;
                4'h4: wb_read_data <= (cursor_addr < 2400) ? char_ram[cursor_addr] : 8'h00;
                4'h6: wb_read_data <= {4'b0, ram_addr_ptr[11:8]};
                4'h7: wb_read_data <= ram_addr_ptr[7:0];
                default: wb_read_data <= 8'h00;
            endcase
        end else begin
            // Framebuffer read not supported (would require extra BRAM port)
            wb_read_data <= 8'h00;
        end
    end
end

always @(posedge I_wb_clk or posedge I_wb_rst) begin
    if (I_wb_rst) begin
        O_wb_ack <= 1'b0;
        O_wb_dat <= 8'h00;
        wb_valid_d <= 1'b0;
    end else begin
        wb_valid_d <= wb_valid && !I_wb_we;
        O_wb_ack <= (wb_valid && I_wb_we) || wb_valid_d;
        O_wb_dat <= wb_read_data;
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

// Active area pixel coordinates
wire [11:0] active_x = h_cnt - (H_SYNC + H_BPORCH);
wire [11:0] active_y = v_cnt - (V_SYNC + V_BPORCH);

// ==============================================================================
// Test Pattern Generator
// ==============================================================================
reg [7:0] tp_r, tp_g, tp_b;

// Color bar colors
localparam [23:0] WHITE   = 24'hFFFFFF;
localparam [23:0] YELLOW  = 24'hFFFF00;
localparam [23:0] CYAN    = 24'h00FFFF;
localparam [23:0] GREEN   = 24'h00FF00;
localparam [23:0] MAGENTA = 24'hFF00FF;
localparam [23:0] RED     = 24'hFF0000;
localparam [23:0] BLUE    = 24'h0000FF;
localparam [23:0] BLACK   = 24'h000000;

wire [2:0] color_bar_idx = active_x[10:8];  // Divide screen into 8 bars

always @(posedge pix_clk) begin
    if (hdmi_de) begin
        case (video_mode)
            MODE_COLOR_BARS: begin
                case (color_bar_idx)
                    3'd0: {tp_r, tp_g, tp_b} <= WHITE;
                    3'd1: {tp_r, tp_g, tp_b} <= YELLOW;
                    3'd2: {tp_r, tp_g, tp_b} <= CYAN;
                    3'd3: {tp_r, tp_g, tp_b} <= GREEN;
                    3'd4: {tp_r, tp_g, tp_b} <= MAGENTA;
                    3'd5: {tp_r, tp_g, tp_b} <= RED;
                    3'd6: {tp_r, tp_g, tp_b} <= BLUE;
                    3'd7: {tp_r, tp_g, tp_b} <= BLACK;
                endcase
            end
            MODE_GRID: begin
                // Grid pattern - lines every 32 pixels
                if ((active_x[4:0] == 5'd0) || (active_y[4:0] == 5'd0) ||
                    (active_x == H_ACTIVE-1) || (active_y == V_ACTIVE-1)) begin
                    {tp_r, tp_g, tp_b} <= RED;
                end else begin
                    {tp_r, tp_g, tp_b} <= BLACK;
                end
            end
            MODE_GRAYSCALE: begin
                // Horizontal grayscale gradient
                tp_r <= active_x[9:2];
                tp_g <= active_x[9:2];
                tp_b <= active_x[9:2];
            end
            default: begin
                {tp_r, tp_g, tp_b} <= BLACK;
            end
        endcase
    end else begin
        {tp_r, tp_g, tp_b} <= BLACK;
    end
end

// ==============================================================================
// Text Mode Generator (80x26 @ 16x16 pixels = 1280x416)
// ==============================================================================
// Replicating wb_text_mode.v pipeline exactly:
// - char_ram read is registered (1 cycle latency like external RAM)
// - Font ROM receives: registered char_data, immediate font_row
// - Font ROM has 1-cycle internal register
// - font_col needs 2 additional delays after ROM to match output

wire [6:0] char_col = active_x[10:4];  // 0-79
wire [4:0] char_row = active_y[8:4];   // 0-25
wire [2:0] font_col = active_x[3:1];   // 0-7 (2x scaled)
wire [2:0] font_row = active_y[3:1];   // 0-7 (2x scaled)

wire in_text_area = (active_y < 12'd416);  // 26 rows * 16 pixels
wire [11:0] text_char_addr = (char_row * 80) + char_col;

// Character RAM read - registered output (like external RAM with 1 cycle latency)
reg [7:0] text_char_data;
reg [7:0] text_attr_data;
always @(posedge pix_clk) begin
    if (text_char_addr < 2400) begin
        text_char_data <= char_ram[text_char_addr];
        text_attr_data <= attr_ram[text_char_addr];
    end else begin
        text_char_data <= 8'h20;  // Space
        text_attr_data <= 8'h0F;  // White on black
    end
end

// Pipeline stage 1: Delay font_row and font_col to match char RAM latency
reg [2:0] font_row_d1;
reg [2:0] font_col_d1, font_col_d2;
reg in_text_area_d1, in_text_area_d2;
reg hdmi_de_d1, hdmi_de_d2;

always @(posedge pix_clk) begin
    font_row_d1 <= font_row;
    font_col_d1 <= font_col;
    font_col_d2 <= font_col_d1;
    in_text_area_d1 <= in_text_area;
    in_text_area_d2 <= in_text_area_d1;
    hdmi_de_d1 <= hdmi_de;
    hdmi_de_d2 <= hdmi_de_d1;
end

// Font ROM - use registered char_data (d1) and IMMEDIATE font_row (like wb_text_mode.v)
wire [7:0] font_pixels;
font_rom_8x8 u_font_rom (
    .clk(pix_clk),
    .char_code(text_char_data),  // Registered from char_ram (d1)
    .row(font_row),              // IMMEDIATE - matches wb_text_mode.v
    .pixels(font_pixels),        // Output valid at d2 (ROM internal register)
    .custom_font_we(1'b0),
    .custom_font_addr(6'd0),
    .custom_font_data(8'd0)
);

// Pipeline stage 2: Register font ROM output
reg [7:0] font_pixels_d1;
reg [2:0] font_col_d3;
reg [7:0] text_attr_d2;
reg in_text_area_d3;
reg hdmi_de_d3;

always @(posedge pix_clk) begin
    font_pixels_d1 <= font_pixels;
    font_col_d3 <= font_col_d2;
    text_attr_d2 <= text_attr_data;  // text_attr_data is already d1 (from char_ram)
    in_text_area_d3 <= in_text_area_d2;
    hdmi_de_d3 <= hdmi_de_d2;
end

// Font pixel extraction - font_col_d3 matches font_pixels_d1 timing
wire font_pixel = font_pixels_d1[7 - font_col_d3];
wire [3:0] fg_color = text_attr_d2[3:0];
wire [3:0] bg_color = text_attr_d2[7:4];

// Convert 4-bit color to RGB
function [23:0] color4_to_rgb;
    input [3:0] color;
    begin
        case (color)
            4'h0: color4_to_rgb = 24'h000000;  // Black
            4'h1: color4_to_rgb = 24'h0000AA;  // Blue
            4'h2: color4_to_rgb = 24'h00AA00;  // Green
            4'h3: color4_to_rgb = 24'h00AAAA;  // Cyan
            4'h4: color4_to_rgb = 24'hAA0000;  // Red
            4'h5: color4_to_rgb = 24'hAA00AA;  // Magenta
            4'h6: color4_to_rgb = 24'hAA5500;  // Brown
            4'h7: color4_to_rgb = 24'hAAAAAA;  // Light gray
            4'h8: color4_to_rgb = 24'h555555;  // Dark gray
            4'h9: color4_to_rgb = 24'h5555FF;  // Light blue
            4'hA: color4_to_rgb = 24'h55FF55;  // Light green
            4'hB: color4_to_rgb = 24'h55FFFF;  // Light cyan
            4'hC: color4_to_rgb = 24'hFF5555;  // Light red
            4'hD: color4_to_rgb = 24'hFF55FF;  // Light magenta
            4'hE: color4_to_rgb = 24'hFFFF55;  // Yellow
            4'hF: color4_to_rgb = 24'hFFFFFF;  // White
        endcase
    end
endfunction

reg [7:0] text_r, text_g, text_b;
always @(posedge pix_clk) begin
    if (hdmi_de_d3 && in_text_area_d3) begin
        if (font_pixel) begin
            {text_r, text_g, text_b} <= color4_to_rgb(fg_color);
        end else begin
            {text_r, text_g, text_b} <= color4_to_rgb(bg_color);
        end
    end else begin
        {text_r, text_g, text_b} <= BLACK;
    end
end

// ==============================================================================
// Framebuffer Display (160x120 scaled 6x to 960x720)
// ==============================================================================
localparam FB_X_START = 160;
localparam FB_X_END   = 1120;

reg [2:0] h_scale_cnt;
reg [2:0] v_scale_cnt;
reg [7:0] src_x;
reg [6:0] src_y;

wire in_fb_region = hdmi_de && (active_x >= FB_X_START) && (active_x < FB_X_END);

// Horizontal scaling counter
always @(posedge pix_clk or negedge hdmi_rst_n) begin
    if (!hdmi_rst_n) begin
        h_scale_cnt <= 3'd0;
        src_x <= 8'd0;
    end else begin
        if (h_cnt == H_SYNC + H_BPORCH + FB_X_START - 1) begin
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

// Track line ends for vertical scaling
reg h_sync_prev;
wire h_sync_tick = !hdmi_hs && h_sync_prev;
always @(posedge pix_clk) h_sync_prev <= hdmi_hs;

// Vertical scaling counter
always @(posedge pix_clk or negedge hdmi_rst_n) begin
    if (!hdmi_rst_n) begin
        v_scale_cnt <= 3'd0;
        src_y <= 7'd0;
    end else begin
        if (v_cnt == V_SYNC + V_BPORCH - 1 && h_cnt == 0) begin
            v_scale_cnt <= 3'd0;
            src_y <= 7'd0;
        end else if (h_sync_tick && (v_cnt >= V_SYNC + V_BPORCH) && (v_cnt < V_SYNC + V_BPORCH + V_ACTIVE)) begin
            if (v_scale_cnt == 3'd5) begin
                v_scale_cnt <= 3'd0;
                if (src_y < 7'd119)
                    src_y <= src_y + 1'b1;
            end else begin
                v_scale_cnt <= v_scale_cnt + 1'b1;
            end
        end
    end
end

// Framebuffer address calculation
wire [14:0] y_times_128 = {1'b0, src_y, 7'b0};
wire [14:0] y_times_32  = {3'b0, src_y, 5'b0};
wire [14:0] fb_addr = y_times_128 + y_times_32 + {7'b0, src_x};

// Pipeline stages for framebuffer read
reg [14:0] fb_addr_p1;
reg in_fb_region_p1, in_fb_region_p2;

always @(posedge pix_clk) begin
    fb_addr_p1 <= fb_addr;
    in_fb_region_p1 <= in_fb_region;
    in_fb_region_p2 <= in_fb_region_p1;
end

// Read pixel from framebuffer
reg [7:0] pixel_data;
always @(posedge pix_clk) begin
    if (in_fb_region_p1 && fb_addr_p1 < FB_SIZE)
        pixel_data <= framebuffer[fb_addr_p1];
    else
        pixel_data <= 8'd0;
end

// Expand RGB332 to RGB888
wire [7:0] fb_r = {pixel_data[7:5], pixel_data[7:5], pixel_data[7:6]};
wire [7:0] fb_g = {pixel_data[4:2], pixel_data[4:2], pixel_data[4:3]};
wire [7:0] fb_b = {pixel_data[1:0], pixel_data[1:0], pixel_data[1:0], pixel_data[1:0]};

// ==============================================================================
// Output Multiplexer
// ==============================================================================
// Sync video_mode to pixel clock domain
reg [2:0] video_mode_pix;
always @(posedge pix_clk) video_mode_pix <= video_mode;

// Pipeline sync signals to match pixel data latency
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

// Final RGB output selection
reg [7:0] out_r, out_g, out_b;

always @(posedge pix_clk) begin
    case (video_mode_pix)
        MODE_COLOR_BARS, MODE_GRID, MODE_GRAYSCALE: begin
            out_r <= tp_r;
            out_g <= tp_g;
            out_b <= tp_b;
        end
        MODE_TEXT: begin
            out_r <= text_r;
            out_g <= text_g;
            out_b <= text_b;
        end
        MODE_FRAMEBUFFER: begin
            if (in_fb_region_p2) begin
                out_r <= fb_r;
                out_g <= fb_g;
                out_b <= fb_b;
            end else begin
                out_r <= 8'd0;
                out_g <= 8'd0;
                out_b <= 8'd0;
            end
        end
        default: begin
            out_r <= 8'd0;
            out_g <= 8'd0;
            out_b <= 8'd0;
        end
    endcase
end

// ==============================================================================
// DVI TX output
// ==============================================================================
DVI_TX_Top DVI_TX_Top_inst
(
    .I_rst_n       (hdmi_rst_n    ),
    .I_serial_clk  (serial_clk    ),
    .I_rgb_clk     (pix_clk       ),
    .I_rgb_vs      (hdmi_vs_p2    ),
    .I_rgb_hs      (hdmi_hs_p2    ),
    .I_rgb_de      (hdmi_de_p2    ),
    .I_rgb_r       (out_r         ),  
    .I_rgb_g       (out_g         ),  
    .I_rgb_b       (out_b         ),  
    .O_tmds_clk_p  (O_tmds_clk_p  ),
    .O_tmds_clk_n  (O_tmds_clk_n  ),
    .O_tmds_data_p (O_tmds_data_p ),
    .O_tmds_data_n (O_tmds_data_n )
);

endmodule
