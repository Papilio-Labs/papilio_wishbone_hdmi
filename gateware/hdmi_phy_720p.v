// ==============================================================================
// hdmi_phy_720p.v - HDMI Physical Layer for 720p output (Open Source)
// ==============================================================================
// Shared HDMI/DVI physical layer that can be used by any video source.
// Uses open-source TMDS encoders instead of proprietary IP.
//
// This module handles:
//   - PLL clock generation (27MHz -> 371.25MHz serial, 74.25MHz pixel)
//   - Video timing generation for 720p@60Hz
//   - TMDS encoding (open source)
//   - 10:1 serialization
//   - LVDS differential output
//
// Interface:
//   - Input: RGB888 pixel data + data enable
//   - Output: TMDS differential pairs
//
// Note: Some Gowin primitives are unavoidable (rPLL, CLKDIV, OSER10, ELVDS_OBUF)
// as they are required for clock generation and LVDS output on Gowin FPGAs.
// However, all logic (TMDS encoding, timing) is open source.
// ==============================================================================

module hdmi_phy_720p
(
    // Reference clock
    input             I_clk           , // 27MHz reference clock
    input             I_rst_n         ,
    
    // Video input interface (directly from video source)
    input      [7:0]  I_rgb_r         , // Red channel
    input      [7:0]  I_rgb_g         , // Green channel
    input      [7:0]  I_rgb_b         , // Blue channel
    input             I_rgb_de        , // Data enable (active video)
    input             I_rgb_hs        , // Horizontal sync
    input             I_rgb_vs        , // Vertical sync
    
    // Timing outputs (active area pixel coordinates)
    output            O_pix_clk       , // 74.25 MHz pixel clock
    output            O_pix_clk_5x    , // 371.25 MHz serial clock
    output            O_hdmi_rst_n    , // Reset synchronized to HDMI domain
    output     [11:0] O_h_cnt         , // Horizontal counter
    output     [11:0] O_v_cnt         , // Vertical counter
    output            O_de            , // Data enable
    output            O_hs            , // Horizontal sync
    output            O_vs            , // Vertical sync
    output     [11:0] O_active_x      , // Active area X coordinate
    output     [11:0] O_active_y      , // Active area Y coordinate
    
    // HDMI TMDS outputs
    output            O_tmds_clk_p    ,
    output            O_tmds_clk_n    ,
    output     [2:0]  O_tmds_data_p   , // {r,g,b}
    output     [2:0]  O_tmds_data_n   
);

// ==============================================================================
// Parameters - 720p@60Hz timing
// ==============================================================================
localparam H_TOTAL    = 12'd1650;
localparam H_SYNC     = 12'd40;
localparam H_BPORCH   = 12'd220;
localparam H_ACTIVE   = 12'd1280;
localparam V_TOTAL    = 12'd750;
localparam V_SYNC     = 12'd5;
localparam V_BPORCH   = 12'd20;
localparam V_ACTIVE   = 12'd720;

// ==============================================================================
// PLL and clock generation
// 27MHz input -> 371.25MHz serial clock -> /5 = 74.25MHz pixel clock
// ==============================================================================
wire serial_clk;
wire pll_lock;
wire pix_clk;

// PLL: 27MHz * 55 / 4 = 371.25 MHz (closest we can get)
// Actually configured for: 27 * (FBDIV+1) / (IDIV+1) / ODIV
TMDS_rPLL u_tmds_rpll
(
    .clkin  (I_clk      ),
    .clkout (serial_clk ),
    .lock   (pll_lock   )
);

wire hdmi_rst_n = I_rst_n & pll_lock;
assign O_hdmi_rst_n = hdmi_rst_n;

// Clock divider: serial_clk / 5 = pixel clock
CLKDIV u_clkdiv
(
    .RESETN (hdmi_rst_n ),
    .HCLKIN (serial_clk ),
    .CLKOUT (pix_clk    ),
    .CALIB  (1'b1       )
);
defparam u_clkdiv.DIV_MODE = "5";
defparam u_clkdiv.GSREN = "false";

assign O_pix_clk = pix_clk;
assign O_pix_clk_5x = serial_clk;

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

// Output timing signals
assign O_h_cnt = h_cnt;
assign O_v_cnt = v_cnt;
assign O_de = hdmi_de;
assign O_hs = hdmi_hs;
assign O_vs = hdmi_vs;
assign O_active_x = active_x;
assign O_active_y = active_y;

// ==============================================================================
// TMDS Encoding (Open Source)
// ==============================================================================
wire [9:0] tmds_r, tmds_g, tmds_b;

// Red channel encoder
tmds_encoder enc_r (
    .clk(pix_clk),
    .rst(~hdmi_rst_n),
    .video_active(I_rgb_de),
    .data_in(I_rgb_r),
    .c0(1'b0),
    .c1(1'b0),
    .tmds_out(tmds_r)
);

// Green channel encoder
tmds_encoder enc_g (
    .clk(pix_clk),
    .rst(~hdmi_rst_n),
    .video_active(I_rgb_de),
    .data_in(I_rgb_g),
    .c0(1'b0),
    .c1(1'b0),
    .tmds_out(tmds_g)
);

// Blue channel encoder (carries sync signals)
tmds_encoder enc_b (
    .clk(pix_clk),
    .rst(~hdmi_rst_n),
    .video_active(I_rgb_de),
    .data_in(I_rgb_b),
    .c0(I_rgb_hs),
    .c1(I_rgb_vs),
    .tmds_out(tmds_b)
);

// ==============================================================================
// 10:1 Serialization using OSER10 primitives
// ==============================================================================
wire [2:0] tmds_serial;
wire tmds_clk_serial;

// Red channel serializer
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
    .PCLK(pix_clk),
    .FCLK(serial_clk),
    .RESET(~hdmi_rst_n),
    .Q(tmds_serial[2])
);

// Green channel serializer
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
    .PCLK(pix_clk),
    .FCLK(serial_clk),
    .RESET(~hdmi_rst_n),
    .Q(tmds_serial[1])
);

// Blue channel serializer
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
    .PCLK(pix_clk),
    .FCLK(serial_clk),
    .RESET(~hdmi_rst_n),
    .Q(tmds_serial[0])
);

// Clock serializer (outputs pixel clock pattern: 5 high, 5 low = 1111100000)
OSER10 oser_clk (
    .D0(1'b1),
    .D1(1'b1),
    .D2(1'b1),
    .D3(1'b1),
    .D4(1'b1),
    .D5(1'b0),
    .D6(1'b0),
    .D7(1'b0),
    .D8(1'b0),
    .D9(1'b0),
    .PCLK(pix_clk),
    .FCLK(serial_clk),
    .RESET(~hdmi_rst_n),
    .Q(tmds_clk_serial)
);

// ==============================================================================
// LVDS Differential Output Buffers
// ==============================================================================
ELVDS_OBUF tmds_clk_obuf (
    .I(tmds_clk_serial),
    .O(O_tmds_clk_p),
    .OB(O_tmds_clk_n)
);

ELVDS_OBUF tmds_d0_obuf (
    .I(tmds_serial[0]),
    .O(O_tmds_data_p[0]),
    .OB(O_tmds_data_n[0])
);

ELVDS_OBUF tmds_d1_obuf (
    .I(tmds_serial[1]),
    .O(O_tmds_data_p[1]),
    .OB(O_tmds_data_n[1])
);

ELVDS_OBUF tmds_d2_obuf (
    .I(tmds_serial[2]),
    .O(O_tmds_data_p[2]),
    .OB(O_tmds_data_n[2])
);

endmodule
