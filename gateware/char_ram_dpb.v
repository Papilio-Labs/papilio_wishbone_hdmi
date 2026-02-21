// char_ram_dpb.v
// Dual-port block RAM for character + attribute storage
// 600 words x 12 bits (30x20 characters)
// Port A: CPU write port (Wishbone)
// Port B: Video read port (pixel clock domain)

module char_ram_dpb (
    // Port A: CPU write port
    input wire clk_a,
    input wire ce_a,
    input wire we_a,
    input wire [9:0] addr_a,  // 0-599 (10 bits for 1024 addresses)
    input wire [11:0] din_a,
    output wire [11:0] dout_a,
    
    // Port B: Video read port  
    input wire clk_b,
    input wire ce_b,
    input wire [9:0] addr_b,
    output wire [11:0] dout_b
);

    wire [3:0] dpb_douta_unused;
    wire [3:0] dpb_doutb_unused;
    wire gw_gnd = 1'b0;
    
    // Instantiate Gowin DPB primitive
    // Configured for 16-bit width (we use 12 bits)
    DPB dpb_inst (
        // Port A outputs (write port)
        .DOA({dpb_douta_unused, dout_a}),
        // Port B outputs (read port)
        .DOB({dpb_doutb_unused, dout_b}),
        
        // Port A control
        .CLKA(clk_a),
        .OCEA(1'b1),      // Output clock enable always on
        .CEA(ce_a),       // Clock enable
        .RESETA(gw_gnd),  // No reset
        .WREA(we_a),      // Write enable
        
        // Port B control (read-only)
        .CLKB(clk_b),
        .OCEB(1'b1),      // Output clock enable always on
        .CEB(ce_b),       // Clock enable
        .RESETB(gw_gnd),  // No reset
        .WREB(gw_gnd),    // Read-only port
        
        // Block select (always 0)
        .BLKSELA({gw_gnd,gw_gnd,gw_gnd}),
        .BLKSELB({gw_gnd,gw_gnd,gw_gnd}),
        
        // Port A address and data (14 bits address for DPB, 16 bits data)
        .ADA({gw_gnd,gw_gnd,gw_gnd,addr_a,gw_gnd}),  // [13:1] = address, [0] = byte select (unused)
        .DIA({gw_gnd,gw_gnd,gw_gnd,gw_gnd,din_a}),   // 16-bit data input (we use 12)
        
        // Port B address (read-only, no data input)
        .ADB({gw_gnd,gw_gnd,gw_gnd,addr_b,gw_gnd}),
        .DIB(16'h0000)    // Not used (read-only port)
    );
    
    // DPB parameters
    defparam dpb_inst.READ_MODE0 = 1'b0;      // Normal read mode (not bypass)
    defparam dpb_inst.READ_MODE1 = 1'b0;      // Normal read mode
    defparam dpb_inst.WRITE_MODE0 = 2'b00;    // Normal write mode
    defparam dpb_inst.WRITE_MODE1 = 2'b00;    // Normal write mode  
    defparam dpb_inst.BIT_WIDTH_0 = 16;       // 16-bit width for port A
    defparam dpb_inst.BIT_WIDTH_1 = 16;       // 16-bit width for port B
    defparam dpb_inst.BLK_SEL_0 = 3'b000;     // Block 0
    defparam dpb_inst.BLK_SEL_1 = 3'b000;     // Block 0
    defparam dpb_inst.RESET_MODE = "SYNC";    // Synchronous reset

endmodule
