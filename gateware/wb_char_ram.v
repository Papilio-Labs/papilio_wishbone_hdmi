// wb_char_ram.v
// Wishbone slave for character RAM access with dual-port video readout
// This should be instantiated as a separate Wishbone slave (e.g., Slave 2)
// Address map: 0x20-0x2F
//   0x20: Control register (bit 0: clear screen, bit 1: cursor enable)
//   0x21: Cursor X position (0-79)
//   0x22: Cursor Y position (0-29)
//   0x23: Default attribute
//   0x24+: Character RAM access (auto-increment)

module wb_char_ram (
    input wire clk,
    input wire rst_n,
    
    // Wishbone interface (for CPU writes)
    input wire [7:0] wb_adr_i,
    input wire [7:0] wb_dat_i,
    output reg [7:0] wb_dat_o,
    input wire wb_cyc_i,
    input wire wb_stb_i,
    input wire wb_we_i,
    output reg wb_ack_o,
    
    // Video readout interface (for HDMI display)
    input wire [11:0] video_char_addr,
    output reg [7:0] video_char_data,
    output reg [7:0] video_attr_data,
    
    // Custom font RAM interface (for font_rom_8x8)
    output reg custom_font_we,
    output reg [5:0] custom_font_addr,
    output reg [7:0] custom_font_data
);

    // Control registers
    reg [7:0] control_reg;    // 0x20
    reg [6:0] cursor_x;       // 0x21 (0-79)
    reg [4:0] cursor_y;       // 0x22 (0-29)
    reg [7:0] default_attr;   // 0x23 (foreground/background color)
    reg [11:0] ram_addr_ptr;  // Auto-increment pointer for RAM access
    reg [5:0] font_addr;      // 0x2A Custom font address
    reg [7:0] font_data_reg;  // 0x2B Custom font data register
    reg [5:0] font_addr;      // 0x0A: Custom font address (0-63)
    reg [7:0] font_data_reg;  // 0x0B: Custom font data
    
    // Character RAM (80x30 = 2400 bytes)
    reg [7:0] char_ram [0:2399];
    reg [7:0] attr_ram [0:2399];
    
    // Note: RAM will be cleared by CPU on initialization
    // No initial block needed for synthesis
    
    wire [11:0] cursor_addr = (cursor_y * 80) + cursor_x;
    wire wb_valid = wb_cyc_i & wb_stb_i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wb_ack_o <= 0;
            wb_dat_o <= 8'h00;
            control_reg <= 8'h00;
            cursor_x <= 7'd0;
            cursor_y <= 5'd0;
            default_attr <= 8'h07;  // White on black
            ram_addr_ptr <= 12'd0;
            font_addr <= 6'd0;
            font_data_reg <= 8'd0;
            custom_font_we <= 0;
            custom_font_addr <= 6'd0;
            custom_font_data <= 8'd0;
        end else begin
            wb_ack_o <= 0;
            custom_font_we <= 0;  // Default: no write to custom font
            
            // Handle clear screen bit - disabled for synthesis
            // Clear screen is now handled in firmware by writing spaces
            if (control_reg[0]) begin
                control_reg[0] <= 0;
            end
            
            if (wb_valid && !wb_ack_o) begin
                wb_ack_o <= 1;
                
                if (wb_we_i) begin
                    // Write operations
                    case (wb_adr_i[3:0])
                        4'h0: control_reg <= wb_dat_i;
                        4'h1: cursor_x <= wb_dat_i[6:0];
                        4'h2: cursor_y <= wb_dat_i[4:0];
                        4'h3: default_attr <= wb_dat_i;
                        4'h4: begin  // Write character at cursor
                            if (cursor_addr < 2400) begin
                                char_ram[cursor_addr] <= wb_dat_i;
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
                        4'h5: begin  // Write attribute at cursor
                            if (cursor_addr < 2400)
                                attr_ram[cursor_addr] <= wb_dat_i;
                        end
                        4'h6: ram_addr_ptr <= {wb_dat_i[3:0], ram_addr_ptr[7:0]};  // Set high addr
                        4'h7: ram_addr_ptr <= {ram_addr_ptr[11:8], wb_dat_i};       // Set low addr
                        4'h8: begin  // Direct RAM write with auto-increment
                            if (ram_addr_ptr < 2400) begin
                                char_ram[ram_addr_ptr] <= wb_dat_i;
                                ram_addr_ptr <= ram_addr_ptr + 1;
                            end
                        end
                        4'h9: begin  // Direct attr write with auto-increment
                            if (ram_addr_ptr < 2400) begin
                                attr_ram[ram_addr_ptr] <= wb_dat_i;
                                ram_addr_ptr <= ram_addr_ptr + 1;
                            end
                        end
                        4'hA: begin  // Set custom font address
                            font_addr <= wb_dat_i[5:0];
                        end
                        4'hB: begin  // Write custom font data
                            font_data_reg <= wb_dat_i;
                            custom_font_we <= 1;
                            custom_font_addr <= font_addr;
                            custom_font_data <= wb_dat_i;
                            font_addr <= font_addr + 1;  // Auto-increment
                        end
                        default: ;
                    endcase
                end else begin
                    // Read operations
                    case (wb_adr_i[3:0])
                        4'h0: wb_dat_o <= control_reg;
                        4'h1: wb_dat_o <= {1'b0, cursor_x};
                        4'h2: wb_dat_o <= {3'b0, cursor_y};
                        4'h3: wb_dat_o <= default_attr;
                        4'h4: wb_dat_o <= (cursor_addr < 2400) ? char_ram[cursor_addr] : 8'h00;
                        4'h5: wb_dat_o <= (cursor_addr < 2400) ? attr_ram[cursor_addr] : 8'h00;
                        4'h6: wb_dat_o <= {4'b0, ram_addr_ptr[11:8]};
                        4'h7: wb_dat_o <= ram_addr_ptr[7:0];
                        4'h8: begin  // Direct RAM read with auto-increment
                            if (ram_addr_ptr < 2400) begin
                                wb_dat_o <= char_ram[ram_addr_ptr];
                                ram_addr_ptr <= ram_addr_ptr + 1;
                            end
                        end
                        4'h9: begin  // Direct attr read with auto-increment
                            if (ram_addr_ptr < 2400) begin
                                wb_dat_o <= attr_ram[ram_addr_ptr];
                                ram_addr_ptr <= ram_addr_ptr + 1;
                            end
                        end
                        4'hA: wb_dat_o <= {2'b0, font_addr};
                        4'hB: wb_dat_o <= font_data_reg;
                        default: wb_dat_o <= 8'h00;
                    endcase
                end
            end
        end
    end
    
    // Video readout port (asynchronous read for display)
    always @(posedge clk) begin
        if (video_char_addr < 2400) begin
            video_char_data <= char_ram[video_char_addr];
            video_attr_data <= attr_ram[video_char_addr];
        end else begin
            video_char_data <= 8'h20;  // Space
            video_attr_data <= 8'h07;  // White on black
        end
    end

endmodule
