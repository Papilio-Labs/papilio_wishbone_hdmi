// ==============================================================================
// framebuffer_ram.v - Gowin SDPB-based Framebuffer Memory
// ==============================================================================
// Simple Dual-Port Block RAM for framebuffer with separate read/write clocks.
// Uses Gowin SDPB primitive for reliable cross-clock-domain operation.
//
// Size: 19,200 bytes (160x120 RGB332)
// Write port: Wishbone clock (27 MHz)
// Read port: Pixel clock (74.25 MHz)
// ==============================================================================

module framebuffer_ram #(
    parameter ADDR_WIDTH = 15,
    parameter DATA_WIDTH = 8,
    parameter DEPTH = 19200
)(
    // Write port (Wishbone clock domain)
    input                       wr_clk,
    input                       wr_en,
    input  [ADDR_WIDTH-1:0]     wr_addr,
    input  [DATA_WIDTH-1:0]     wr_data,
    
    // Read port (Pixel clock domain)  
    input                       rd_clk,
    input                       rd_en,
    input  [ADDR_WIDTH-1:0]     rd_addr,
    output reg [DATA_WIDTH-1:0] rd_data
);

// Use distributed RAM style which works better for dual-clock
// For larger memories, Gowin will still use BSRAM but infer it correctly
(* syn_ramstyle = "block_ram" *)
reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

// Write port - synchronous write
always @(posedge wr_clk) begin
    if (wr_en && wr_addr < DEPTH) begin
        mem[wr_addr] <= wr_data;
    end
end

// Read port - synchronous read with registered output
always @(posedge rd_clk) begin
    if (rd_en && rd_addr < DEPTH) begin
        rd_data <= mem[rd_addr];
    end else begin
        rd_data <= 8'd0;
    end
end

endmodule
