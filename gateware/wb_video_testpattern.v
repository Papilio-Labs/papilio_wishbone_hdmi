// ==============================================================================
// wb_video_testpattern.v - Wishbone Test Pattern Generator
// ==============================================================================
// Standalone test pattern generator with Wishbone control interface.
// Generates color bars, grid, or grayscale patterns.
//
// This module can be instantiated independently - just connect it to the
// shared HDMI PHY layer (hdmi_phy_720p.v).
//
// Wishbone Register Map (directly addressed):
//   0x00: Control register
//         [2:0] = Pattern mode:
//                 0 = Color bars
//                 1 = Grid (32 pixel spacing)
//                 2 = Grayscale gradient
//         [7:3] = Reserved
//
// Usage: Instantiate this module and hdmi_phy_720p, connect RGB outputs
//        from this module to the PHY's RGB inputs.
// ==============================================================================

module wb_video_testpattern
(
    // Wishbone slave interface
    input             I_wb_clk        ,
    input             I_wb_rst        ,
    input      [7:0]  I_wb_adr        ,
    input      [7:0]  I_wb_dat        ,
    input             I_wb_we         ,
    input             I_wb_stb        ,
    input             I_wb_cyc        ,
    output reg        O_wb_ack        ,
    output reg [7:0]  O_wb_dat        ,
    
    // Video timing inputs (from HDMI PHY)
    input             I_pix_clk       ,
    input             I_rst_n         ,
    input      [11:0] I_active_x      ,
    input      [11:0] I_active_y      ,
    input             I_de            ,
    input             I_hs            ,
    input             I_vs            ,
    
    // RGB output (directly to HDMI PHY)
    output reg [7:0]  O_rgb_r         ,
    output reg [7:0]  O_rgb_g         ,
    output reg [7:0]  O_rgb_b         ,
    output reg        O_rgb_de        ,
    output reg        O_rgb_hs        ,
    output reg        O_rgb_vs        
);

// ==============================================================================
// Parameters
// ==============================================================================
localparam H_ACTIVE = 12'd1280;
localparam V_ACTIVE = 12'd720;

// Pattern modes
localparam MODE_COLOR_BARS = 3'd0;
localparam MODE_GRID       = 3'd1;
localparam MODE_GRAYSCALE  = 3'd2;

// Color definitions
localparam [23:0] WHITE   = 24'hFFFFFF;
localparam [23:0] YELLOW  = 24'hFFFF00;
localparam [23:0] CYAN    = 24'h00FFFF;
localparam [23:0] GREEN   = 24'h00FF00;
localparam [23:0] MAGENTA = 24'hFF00FF;
localparam [23:0] RED     = 24'hFF0000;
localparam [23:0] BLUE    = 24'h0000FF;
localparam [23:0] BLACK   = 24'h000000;

// ==============================================================================
// Control Register
// ==============================================================================
reg [2:0] pattern_mode;

// Cross-clock domain synchronization
reg [2:0] pattern_mode_sync1, pattern_mode_sync2;

always @(posedge I_pix_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
        pattern_mode_sync1 <= MODE_COLOR_BARS;
        pattern_mode_sync2 <= MODE_COLOR_BARS;
    end else begin
        pattern_mode_sync1 <= pattern_mode;
        pattern_mode_sync2 <= pattern_mode_sync1;
    end
end

// ==============================================================================
// Wishbone Interface
// ==============================================================================
wire wb_valid = I_wb_stb && I_wb_cyc;

always @(posedge I_wb_clk or posedge I_wb_rst) begin
    if (I_wb_rst) begin
        pattern_mode <= MODE_COLOR_BARS;
        O_wb_ack <= 1'b0;
        O_wb_dat <= 8'h00;
    end else begin
        O_wb_ack <= wb_valid && !O_wb_ack;
        
        if (wb_valid && I_wb_we && !O_wb_ack) begin
            case (I_wb_adr[3:0])
                4'h0: pattern_mode <= I_wb_dat[2:0];
                default: ;
            endcase
        end
        
        if (wb_valid && !I_wb_we) begin
            case (I_wb_adr[3:0])
                4'h0: O_wb_dat <= {5'b0, pattern_mode};
                default: O_wb_dat <= 8'h00;
            endcase
        end
    end
end

// ==============================================================================
// Test Pattern Generation
// ==============================================================================
reg [7:0] tp_r, tp_g, tp_b;

// Color bar index (divide 1280 pixels into 8 bars of 160 pixels each)
// 1280 / 8 = 160 pixels per bar
// To avoid division, use comparison thresholds
wire [2:0] color_bar_idx = (I_active_x < 12'd160) ? 3'd0 :
                           (I_active_x < 12'd320) ? 3'd1 :
                           (I_active_x < 12'd480) ? 3'd2 :
                           (I_active_x < 12'd640) ? 3'd3 :
                           (I_active_x < 12'd800) ? 3'd4 :
                           (I_active_x < 12'd960) ? 3'd5 :
                           (I_active_x < 12'd1120) ? 3'd6 : 3'd7;

always @(posedge I_pix_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
        tp_r <= 8'd0;
        tp_g <= 8'd0;
        tp_b <= 8'd0;
    end else if (I_de) begin
        case (pattern_mode_sync2)
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
                if ((I_active_x[4:0] == 5'd0) || (I_active_y[4:0] == 5'd0) ||
                    (I_active_x == H_ACTIVE-1) || (I_active_y == V_ACTIVE-1)) begin
                    {tp_r, tp_g, tp_b} <= RED;
                end else begin
                    {tp_r, tp_g, tp_b} <= BLACK;
                end
            end
            
            MODE_GRAYSCALE: begin
                // Horizontal grayscale gradient (black to white across 1280 pixels)
                // x >> 2 gives 0-319 for x=0-1279
                // Truncating to 8 bits clamps values > 255
                // Result: black at x=0, white at x=1020, then stays white to x=1279
                if (I_active_x[10:2] > 9'd255)
                    {tp_r, tp_g, tp_b} <= 24'hFFFFFF;
                else begin
                    tp_r <= I_active_x[9:2];
                    tp_g <= I_active_x[9:2];
                    tp_b <= I_active_x[9:2];
                end
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
// Output Pipeline (1 cycle latency to match pattern generation)
// ==============================================================================
reg de_d1, hs_d1, vs_d1;

always @(posedge I_pix_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
        de_d1 <= 1'b0;
        hs_d1 <= 1'b0;
        vs_d1 <= 1'b0;
        O_rgb_r <= 8'd0;
        O_rgb_g <= 8'd0;
        O_rgb_b <= 8'd0;
        O_rgb_de <= 1'b0;
        O_rgb_hs <= 1'b0;
        O_rgb_vs <= 1'b0;
    end else begin
        // Pipeline delay for sync signals
        de_d1 <= I_de;
        hs_d1 <= I_hs;
        vs_d1 <= I_vs;
        
        // Output
        O_rgb_r <= tp_r;
        O_rgb_g <= tp_g;
        O_rgb_b <= tp_b;
        O_rgb_de <= de_d1;
        O_rgb_hs <= hs_d1;
        O_rgb_vs <= vs_d1;
    end
end

endmodule
