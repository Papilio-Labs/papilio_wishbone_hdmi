// ==============================================================================
// Video top module for 800x600 output using DVI_TX_Top IP
// Modified from Gowin's video_top.v for HQVGA integration
// 
// Clock generation:
//   27MHz -> TMDS_rPLL_250 -> 256.5MHz (serial) -> CLKDIV /5 -> 51.3MHz (pixel)
//
// Timing: 800x600@~72Hz (51.3MHz pixel clock, ~2.6% faster than standard 50MHz)
//   H_TOTAL=1040, H_SYNC=120, H_BACK=64, H_RES=800
//   V_TOTAL=666,  V_SYNC=6,   V_BACK=23, V_RES=600
// ==============================================================================

module video_top_800x600
#(
    parameter TEST_PATTERN = 1  // 1 = use internal test pattern, 0 = use external VGA input
)
(
    input             I_clk           , // 27MHz
    input             I_rst_n         ,
    // VGA input from HQVGA (directly usable)
    input             I_vga_vs        ,
    input             I_vga_hs        ,
    input             I_vga_de        ,
    input      [7:0]  I_vga_r         ,
    input      [7:0]  I_vga_g         ,
    input      [7:0]  I_vga_b         ,
    // Pixel clock output for HQVGA
    output            O_pix_clk       ,
    output            O_pix_clk_locked,
    // HDMI output
    output            O_tmds_clk_p    ,
    output            O_tmds_clk_n    ,
    output     [2:0]  O_tmds_data_p   , // {r,g,b}
    output     [2:0]  O_tmds_data_n
);

//==================================================
// Clock generation
// 27MHz -> 252MHz serial clock -> 50.4MHz pixel clock
//==================================================
wire serial_clk;
wire pll_lock;
wire pix_clk;
wire hdmi_rst_n;

// PLL: 27MHz -> 252MHz (27 * 56 / 6 = 252MHz)
// Pixel clock will be 252 / 5 = 50.4MHz (close to 50MHz for 800x600@72Hz)
TMDS_rPLL_250 u_tmds_rpll (
    .clkin(I_clk),
    .clkout(serial_clk),
    .lock(pll_lock)
);

assign hdmi_rst_n = I_rst_n & pll_lock;

// CLKDIV: serial_clk / 5 = pixel clock (50.4MHz)
CLKDIV u_clkdiv
(
    .RESETN(hdmi_rst_n),
    .HCLKIN(serial_clk),  // 5x pixel clock (252MHz)
    .CLKOUT(pix_clk),     // 1x pixel clock (50.4MHz)
    .CALIB(1'b1)
);
defparam u_clkdiv.DIV_MODE = "5";
defparam u_clkdiv.GSREN = "false";

assign O_pix_clk = pix_clk;
assign O_pix_clk_locked = pll_lock;

//==================================================
// Internal test pattern generator (800x600@72Hz timing)
//==================================================
localparam H_DISPLAY = 800;
localparam H_FRONT   = 56;
localparam H_SYNC    = 120;
localparam H_BACK    = 64;
localparam H_TOTAL   = H_DISPLAY + H_FRONT + H_SYNC + H_BACK;  // 1040

localparam V_DISPLAY = 600;
localparam V_FRONT   = 37;
localparam V_SYNC    = 6;
localparam V_BACK    = 23;
localparam V_TOTAL   = V_DISPLAY + V_FRONT + V_SYNC + V_BACK;  // 666

reg [10:0] h_cnt;
reg [9:0]  v_cnt;
reg        tp_hs;
reg        tp_vs;
reg        tp_de;
reg [7:0]  tp_r;
reg [7:0]  tp_g;
reg [7:0]  tp_b;

always @(posedge pix_clk or negedge hdmi_rst_n) begin
    if (!hdmi_rst_n) begin
        h_cnt <= 0;
        v_cnt <= 0;
    end else begin
        if (h_cnt == H_TOTAL - 1) begin
            h_cnt <= 0;
            if (v_cnt == V_TOTAL - 1)
                v_cnt <= 0;
            else
                v_cnt <= v_cnt + 1;
        end else begin
            h_cnt <= h_cnt + 1;
        end
    end
end

always @(posedge pix_clk or negedge hdmi_rst_n) begin
    if (!hdmi_rst_n) begin
        tp_hs <= 1'b1;
        tp_vs <= 1'b1;
        tp_de <= 1'b0;
        tp_r  <= 8'h00;
        tp_g  <= 8'h00;
        tp_b  <= 8'h00;
    end else begin
        // H sync: positive polarity for 800x600@72Hz
        tp_hs <= !((h_cnt >= H_DISPLAY + H_FRONT) && (h_cnt < H_DISPLAY + H_FRONT + H_SYNC));
        // V sync: positive polarity
        tp_vs <= !((v_cnt >= V_DISPLAY + V_FRONT) && (v_cnt < V_DISPLAY + V_FRONT + V_SYNC));
        // Data enable
        tp_de <= (h_cnt < H_DISPLAY) && (v_cnt < V_DISPLAY);
        
        // Test pattern: Color bars
        if ((h_cnt < H_DISPLAY) && (v_cnt < V_DISPLAY)) begin
            // 8 vertical color bars
            case (h_cnt[9:7])  // Divide 800 into 8 sections
                3'd0: begin tp_r <= 8'hFF; tp_g <= 8'hFF; tp_b <= 8'hFF; end  // White
                3'd1: begin tp_r <= 8'hFF; tp_g <= 8'hFF; tp_b <= 8'h00; end  // Yellow
                3'd2: begin tp_r <= 8'h00; tp_g <= 8'hFF; tp_b <= 8'hFF; end  // Cyan
                3'd3: begin tp_r <= 8'h00; tp_g <= 8'hFF; tp_b <= 8'h00; end  // Green
                3'd4: begin tp_r <= 8'hFF; tp_g <= 8'h00; tp_b <= 8'hFF; end  // Magenta
                3'd5: begin tp_r <= 8'hFF; tp_g <= 8'h00; tp_b <= 8'h00; end  // Red
                3'd6: begin tp_r <= 8'h00; tp_g <= 8'h00; tp_b <= 8'hFF; end  // Blue
                3'd7: begin tp_r <= 8'h00; tp_g <= 8'h00; tp_b <= 8'h00; end  // Black
            endcase
        end else begin
            tp_r <= 8'h00;
            tp_g <= 8'h00;
            tp_b <= 8'h00;
        end
    end
end

// Select between test pattern and external VGA input
wire use_tp_hs = TEST_PATTERN ? tp_hs : I_vga_hs;
wire use_tp_vs = TEST_PATTERN ? tp_vs : I_vga_vs;
wire use_tp_de = TEST_PATTERN ? tp_de : I_vga_de;
wire [7:0] use_tp_r = TEST_PATTERN ? tp_r : I_vga_r;
wire [7:0] use_tp_g = TEST_PATTERN ? tp_g : I_vga_g;
wire [7:0] use_tp_b = TEST_PATTERN ? tp_b : I_vga_b;

//==================================================
// DVI TX - Gowin IP for TMDS encoding
//==================================================
DVI_TX_Top DVI_TX_Top_inst
(
    .I_rst_n       (hdmi_rst_n     ),  // asynchronous reset, low active
    .I_serial_clk  (serial_clk     ),
    .I_rgb_clk     (pix_clk        ),  // pixel clock
    .I_rgb_vs      (use_tp_vs      ),
    .I_rgb_hs      (use_tp_hs      ),
    .I_rgb_de      (use_tp_de      ),
    .I_rgb_r       (use_tp_r       ),
    .I_rgb_g       (use_tp_g       ),
    .I_rgb_b       (use_tp_b       ),
    .O_tmds_clk_p  (O_tmds_clk_p   ),
    .O_tmds_clk_n  (O_tmds_clk_n   ),
    .O_tmds_data_p (O_tmds_data_p  ),
    .O_tmds_data_n (O_tmds_data_n  )
);

endmodule
