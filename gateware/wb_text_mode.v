// wb_text_mode.v
// Text mode video generator based on DesignLab HQVGA example
// 80x26 characters @ 16x16 pixels each = 1280x416 pixels
// Simple white-on-blue text for testing

module wb_text_mode (
    input wire clk,
    input wire rst_n,
    input wire enable,
    
    // Video timing inputs
    input wire [11:0] pixel_x,
    input wire [11:0] pixel_y,
    input wire video_active,
    
    // Character RAM interface
    output wire [10:0] char_addr,  // 0-2047
    input wire [7:0] char_data,
    
    // Custom font RAM interface
    input wire custom_font_we,
    input wire [5:0] custom_font_addr,
    input wire [7:0] custom_font_data,
    
    // RGB output
    output reg [7:0] text_r,
    output reg [7:0] text_g,
    output reg [7:0] text_b,
    output reg text_valid
);

    // Text mode: 80x26 characters, 8x8 font, 16x16 pixels per character
    // 80 * 16 = 1280 pixels wide, 26 * 16 = 416 pixels tall
    wire [6:0] char_x = pixel_x[10:4];  // 0-79
    wire [4:0] char_y = pixel_y[8:4];   // 0-31 possible, but limit to 0-25
    
    // Pixel within character (0-15)
    wire [3:0] pixel_in_char_x = pixel_x[3:0];
    wire [3:0] pixel_in_char_y = pixel_y[3:0];
    
    // Font position (divide by 2 for 2x scaling)
    wire [2:0] font_col = pixel_in_char_x[3:1];  // 0-7
    wire [2:0] font_row = pixel_in_char_y[3:1];  // 0-7
    
    // Check if we're within the valid text area (first 416 pixels = 26 rows of 16)
    wire in_text_area = (pixel_y < 12'd416);
    
    // Character address: row * 80 + column
    wire [11:0] char_addr_calc = ({4'd0, char_y} * 7'd80) + {4'd0, char_x};
    assign char_addr = char_addr_calc[10:0];
    
    // Pipeline stage 1: Delay font_row and font_col to match character RAM latency (1 cycle)
    // Then delay again to match font ROM latency (1 cycle) = 2 total delays
    reg [2:0] font_row_d1;
    reg [2:0] font_col_d1, font_col_d2;
    reg video_active_d1, video_active_d2;
    reg in_text_area_d1, in_text_area_d2;
    
    always @(posedge clk) begin
        font_row_d1 <= font_row;     // Delay font_row by 1 cycle to match char_data
        font_col_d1 <= font_col;
        font_col_d2 <= font_col_d1;
        video_active_d1 <= video_active;
        video_active_d2 <= video_active_d1;
        in_text_area_d1 <= in_text_area;
        in_text_area_d2 <= in_text_area_d1;
    end
    
    // Font ROM instantiation - use IMMEDIATE signals, no delays
    wire [7:0] font_row_data;
    font_rom_8x8 font_rom (
        .clk(clk),
        .char_code(char_data),  // Use character from RAM
        .row(font_row),  // Use immediate font_row, not delayed
        .pixels(font_row_data),
        .custom_font_we(custom_font_we),
        .custom_font_addr(custom_font_addr),
        .custom_font_data(custom_font_data)
    );
    
    // Extract pixel from font row - try both to see which works
    wire font_pixel_reversed = font_row_data[7 - font_col];  // VGA standard (MSB first)
    wire font_pixel_direct = font_row_data[font_col];        // Direct indexing
    
    // Fixed colors
    localparam [23:0] WHITE = 24'hFFFFFF;
    localparam [23:0] BLACK = 24'h000000;
    localparam [23:0] BLUE  = 24'h0000AA;
    
    // Pipeline stage 2: Register font ROM output and extract pixel
    reg [7:0] font_row_data_d1;
    reg [2:0] font_col_d3;
    reg video_active_d3;
    reg in_text_area_d3;
    
    always @(posedge clk) begin
        font_row_data_d1 <= font_row_data;
        font_col_d3 <= font_col_d2;
        video_active_d3 <= video_active_d2;
        in_text_area_d3 <= in_text_area_d2;
    end
    
    // Extract pixel from delayed font row
    wire font_pixel = font_row_data_d1[7 - font_col_d3];  // VGA standard (MSB first)
    
    // Output logic with proper pipeline
    always @(posedge clk) begin
        if (!rst_n) begin
            text_r <= 8'h00;
            text_g <= 8'h00;
            text_b <= 8'h00;
            text_valid <= 0;
        end else begin
            text_valid <= video_active_d3;
            if (video_active_d3) begin
                if (in_text_area_d3) begin
                    // Within text area: show text
                    if (font_pixel) begin
                        // Foreground: white
                        text_r <= WHITE[23:16];
                        text_g <= WHITE[15:8];
                        text_b <= WHITE[7:0];
                    end else begin
                        // Background: blue
                        text_r <= BLUE[23:16];
                        text_g <= BLUE[15:8];
                        text_b <= BLUE[7:0];
                    end
                end else begin
                    // Outside text area: show BLACK (not blue)
                    text_r <= BLACK[23:16];
                    text_g <= BLACK[15:8];
                    text_b <= BLACK[7:0];
                end
            end else begin
                // Inactive video - show black
                text_r <= 8'h00;
                text_g <= 8'h00;
                text_b <= 8'h00;
            end
        end
    end

endmodule
