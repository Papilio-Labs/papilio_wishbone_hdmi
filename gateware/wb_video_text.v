// ==============================================================================
// wb_video_text.v - Wishbone Text Mode Video Generator
// ==============================================================================
// Standalone text mode generator with Wishbone control interface.
// 80x26 characters @ 16x16 pixels each = 1280x416 pixels (centered in 720p)
//
// This module can be instantiated independently - just connect it to the
// shared HDMI PHY layer (hdmi_phy_720p.v).
//
// Wishbone Register Map:
//   0x00: Reserved (mode control handled by top-level mux if needed)
//   0x01: Cursor X position (0-79)
//   0x02: Cursor Y position (0-25)
//   0x03: Default attribute (foreground/background color)
//   0x04: Write character at cursor (auto-advances cursor)
//   0x05: Reserved
//   0x06: RAM address pointer high nibble [11:8]
//   0x07: RAM address pointer low byte [7:0]
//   0x08: Direct character RAM write (increments pointer)
//   0x09: Direct attribute RAM write (increments pointer)
//   0x0A: Clear screen command (write any value)
//
// Attribute byte format: [7:4] = background color, [3:0] = foreground color
// Uses CGA 16-color palette.
//
// Usage: Instantiate this module and hdmi_phy_720p, connect RGB outputs
//        from this module to the PHY's RGB inputs.
// ==============================================================================

module wb_video_text
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
localparam TEXT_COLS = 80;
localparam TEXT_ROWS = 26;
localparam TEXT_SIZE = TEXT_COLS * TEXT_ROWS;  // 2080 characters

// ==============================================================================
// Character and Attribute RAM
// ==============================================================================
(* ram_style = "block" *)
reg [7:0] char_ram [0:TEXT_SIZE-1];
(* ram_style = "block" *)
reg [7:0] attr_ram [0:TEXT_SIZE-1];

// Note: RAM not pre-initialized - firmware should clear screen on startup
// Gowin synthesis doesn't support large initialization loops

// ==============================================================================
// Wishbone Control Registers
// ==============================================================================
reg [6:0] cursor_x;
reg [4:0] cursor_y;
reg [7:0] default_attr;
reg [11:0] ram_addr_ptr;

wire [11:0] cursor_addr = (cursor_y * TEXT_COLS) + {5'b0, cursor_x};
wire wb_valid = I_wb_stb && I_wb_cyc;

// Clear screen state machine
reg clear_active;
reg [11:0] clear_addr;

always @(posedge I_wb_clk or posedge I_wb_rst) begin
    if (I_wb_rst) begin
        cursor_x <= 7'd0;
        cursor_y <= 5'd0;
        default_attr <= 8'h0F;
        ram_addr_ptr <= 12'd0;
        clear_active <= 1'b0;
        clear_addr <= 12'd0;
        O_wb_ack <= 1'b0;
        O_wb_dat <= 8'h00;
    end else begin
        // Clear screen operation
        if (clear_active) begin
            if (clear_addr < TEXT_SIZE) begin
                char_ram[clear_addr] <= 8'h20;
                attr_ram[clear_addr] <= default_attr;
                clear_addr <= clear_addr + 1;
            end else begin
                clear_active <= 1'b0;
                cursor_x <= 7'd0;
                cursor_y <= 5'd0;
            end
        end
        
        // Wishbone access
        O_wb_ack <= wb_valid && !O_wb_ack && !clear_active;
        
        if (wb_valid && I_wb_we && !O_wb_ack && !clear_active) begin
            case (I_wb_adr[3:0])
                4'h1: cursor_x <= I_wb_dat[6:0];
                4'h2: cursor_y <= I_wb_dat[4:0];
                4'h3: default_attr <= I_wb_dat;
                4'h4: begin  // Write character at cursor
                    if (cursor_addr < TEXT_SIZE) begin
                        char_ram[cursor_addr] <= I_wb_dat;
                        attr_ram[cursor_addr] <= default_attr;
                        // Auto-advance cursor
                        if (cursor_x < TEXT_COLS - 1)
                            cursor_x <= cursor_x + 1;
                        else begin
                            cursor_x <= 0;
                            if (cursor_y < TEXT_ROWS - 1)
                                cursor_y <= cursor_y + 1;
                        end
                    end
                end
                4'h6: ram_addr_ptr[11:8] <= I_wb_dat[3:0];
                4'h7: ram_addr_ptr[7:0] <= I_wb_dat;
                4'h8: begin  // Direct char RAM write
                    if (ram_addr_ptr < TEXT_SIZE) begin
                        char_ram[ram_addr_ptr] <= I_wb_dat;
                        ram_addr_ptr <= ram_addr_ptr + 1;
                    end
                end
                4'h9: begin  // Direct attr RAM write
                    if (ram_addr_ptr < TEXT_SIZE) begin
                        attr_ram[ram_addr_ptr] <= I_wb_dat;
                        ram_addr_ptr <= ram_addr_ptr + 1;
                    end
                end
                4'hA: begin  // Clear screen
                    clear_active <= 1'b1;
                    clear_addr <= 12'd0;
                end
                default: ;
            endcase
        end
        
        // Wishbone read
        if (wb_valid && !I_wb_we && !clear_active) begin
            case (I_wb_adr[3:0])
                4'h1: O_wb_dat <= {1'b0, cursor_x};
                4'h2: O_wb_dat <= {3'b0, cursor_y};
                4'h3: O_wb_dat <= default_attr;
                4'h4: O_wb_dat <= (cursor_addr < TEXT_SIZE) ? char_ram[cursor_addr] : 8'h00;
                4'h6: O_wb_dat <= {4'b0, ram_addr_ptr[11:8]};
                4'h7: O_wb_dat <= ram_addr_ptr[7:0];
                default: O_wb_dat <= 8'h00;
            endcase
        end
    end
end

// ==============================================================================
// Text Rendering Pipeline (Pixel Clock Domain)
// ==============================================================================
// Text area: 80x26 chars @ 16x16 pixels = 1280x416 pixels
// Vertical centering: (720-416)/2 = 152 pixels offset

localparam V_TEXT_START = 12'd152;
localparam V_TEXT_END   = 12'd568;  // 152 + 416

// Character position from pixel position
wire [6:0] char_col = I_active_x[10:4];  // / 16
wire [4:0] char_row = (I_active_y - V_TEXT_START) >> 4;
wire [2:0] font_col = I_active_x[3:1];   // / 2 (2x scale)
wire [2:0] font_row = (I_active_y - V_TEXT_START) >> 1;  // / 2 (2x scale)

wire in_text_area = (I_active_y >= V_TEXT_START) && (I_active_y < V_TEXT_END);

// Character address
wire [11:0] text_char_addr = (char_row * TEXT_COLS) + {5'b0, char_col};

// Pipeline stage 1: Read character and attribute from RAM
reg [7:0] char_data_d1;
reg [7:0] attr_data_d1;
reg [2:0] font_col_d1, font_row_d1;
reg in_text_d1, de_d1, hs_d1, vs_d1;

always @(posedge I_pix_clk) begin
    if (text_char_addr < TEXT_SIZE) begin
        char_data_d1 <= char_ram[text_char_addr];
        attr_data_d1 <= attr_ram[text_char_addr];
    end else begin
        char_data_d1 <= 8'h20;
        attr_data_d1 <= 8'h0F;
    end
    font_col_d1 <= font_col;
    font_row_d1 <= font_row;
    in_text_d1 <= in_text_area;
    de_d1 <= I_de;
    hs_d1 <= I_hs;
    vs_d1 <= I_vs;
end

// Pipeline stage 2: Font ROM lookup
wire [7:0] font_pixels;
font_rom_8x8 u_font_rom (
    .clk(I_pix_clk),
    .char_code(char_data_d1),
    .row(font_row_d1[2:0]),
    .pixels(font_pixels),
    .custom_font_we(1'b0),
    .custom_font_addr(6'd0),
    .custom_font_data(8'd0)
);

reg [7:0] attr_data_d2;
reg [2:0] font_col_d2;
reg in_text_d2, de_d2, hs_d2, vs_d2;

always @(posedge I_pix_clk) begin
    attr_data_d2 <= attr_data_d1;
    font_col_d2 <= font_col_d1;
    in_text_d2 <= in_text_d1;
    de_d2 <= de_d1;
    hs_d2 <= hs_d1;
    vs_d2 <= vs_d1;
end

// Pipeline stage 3: Extract pixel and apply color
reg [7:0] font_pixels_d3;
reg [7:0] attr_data_d3;
reg [2:0] font_col_d3;
reg in_text_d3, de_d3, hs_d3, vs_d3;

always @(posedge I_pix_clk) begin
    font_pixels_d3 <= font_pixels;
    attr_data_d3 <= attr_data_d2;
    font_col_d3 <= font_col_d2;
    in_text_d3 <= in_text_d2;
    de_d3 <= de_d2;
    hs_d3 <= hs_d2;
    vs_d3 <= vs_d2;
end

// Font pixel extraction
wire font_pixel = font_pixels_d3[7 - font_col_d3];
wire [3:0] fg_color = attr_data_d3[3:0];
wire [3:0] bg_color = attr_data_d3[7:4];

// CGA 16-color palette
function [23:0] cga_color;
    input [3:0] color;
    begin
        case (color)
            4'h0: cga_color = 24'h000000;  // Black
            4'h1: cga_color = 24'h0000AA;  // Blue
            4'h2: cga_color = 24'h00AA00;  // Green
            4'h3: cga_color = 24'h00AAAA;  // Cyan
            4'h4: cga_color = 24'hAA0000;  // Red
            4'h5: cga_color = 24'hAA00AA;  // Magenta
            4'h6: cga_color = 24'hAA5500;  // Brown
            4'h7: cga_color = 24'hAAAAAA;  // Light gray
            4'h8: cga_color = 24'h555555;  // Dark gray
            4'h9: cga_color = 24'h5555FF;  // Light blue
            4'hA: cga_color = 24'h55FF55;  // Light green
            4'hB: cga_color = 24'h55FFFF;  // Light cyan
            4'hC: cga_color = 24'hFF5555;  // Light red
            4'hD: cga_color = 24'hFF55FF;  // Light magenta
            4'hE: cga_color = 24'hFFFF55;  // Yellow
            4'hF: cga_color = 24'hFFFFFF;  // White
        endcase
    end
endfunction

// Pipeline stage 4: Final color output
always @(posedge I_pix_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
        O_rgb_r <= 8'd0;
        O_rgb_g <= 8'd0;
        O_rgb_b <= 8'd0;
        O_rgb_de <= 1'b0;
        O_rgb_hs <= 1'b0;
        O_rgb_vs <= 1'b0;
    end else begin
        O_rgb_de <= de_d3;
        O_rgb_hs <= hs_d3;
        O_rgb_vs <= vs_d3;
        
        if (de_d3 && in_text_d3) begin
            if (font_pixel) begin
                {O_rgb_r, O_rgb_g, O_rgb_b} <= cga_color(fg_color);
            end else begin
                {O_rgb_r, O_rgb_g, O_rgb_b} <= cga_color(bg_color);
            end
        end else begin
            O_rgb_r <= 8'd0;
            O_rgb_g <= 8'd0;
            O_rgb_b <= 8'd0;
        end
    end
end

endmodule
