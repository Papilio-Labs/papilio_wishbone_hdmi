// wb_video_ctrl.v
// Wishbone wrapper for HDMI video output control
// Slave 1: Base address 0x10-0x1F
// Register map:
//   0x10: Pattern mode (0=color bars, 1=grid, 2=grayscale, 3=text mode)
//   0x11: Status/version

module wb_video_ctrl (
    input wire clk,
    input wire rst_n,
    
    // Wishbone interface
    input wire [7:0] wb_adr_i,
    input wire [7:0] wb_dat_i,
    output reg [7:0] wb_dat_o,
    input wire wb_cyc_i,
    input wire wb_stb_i,
    input wire wb_we_i,
    output reg wb_ack_o,
    
    // Text mode character RAM interface (connect to wb_char_ram externally)
    input wire [7:0] text_char_data,
    input wire [7:0] text_attr_data,
    output wire [11:0] text_char_addr,
    
    // Custom font RAM interface
    input wire custom_font_we,
    input wire [5:0] custom_font_addr,
    input wire [7:0] custom_font_data,
    
    // HDMI outputs
    output wire O_tmds_clk_p,
    output wire O_tmds_clk_n,
    output wire [2:0] O_tmds_data_p,
    output wire [2:0] O_tmds_data_n
);

    // Wishbone control registers
    reg [7:0] pattern_mode;  // Address 0x10: Pattern mode selection (0-2=patterns, 3=text)
    
    // Wishbone bus handling
    wire wb_valid = wb_cyc_i & wb_stb_i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wb_ack_o <= 0;
            wb_dat_o <= 8'h00;
            pattern_mode <= 8'h03;  // Default: text mode
        end else begin
            wb_ack_o <= 0;
            
            if (wb_valid && !wb_ack_o) begin
                wb_ack_o <= 1;
                
                if (wb_we_i) begin
                    // Write operations
                    case (wb_adr_i[3:0])
                        4'h0: pattern_mode <= wb_dat_i;
                        default: ;
                    endcase
                end else begin
                    // Read operations
                    case (wb_adr_i[3:0])
                        4'h0: wb_dat_o <= pattern_mode;
                        4'h1: wb_dat_o <= 8'h02;  // Version 2 (supports text mode)
                        default: wb_dat_o <= 8'h00;
                    endcase
                end
            end
        end
    end
    
    // Instantiate video_top with pattern mode control
    video_top_wb u_video (
        .I_clk(clk),
        .I_rst_n(rst_n),
        .I_pattern_mode(pattern_mode[1:0]),  // Use lower 2 bits for 4 modes
        
        // Text mode character RAM interface
        .I_text_char_data(text_char_data),
        .O_text_char_addr(text_char_addr),
        
        // Custom font RAM interface
        .I_custom_font_we(custom_font_we),
        .I_custom_font_addr(custom_font_addr),
        .I_custom_font_data(custom_font_data),
        
        .O_tmds_clk_p(O_tmds_clk_p),
        .O_tmds_clk_n(O_tmds_clk_n),
        .O_tmds_data_p(O_tmds_data_p),
        .O_tmds_data_n(O_tmds_data_n)
    );

endmodule
