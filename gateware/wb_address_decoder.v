// wb_address_decoder.v
// Simple Wishbone address decoder for multiple slaves
// Address map:
// 0x00-0x0F: RGB LED controller
// 0x10-0x1F: HDMI color bar controller
// 0x20-0x2F: USB Serial port

module wb_address_decoder (
    input wire clk,
    input wire rst,
    
    // Master interface (from SPI bridge)
    input wire [7:0] wb_adr_i,
    input wire [7:0] wb_dat_i,
    output reg [7:0] wb_dat_o,
    input wire wb_cyc_i,
    input wire wb_stb_i,
    input wire wb_we_i,
    output reg wb_ack_o,
    
    // Slave 0 interface (RGB LED) - addresses 0x00-0x0F
    output wire [7:0] s0_wb_adr_o,
    output wire [7:0] s0_wb_dat_o,
    input wire [7:0] s0_wb_dat_i,
    output wire s0_wb_cyc_o,
    output wire s0_wb_stb_o,
    output wire s0_wb_we_o,
    input wire s0_wb_ack_i,
    
    // Slave 1 interface (HDMI) - addresses 0x10-0x1F
    output wire [7:0] s1_wb_adr_o,
    output wire [7:0] s1_wb_dat_o,
    input wire [7:0] s1_wb_dat_i,
    output wire s1_wb_cyc_o,
    output wire s1_wb_stb_o,
    output wire s1_wb_we_o,
    input wire s1_wb_ack_i,
    
    // Slave 2 interface (USB Serial) - addresses 0x20-0x2F
    output wire [7:0] s2_wb_adr_o,
    output wire [7:0] s2_wb_dat_o,
    input wire [7:0] s2_wb_dat_i,
    output wire s2_wb_cyc_o,
    output wire s2_wb_stb_o,
    output wire s2_wb_we_o,
    input wire s2_wb_ack_i
);

    // Decode address to select slave
    wire sel_s0 = (wb_adr_i[7:4] == 4'h0);  // 0x00-0x0F
    wire sel_s1 = (wb_adr_i[7:4] == 4'h1);  // 0x10-0x1F
    wire sel_s2 = (wb_adr_i[7:4] == 4'h2);  // 0x20-0x2F
    
    // Route signals to slave 0
    assign s0_wb_adr_o = wb_adr_i;
    assign s0_wb_dat_o = wb_dat_i;
    assign s0_wb_cyc_o = wb_cyc_i && sel_s0;
    assign s0_wb_stb_o = wb_stb_i && sel_s0;
    assign s0_wb_we_o = wb_we_i;
    
    // Route signals to slave 1
    assign s1_wb_adr_o = wb_adr_i;
    assign s1_wb_dat_o = wb_dat_i;
    assign s1_wb_cyc_o = wb_cyc_i && sel_s1;
    assign s1_wb_stb_o = wb_stb_i && sel_s1;
    assign s1_wb_we_o = wb_we_i;
    
    // Route signals to slave 2
    assign s2_wb_adr_o = wb_adr_i;
    assign s2_wb_dat_o = wb_dat_i;
    assign s2_wb_cyc_o = wb_cyc_i && sel_s2;
    assign s2_wb_stb_o = wb_stb_i && sel_s2;
    assign s2_wb_we_o = wb_we_i;
    
    // Multiplex responses
    always @(*) begin
        if (sel_s0) begin
            wb_dat_o = s0_wb_dat_i;
            wb_ack_o = s0_wb_ack_i;
        end else if (sel_s1) begin
            wb_dat_o = s1_wb_dat_i;
            wb_ack_o = s1_wb_ack_i;
        end else if (sel_s2) begin
            wb_dat_o = s2_wb_dat_i;
            wb_ack_o = s2_wb_ack_i;
        end else begin
            wb_dat_o = 8'h00;
            wb_ack_o = 1'b0;
        end
    end
    
endmodule
