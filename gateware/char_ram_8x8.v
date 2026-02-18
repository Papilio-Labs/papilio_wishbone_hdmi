// char_ram_8x8.v
// Character RAM and ROM font for 80x30 text mode (640x480 @ 8x16 chars)
// Port for video scan (read-only) and Wishbone interface (read/write)

module char_ram_8x8 (
    // Video scan interface
    input wire v_clk,
    input wire v_en,
    input wire [11:0] v_addr,  // 80x30 = 2400 addresses (12 bits)
    output reg [7:0] v_char,   // Character code
    output reg [7:0] v_attr,   // Attribute (foreground/background color)
    
    // Wishbone interface for MCU writes
    input wire wb_clk,
    input wire [11:0] wb_addr,
    input wire [7:0] wb_dat_i,
    output reg [7:0] wb_dat_o,
    input wire wb_we,
    input wire wb_en,
    input wire wb_addr_sel  // 0=char, 1=attr
);

    // Dual-port RAM for character codes (2400 bytes for 80x30)
    reg [7:0] char_ram [0:2399];
    
    // Dual-port RAM for attributes (2400 bytes for 80x30)
    reg [7:0] attr_ram [0:2399];
    
    // Initialize character RAM with spaces
    integer i;
    initial begin
        for (i = 0; i < 2400; i = i + 1) begin
            char_ram[i] = 8'h20;  // Space character
            attr_ram[i] = 8'h07;  // White on black
        end
    end
    
    // Video scan read port
    always @(posedge v_clk) begin
        if (v_en && v_addr < 2400) begin
            v_char <= char_ram[v_addr];
            v_attr <= attr_ram[v_addr];
        end
    end
    
    // Wishbone write/read port
    always @(posedge wb_clk) begin
        if (wb_en && wb_addr < 2400) begin
            if (wb_we) begin
                if (wb_addr_sel == 0)
                    char_ram[wb_addr] <= wb_dat_i;
                else
                    attr_ram[wb_addr] <= wb_dat_i;
            end
            wb_dat_o <= wb_addr_sel ? attr_ram[wb_addr] : char_ram[wb_addr];
        end
    end

endmodule


// font_rom_8x8.v
// 8x8 font ROM containing standard ASCII characters
// with custom font RAM for characters 0x00-0x07 (LCD custom characters)
(* syn_keep = "true" *)
module font_rom_8x8 (
    input wire clk,
    input wire [7:0] char_code,
    input wire [2:0] row,
    output reg [7:0] pixels,
    
    // Custom font RAM interface (for LCD createChar support)
    input wire custom_font_we,
    input wire [5:0] custom_font_addr,  // 8 chars * 8 rows = 6 bits
    input wire [7:0] custom_font_data
);

    // Custom font RAM for characters 0x00-0x07 (8 chars * 8 rows = 64 bytes)
    reg [7:0] custom_font_ram [0:63];
    
    // Font ROM - 256 characters x 8 rows x 8 pixels
    // Using standard VGA 8x8 font data
    wire [10:0] addr = {char_code, row};
    
    // Check if this is a custom character (0x00-0x07)
    wire is_custom = (char_code[7:3] == 5'b00000);  // Characters 0x00-0x07
    wire [5:0] custom_addr = {char_code[2:0], row};
    
    // Registered lookup for font data to prevent optimization
    reg [7:0] pixels_comb;
    
    always @(posedge clk) begin
        if (custom_font_we) begin
            custom_font_ram[custom_font_addr] <= custom_font_data;
        end
        
        pixels <= is_custom ? custom_font_ram[custom_addr] : pixels_comb;
    end
    
    // Combinational lookup for font data
    always @(*) begin
        case (addr[10:3])  // Character code
            8'h20: pixels_comb = (addr[2:0] == 0) ? 8'h00 : (addr[2:0] == 1) ? 8'h00 : (addr[2:0] == 2) ? 8'h00 : (addr[2:0] == 3) ? 8'h00 : (addr[2:0] == 4) ? 8'h00 : (addr[2:0] == 5) ? 8'h00 : (addr[2:0] == 6) ? 8'h00 : 8'h00; // Space
            8'h21: pixels_comb = (addr[2:0] == 0) ? 8'h18 : (addr[2:0] == 1) ? 8'h3C : (addr[2:0] == 2) ? 8'h3C : (addr[2:0] == 3) ? 8'h18 : (addr[2:0] == 4) ? 8'h18 : (addr[2:0] == 5) ? 8'h00 : (addr[2:0] == 6) ? 8'h18 : 8'h00; // !
            8'h2D: pixels_comb = (addr[2:0] == 0) ? 8'h00 : (addr[2:0] == 1) ? 8'h00 : (addr[2:0] == 2) ? 8'h00 : (addr[2:0] == 3) ? 8'h7E : (addr[2:0] == 4) ? 8'h00 : (addr[2:0] == 5) ? 8'h00 : (addr[2:0] == 6) ? 8'h00 : 8'h00; // -
            8'h2E: pixels_comb = (addr[2:0] == 0) ? 8'h00 : (addr[2:0] == 1) ? 8'h00 : (addr[2:0] == 2) ? 8'h00 : (addr[2:0] == 3) ? 8'h00 : (addr[2:0] == 4) ? 8'h00 : (addr[2:0] == 5) ? 8'h18 : (addr[2:0] == 6) ? 8'h18 : 8'h00; // .
            8'h2F: pixels_comb = (addr[2:0] == 0) ? 8'h00 : (addr[2:0] == 1) ? 8'h03 : (addr[2:0] == 2) ? 8'h06 : (addr[2:0] == 3) ? 8'h0C : (addr[2:0] == 4) ? 8'h18 : (addr[2:0] == 5) ? 8'h30 : (addr[2:0] == 6) ? 8'h60 : 8'h00; // /
            8'h3A: pixels_comb = (addr[2:0] == 0) ? 8'h00 : (addr[2:0] == 1) ? 8'h00 : (addr[2:0] == 2) ? 8'h18 : (addr[2:0] == 3) ? 8'h00 : (addr[2:0] == 4) ? 8'h00 : (addr[2:0] == 5) ? 8'h18 : (addr[2:0] == 6) ? 8'h00 : 8'h00; // :
            8'h30: pixels_comb = (addr[2:0] == 0) ? 8'h3C : (addr[2:0] == 1) ? 8'h66 : (addr[2:0] == 2) ? 8'h6E : (addr[2:0] == 3) ? 8'h76 : (addr[2:0] == 4) ? 8'h66 : (addr[2:0] == 5) ? 8'h66 : (addr[2:0] == 6) ? 8'h3C : 8'h00; // 0
            8'h31: pixels_comb = (addr[2:0] == 0) ? 8'h18 : (addr[2:0] == 1) ? 8'h38 : (addr[2:0] == 2) ? 8'h18 : (addr[2:0] == 3) ? 8'h18 : (addr[2:0] == 4) ? 8'h18 : (addr[2:0] == 5) ? 8'h18 : (addr[2:0] == 6) ? 8'h7E : 8'h00; // 1
            8'h32: pixels_comb = (addr[2:0] == 0) ? 8'h3C : (addr[2:0] == 1) ? 8'h66 : (addr[2:0] == 2) ? 8'h06 : (addr[2:0] == 3) ? 8'h1C : (addr[2:0] == 4) ? 8'h30 : (addr[2:0] == 5) ? 8'h66 : (addr[2:0] == 6) ? 8'h7E : 8'h00; // 2
            8'h33: pixels_comb = (addr[2:0] == 0) ? 8'h3C : (addr[2:0] == 1) ? 8'h66 : (addr[2:0] == 2) ? 8'h06 : (addr[2:0] == 3) ? 8'h1C : (addr[2:0] == 4) ? 8'h06 : (addr[2:0] == 5) ? 8'h66 : (addr[2:0] == 6) ? 8'h3C : 8'h00; // 3
            8'h34: pixels_comb = (addr[2:0] == 0) ? 8'h0C : (addr[2:0] == 1) ? 8'h1C : (addr[2:0] == 2) ? 8'h3C : (addr[2:0] == 3) ? 8'h6C : (addr[2:0] == 4) ? 8'h7E : (addr[2:0] == 5) ? 8'h0C : (addr[2:0] == 6) ? 8'h0C : 8'h00; // 4
            8'h35: pixels_comb = (addr[2:0] == 0) ? 8'h7E : (addr[2:0] == 1) ? 8'h60 : (addr[2:0] == 2) ? 8'h7C : (addr[2:0] == 3) ? 8'h06 : (addr[2:0] == 4) ? 8'h06 : (addr[2:0] == 5) ? 8'h66 : (addr[2:0] == 6) ? 8'h3C : 8'h00; // 5
            8'h36: pixels_comb = (addr[2:0] == 0) ? 8'h1C : (addr[2:0] == 1) ? 8'h30 : (addr[2:0] == 2) ? 8'h60 : (addr[2:0] == 3) ? 8'h7C : (addr[2:0] == 4) ? 8'h66 : (addr[2:0] == 5) ? 8'h66 : (addr[2:0] == 6) ? 8'h3C : 8'h00; // 6
            8'h37: pixels_comb = (addr[2:0] == 0) ? 8'h7E : (addr[2:0] == 1) ? 8'h06 : (addr[2:0] == 2) ? 8'h0C : (addr[2:0] == 3) ? 8'h18 : (addr[2:0] == 4) ? 8'h30 : (addr[2:0] == 5) ? 8'h30 : (addr[2:0] == 6) ? 8'h30 : 8'h00; // 7
            8'h38: pixels_comb = (addr[2:0] == 0) ? 8'h3C : (addr[2:0] == 1) ? 8'h66 : (addr[2:0] == 2) ? 8'h66 : (addr[2:0] == 3) ? 8'h3C : (addr[2:0] == 4) ? 8'h66 : (addr[2:0] == 5) ? 8'h66 : (addr[2:0] == 6) ? 8'h3C : 8'h00; // 8
            8'h39: pixels_comb = (addr[2:0] == 0) ? 8'h3C : (addr[2:0] == 1) ? 8'h66 : (addr[2:0] == 2) ? 8'h66 : (addr[2:0] == 3) ? 8'h3E : (addr[2:0] == 4) ? 8'h06 : (addr[2:0] == 5) ? 8'h0C : (addr[2:0] == 6) ? 8'h38 : 8'h00; // 9
            8'h40: pixels_comb = (addr[2:0] == 0) ? 8'h3C : (addr[2:0] == 1) ? 8'h66 : (addr[2:0] == 2) ? 8'h6E : (addr[2:0] == 3) ? 8'h6E : (addr[2:0] == 4) ? 8'h60 : (addr[2:0] == 5) ? 8'h62 : (addr[2:0] == 6) ? 8'h3C : 8'h00; // @
            8'h41: pixels_comb = (addr[2:0] == 0) ? 8'h3C : (addr[2:0] == 1) ? 8'h66 : (addr[2:0] == 2) ? 8'h66 : (addr[2:0] == 3) ? 8'h7E : (addr[2:0] == 4) ? 8'h66 : (addr[2:0] == 5) ? 8'h66 : (addr[2:0] == 6) ? 8'h66 : 8'h00; // A
            8'h42: pixels_comb = (addr[2:0] == 0) ? 8'h7C : (addr[2:0] == 1) ? 8'h66 : (addr[2:0] == 2) ? 8'h66 : (addr[2:0] == 3) ? 8'h7C : (addr[2:0] == 4) ? 8'h66 : (addr[2:0] == 5) ? 8'h66 : (addr[2:0] == 6) ? 8'h7C : 8'h00; // B
            8'h43: pixels_comb = (addr[2:0] == 0) ? 8'h3C : (addr[2:0] == 1) ? 8'h66 : (addr[2:0] == 2) ? 8'h60 : (addr[2:0] == 3) ? 8'h60 : (addr[2:0] == 4) ? 8'h60 : (addr[2:0] == 5) ? 8'h66 : (addr[2:0] == 6) ? 8'h3C : 8'h00; // C
            8'h44: pixels_comb = (addr[2:0] == 0) ? 8'h78 : (addr[2:0] == 1) ? 8'h6C : (addr[2:0] == 2) ? 8'h66 : (addr[2:0] == 3) ? 8'h66 : (addr[2:0] == 4) ? 8'h66 : (addr[2:0] == 5) ? 8'h6C : (addr[2:0] == 6) ? 8'h78 : 8'h00; // D
            8'h45: pixels_comb = (addr[2:0] == 0) ? 8'h7E : (addr[2:0] == 1) ? 8'h60 : (addr[2:0] == 2) ? 8'h60 : (addr[2:0] == 3) ? 8'h7C : (addr[2:0] == 4) ? 8'h60 : (addr[2:0] == 5) ? 8'h60 : (addr[2:0] == 6) ? 8'h7E : 8'h00; // E
            8'h46: pixels_comb = (addr[2:0] == 0) ? 8'h7E : (addr[2:0] == 1) ? 8'h60 : (addr[2:0] == 2) ? 8'h60 : (addr[2:0] == 3) ? 8'h7C : (addr[2:0] == 4) ? 8'h60 : (addr[2:0] == 5) ? 8'h60 : (addr[2:0] == 6) ? 8'h60 : 8'h00; // F
            8'h47: pixels_comb = (addr[2:0] == 0) ? 8'h3C : (addr[2:0] == 1) ? 8'h66 : (addr[2:0] == 2) ? 8'h60 : (addr[2:0] == 3) ? 8'h6E : (addr[2:0] == 4) ? 8'h66 : (addr[2:0] == 5) ? 8'h66 : (addr[2:0] == 6) ? 8'h3C : 8'h00; // G
            8'h48: pixels_comb = (addr[2:0] == 0) ? 8'h66 : (addr[2:0] == 1) ? 8'h66 : (addr[2:0] == 2) ? 8'h66 : (addr[2:0] == 3) ? 8'h7E : (addr[2:0] == 4) ? 8'h66 : (addr[2:0] == 5) ? 8'h66 : (addr[2:0] == 6) ? 8'h66 : 8'h00; // H
            8'h49: pixels_comb = (addr[2:0] == 0) ? 8'h3C : (addr[2:0] == 1) ? 8'h18 : (addr[2:0] == 2) ? 8'h18 : (addr[2:0] == 3) ? 8'h18 : (addr[2:0] == 4) ? 8'h18 : (addr[2:0] == 5) ? 8'h18 : (addr[2:0] == 6) ? 8'h3C : 8'h00; // I
            8'h4A: pixels_comb = (addr[2:0] == 0) ? 8'h1E : (addr[2:0] == 1) ? 8'h0C : (addr[2:0] == 2) ? 8'h0C : (addr[2:0] == 3) ? 8'h0C : (addr[2:0] == 4) ? 8'h0C : (addr[2:0] == 5) ? 8'h6C : (addr[2:0] == 6) ? 8'h38 : 8'h00; // J
            8'h4B: pixels_comb = (addr[2:0] == 0) ? 8'h66 : (addr[2:0] == 1) ? 8'h6C : (addr[2:0] == 2) ? 8'h78 : (addr[2:0] == 3) ? 8'h70 : (addr[2:0] == 4) ? 8'h78 : (addr[2:0] == 5) ? 8'h6C : (addr[2:0] == 6) ? 8'h66 : 8'h00; // K
            8'h4C: pixels_comb = (addr[2:0] == 0) ? 8'h60 : (addr[2:0] == 1) ? 8'h60 : (addr[2:0] == 2) ? 8'h60 : (addr[2:0] == 3) ? 8'h60 : (addr[2:0] == 4) ? 8'h60 : (addr[2:0] == 5) ? 8'h60 : (addr[2:0] == 6) ? 8'h7E : 8'h00; // L
            8'h4D: pixels_comb = (addr[2:0] == 0) ? 8'h63 : (addr[2:0] == 1) ? 8'h77 : (addr[2:0] == 2) ? 8'h7F : (addr[2:0] == 3) ? 8'h6B : (addr[2:0] == 4) ? 8'h63 : (addr[2:0] == 5) ? 8'h63 : (addr[2:0] == 6) ? 8'h63 : 8'h00; // M
            8'h4E: pixels_comb = (addr[2:0] == 0) ? 8'h66 : (addr[2:0] == 1) ? 8'h76 : (addr[2:0] == 2) ? 8'h7E : (addr[2:0] == 3) ? 8'h7E : (addr[2:0] == 4) ? 8'h6E : (addr[2:0] == 5) ? 8'h66 : (addr[2:0] == 6) ? 8'h66 : 8'h00; // N
            8'h4F: pixels_comb = (addr[2:0] == 0) ? 8'h3C : (addr[2:0] == 1) ? 8'h66 : (addr[2:0] == 2) ? 8'h66 : (addr[2:0] == 3) ? 8'h66 : (addr[2:0] == 4) ? 8'h66 : (addr[2:0] == 5) ? 8'h66 : (addr[2:0] == 6) ? 8'h3C : 8'h00; // O
            8'h50: pixels_comb = (addr[2:0] == 0) ? 8'h7C : (addr[2:0] == 1) ? 8'h66 : (addr[2:0] == 2) ? 8'h66 : (addr[2:0] == 3) ? 8'h7C : (addr[2:0] == 4) ? 8'h60 : (addr[2:0] == 5) ? 8'h60 : (addr[2:0] == 6) ? 8'h60 : 8'h00; // P
            8'h51: pixels_comb = (addr[2:0] == 0) ? 8'h3C : (addr[2:0] == 1) ? 8'h66 : (addr[2:0] == 2) ? 8'h66 : (addr[2:0] == 3) ? 8'h66 : (addr[2:0] == 4) ? 8'h66 : (addr[2:0] == 5) ? 8'h3C : (addr[2:0] == 6) ? 8'h0E : 8'h00; // Q
            8'h52: pixels_comb = (addr[2:0] == 0) ? 8'h7C : (addr[2:0] == 1) ? 8'h66 : (addr[2:0] == 2) ? 8'h66 : (addr[2:0] == 3) ? 8'h7C : (addr[2:0] == 4) ? 8'h78 : (addr[2:0] == 5) ? 8'h6C : (addr[2:0] == 6) ? 8'h66 : 8'h00; // R
            8'h53: pixels_comb = (addr[2:0] == 0) ? 8'h3C : (addr[2:0] == 1) ? 8'h66 : (addr[2:0] == 2) ? 8'h60 : (addr[2:0] == 3) ? 8'h3C : (addr[2:0] == 4) ? 8'h06 : (addr[2:0] == 5) ? 8'h66 : (addr[2:0] == 6) ? 8'h3C : 8'h00; // S
            8'h54: pixels_comb = (addr[2:0] == 0) ? 8'h7E : (addr[2:0] == 1) ? 8'h18 : (addr[2:0] == 2) ? 8'h18 : (addr[2:0] == 3) ? 8'h18 : (addr[2:0] == 4) ? 8'h18 : (addr[2:0] == 5) ? 8'h18 : (addr[2:0] == 6) ? 8'h18 : 8'h00; // T
            8'h55: pixels_comb = (addr[2:0] == 0) ? 8'h66 : (addr[2:0] == 1) ? 8'h66 : (addr[2:0] == 2) ? 8'h66 : (addr[2:0] == 3) ? 8'h66 : (addr[2:0] == 4) ? 8'h66 : (addr[2:0] == 5) ? 8'h66 : (addr[2:0] == 6) ? 8'h3C : 8'h00; // U
            8'h56: pixels_comb = (addr[2:0] == 0) ? 8'h66 : (addr[2:0] == 1) ? 8'h66 : (addr[2:0] == 2) ? 8'h66 : (addr[2:0] == 3) ? 8'h66 : (addr[2:0] == 4) ? 8'h66 : (addr[2:0] == 5) ? 8'h3C : (addr[2:0] == 6) ? 8'h18 : 8'h00; // V
            8'h57: pixels_comb = (addr[2:0] == 0) ? 8'h63 : (addr[2:0] == 1) ? 8'h63 : (addr[2:0] == 2) ? 8'h63 : (addr[2:0] == 3) ? 8'h6B : (addr[2:0] == 4) ? 8'h7F : (addr[2:0] == 5) ? 8'h77 : (addr[2:0] == 6) ? 8'h63 : 8'h00; // W
            8'h58: pixels_comb = (addr[2:0] == 0) ? 8'h66 : (addr[2:0] == 1) ? 8'h66 : (addr[2:0] == 2) ? 8'h3C : (addr[2:0] == 3) ? 8'h18 : (addr[2:0] == 4) ? 8'h3C : (addr[2:0] == 5) ? 8'h66 : (addr[2:0] == 6) ? 8'h66 : 8'h00; // X
            8'h59: pixels_comb = (addr[2:0] == 0) ? 8'h66 : (addr[2:0] == 1) ? 8'h66 : (addr[2:0] == 2) ? 8'h66 : (addr[2:0] == 3) ? 8'h3C : (addr[2:0] == 4) ? 8'h18 : (addr[2:0] == 5) ? 8'h18 : (addr[2:0] == 6) ? 8'h18 : 8'h00; // Y
            8'h5A: pixels_comb = (addr[2:0] == 0) ? 8'h7E : (addr[2:0] == 1) ? 8'h06 : (addr[2:0] == 2) ? 8'h0C : (addr[2:0] == 3) ? 8'h18 : (addr[2:0] == 4) ? 8'h30 : (addr[2:0] == 5) ? 8'h60 : (addr[2:0] == 6) ? 8'h7E : 8'h00; // Z
            8'h61: pixels_comb = (addr[2:0] == 0) ? 8'h00 : (addr[2:0] == 1) ? 8'h00 : (addr[2:0] == 2) ? 8'h3C : (addr[2:0] == 3) ? 8'h06 : (addr[2:0] == 4) ? 8'h3E : (addr[2:0] == 5) ? 8'h66 : (addr[2:0] == 6) ? 8'h3E : 8'h00; // a
            8'h62: pixels_comb = (addr[2:0] == 0) ? 8'h60 : (addr[2:0] == 1) ? 8'h60 : (addr[2:0] == 2) ? 8'h7C : (addr[2:0] == 3) ? 8'h66 : (addr[2:0] == 4) ? 8'h66 : (addr[2:0] == 5) ? 8'h66 : (addr[2:0] == 6) ? 8'h7C : 8'h00; // b
            8'h63: pixels_comb = (addr[2:0] == 0) ? 8'h00 : (addr[2:0] == 1) ? 8'h00 : (addr[2:0] == 2) ? 8'h3C : (addr[2:0] == 3) ? 8'h66 : (addr[2:0] == 4) ? 8'h60 : (addr[2:0] == 5) ? 8'h66 : (addr[2:0] == 6) ? 8'h3C : 8'h00; // c
            8'h64: pixels_comb = (addr[2:0] == 0) ? 8'h06 : (addr[2:0] == 1) ? 8'h06 : (addr[2:0] == 2) ? 8'h3E : (addr[2:0] == 3) ? 8'h66 : (addr[2:0] == 4) ? 8'h66 : (addr[2:0] == 5) ? 8'h66 : (addr[2:0] == 6) ? 8'h3E : 8'h00; // d
            8'h65: pixels_comb = (addr[2:0] == 0) ? 8'h00 : (addr[2:0] == 1) ? 8'h00 : (addr[2:0] == 2) ? 8'h3C : (addr[2:0] == 3) ? 8'h66 : (addr[2:0] == 4) ? 8'h7E : (addr[2:0] == 5) ? 8'h60 : (addr[2:0] == 6) ? 8'h3C : 8'h00; // e
            8'h66: pixels_comb = (addr[2:0] == 0) ? 8'h0E : (addr[2:0] == 1) ? 8'h18 : (addr[2:0] == 2) ? 8'h18 : (addr[2:0] == 3) ? 8'h7E : (addr[2:0] == 4) ? 8'h18 : (addr[2:0] == 5) ? 8'h18 : (addr[2:0] == 6) ? 8'h18 : 8'h00; // f
            8'h67: pixels_comb = (addr[2:0] == 0) ? 8'h00 : (addr[2:0] == 1) ? 8'h00 : (addr[2:0] == 2) ? 8'h3E : (addr[2:0] == 3) ? 8'h66 : (addr[2:0] == 4) ? 8'h66 : (addr[2:0] == 5) ? 8'h3E : (addr[2:0] == 6) ? 8'h06 : 8'h7C; // g
            8'h68: pixels_comb = (addr[2:0] == 0) ? 8'h60 : (addr[2:0] == 1) ? 8'h60 : (addr[2:0] == 2) ? 8'h7C : (addr[2:0] == 3) ? 8'h66 : (addr[2:0] == 4) ? 8'h66 : (addr[2:0] == 5) ? 8'h66 : (addr[2:0] == 6) ? 8'h66 : 8'h00; // h
            8'h69: pixels_comb = (addr[2:0] == 0) ? 8'h18 : (addr[2:0] == 1) ? 8'h00 : (addr[2:0] == 2) ? 8'h38 : (addr[2:0] == 3) ? 8'h18 : (addr[2:0] == 4) ? 8'h18 : (addr[2:0] == 5) ? 8'h18 : (addr[2:0] == 6) ? 8'h3C : 8'h00; // i
            8'h6A: pixels_comb = (addr[2:0] == 0) ? 8'h0C : (addr[2:0] == 1) ? 8'h00 : (addr[2:0] == 2) ? 8'h0C : (addr[2:0] == 3) ? 8'h0C : (addr[2:0] == 4) ? 8'h0C : (addr[2:0] == 5) ? 8'h6C : (addr[2:0] == 6) ? 8'h38 : 8'h00; // j
            8'h6B: pixels_comb = (addr[2:0] == 0) ? 8'h60 : (addr[2:0] == 1) ? 8'h60 : (addr[2:0] == 2) ? 8'h66 : (addr[2:0] == 3) ? 8'h6C : (addr[2:0] == 4) ? 8'h78 : (addr[2:0] == 5) ? 8'h6C : (addr[2:0] == 6) ? 8'h66 : 8'h00; // k
            8'h6C: pixels_comb = (addr[2:0] == 0) ? 8'h38 : (addr[2:0] == 1) ? 8'h18 : (addr[2:0] == 2) ? 8'h18 : (addr[2:0] == 3) ? 8'h18 : (addr[2:0] == 4) ? 8'h18 : (addr[2:0] == 5) ? 8'h18 : (addr[2:0] == 6) ? 8'h3C : 8'h00; // l
            8'h6D: pixels_comb = (addr[2:0] == 0) ? 8'h00 : (addr[2:0] == 1) ? 8'h00 : (addr[2:0] == 2) ? 8'h66 : (addr[2:0] == 3) ? 8'h7F : (addr[2:0] == 4) ? 8'h7F : (addr[2:0] == 5) ? 8'h6B : (addr[2:0] == 6) ? 8'h63 : 8'h00; // m
            8'h6E: pixels_comb = (addr[2:0] == 0) ? 8'h00 : (addr[2:0] == 1) ? 8'h00 : (addr[2:0] == 2) ? 8'h5C : (addr[2:0] == 3) ? 8'h66 : (addr[2:0] == 4) ? 8'h66 : (addr[2:0] == 5) ? 8'h66 : (addr[2:0] == 6) ? 8'h66 : 8'h00; // n
            8'h6F: pixels_comb = (addr[2:0] == 0) ? 8'h00 : (addr[2:0] == 1) ? 8'h00 : (addr[2:0] == 2) ? 8'h3C : (addr[2:0] == 3) ? 8'h66 : (addr[2:0] == 4) ? 8'h66 : (addr[2:0] == 5) ? 8'h66 : (addr[2:0] == 6) ? 8'h3C : 8'h00; // o
            8'h70: pixels_comb = (addr[2:0] == 0) ? 8'h00 : (addr[2:0] == 1) ? 8'h00 : (addr[2:0] == 2) ? 8'h7C : (addr[2:0] == 3) ? 8'h66 : (addr[2:0] == 4) ? 8'h66 : (addr[2:0] == 5) ? 8'h7C : (addr[2:0] == 6) ? 8'h60 : 8'h60; // p
            8'h71: pixels_comb = (addr[2:0] == 0) ? 8'h00 : (addr[2:0] == 1) ? 8'h00 : (addr[2:0] == 2) ? 8'h3E : (addr[2:0] == 3) ? 8'h66 : (addr[2:0] == 4) ? 8'h66 : (addr[2:0] == 5) ? 8'h3E : (addr[2:0] == 6) ? 8'h06 : 8'h06; // q
            8'h72: pixels_comb = (addr[2:0] == 0) ? 8'h00 : (addr[2:0] == 1) ? 8'h00 : (addr[2:0] == 2) ? 8'h5C : (addr[2:0] == 3) ? 8'h66 : (addr[2:0] == 4) ? 8'h60 : (addr[2:0] == 5) ? 8'h60 : (addr[2:0] == 6) ? 8'h60 : 8'h00; // r
            8'h73: pixels_comb = (addr[2:0] == 0) ? 8'h00 : (addr[2:0] == 1) ? 8'h00 : (addr[2:0] == 2) ? 8'h3E : (addr[2:0] == 3) ? 8'h60 : (addr[2:0] == 4) ? 8'h3C : (addr[2:0] == 5) ? 8'h06 : (addr[2:0] == 6) ? 8'h7C : 8'h00; // s
            8'h74: pixels_comb = (addr[2:0] == 0) ? 8'h00 : (addr[2:0] == 1) ? 8'h18 : (addr[2:0] == 2) ? 8'h7E : (addr[2:0] == 3) ? 8'h18 : (addr[2:0] == 4) ? 8'h18 : (addr[2:0] == 5) ? 8'h18 : (addr[2:0] == 6) ? 8'h0E : 8'h00; // t
            8'h75: pixels_comb = (addr[2:0] == 0) ? 8'h00 : (addr[2:0] == 1) ? 8'h00 : (addr[2:0] == 2) ? 8'h66 : (addr[2:0] == 3) ? 8'h66 : (addr[2:0] == 4) ? 8'h66 : (addr[2:0] == 5) ? 8'h66 : (addr[2:0] == 6) ? 8'h3E : 8'h00; // u
            8'h76: pixels_comb = (addr[2:0] == 0) ? 8'h00 : (addr[2:0] == 1) ? 8'h00 : (addr[2:0] == 2) ? 8'h66 : (addr[2:0] == 3) ? 8'h66 : (addr[2:0] == 4) ? 8'h66 : (addr[2:0] == 5) ? 8'h3C : (addr[2:0] == 6) ? 8'h18 : 8'h00; // v
            8'h77: pixels_comb = (addr[2:0] == 0) ? 8'h00 : (addr[2:0] == 1) ? 8'h00 : (addr[2:0] == 2) ? 8'h63 : (addr[2:0] == 3) ? 8'h6B : (addr[2:0] == 4) ? 8'h7F : (addr[2:0] == 5) ? 8'h3E : (addr[2:0] == 6) ? 8'h36 : 8'h00; // w
            8'h78: pixels_comb = (addr[2:0] == 0) ? 8'h00 : (addr[2:0] == 1) ? 8'h00 : (addr[2:0] == 2) ? 8'h66 : (addr[2:0] == 3) ? 8'h3C : (addr[2:0] == 4) ? 8'h18 : (addr[2:0] == 5) ? 8'h3C : (addr[2:0] == 6) ? 8'h66 : 8'h00; // x
            8'h79: pixels_comb = (addr[2:0] == 0) ? 8'h00 : (addr[2:0] == 1) ? 8'h00 : (addr[2:0] == 2) ? 8'h66 : (addr[2:0] == 3) ? 8'h66 : (addr[2:0] == 4) ? 8'h66 : (addr[2:0] == 5) ? 8'h3E : (addr[2:0] == 6) ? 8'h0C : 8'h78; // y
            8'h7A: pixels_comb = (addr[2:0] == 0) ? 8'h00 : (addr[2:0] == 1) ? 8'h00 : (addr[2:0] == 2) ? 8'h7E : (addr[2:0] == 3) ? 8'h0C : (addr[2:0] == 4) ? 8'h18 : (addr[2:0] == 5) ? 8'h30 : (addr[2:0] == 6) ? 8'h7E : 8'h00; // z
            default: pixels_comb = 8'hFF;  // Solid block for unknown characters
        endcase
    end

endmodule
