`timescale 1ns / 1ps

/**
 * tb_wb_video_ctrl.v - Testbench for wb_video_ctrl.v
 *
 * Tests:
 *   1. Reset state: wb_ack_o deasserted, pattern_mode defaults to 0x03 (text mode)
 *   2. Write pattern mode register (address 0x10)
 *   3. Read back pattern mode register
 *   4. Read status/version register (address 0x11)
 *   5. Write ignored address (no effect)
 */

module tb_wb_video_ctrl;

    // Clock (27MHz = ~37ns period; use simplified 10ns for simulation)
    localparam CLK_PERIOD = 10;

    reg clk   = 0;
    reg rst_n = 0;

    always #(CLK_PERIOD/2) clk = ~clk;

    // Wishbone signals
    reg  [7:0] wb_adr_i  = 0;
    reg  [7:0] wb_dat_i  = 0;
    wire [7:0] wb_dat_o;
    reg        wb_cyc_i  = 0;
    reg        wb_stb_i  = 0;
    reg        wb_we_i   = 0;
    wire       wb_ack_o;

    // Text char RAM interface (stub)
    reg  [7:0] text_char_data = 8'hAA;
    reg  [7:0] text_attr_data = 8'h07;
    wire [11:0] text_char_addr;

    // Custom font interface (stub)
    reg        custom_font_we   = 0;
    reg  [5:0] custom_font_addr = 0;
    reg  [7:0] custom_font_data_i = 0;

    // HDMI outputs (not checked in this testbench — just need valid connections)
    wire O_tmds_clk_p, O_tmds_clk_n;
    wire [2:0] O_tmds_data_p, O_tmds_data_n;

    // Instantiate DUT
    wb_video_ctrl dut (
        .clk             (clk            ),
        .rst_n           (rst_n          ),
        .wb_adr_i        (wb_adr_i       ),
        .wb_dat_i        (wb_dat_i       ),
        .wb_dat_o        (wb_dat_o       ),
        .wb_cyc_i        (wb_cyc_i       ),
        .wb_stb_i        (wb_stb_i       ),
        .wb_we_i         (wb_we_i        ),
        .wb_ack_o        (wb_ack_o       ),
        .text_char_data  (text_char_data ),
        .text_attr_data  (text_attr_data ),
        .text_char_addr  (text_char_addr ),
        .custom_font_we  (custom_font_we ),
        .custom_font_addr(custom_font_addr),
        .custom_font_data(custom_font_data_i),
        .O_tmds_clk_p    (O_tmds_clk_p   ),
        .O_tmds_clk_n    (O_tmds_clk_n   ),
        .O_tmds_data_p   (O_tmds_data_p  ),
        .O_tmds_data_n   (O_tmds_data_n  )
    );

    // -------------------------------------------------------------------------
    // Wishbone helpers
    // -------------------------------------------------------------------------

    task wb_write;
        input [7:0] addr;
        input [7:0] data;
        begin
            @(posedge clk);
            wb_adr_i <= addr;
            wb_dat_i <= data;
            wb_we_i  <= 1;
            wb_cyc_i <= 1;
            wb_stb_i <= 1;
            @(posedge clk);
            while (!wb_ack_o) @(posedge clk);
            wb_cyc_i <= 0;
            wb_stb_i <= 0;
            wb_we_i  <= 0;
            @(posedge clk);
        end
    endtask

    task wb_read;
        input  [7:0] addr;
        output [7:0] data;
        begin
            @(posedge clk);
            wb_adr_i <= addr;
            wb_we_i  <= 0;
            wb_cyc_i <= 1;
            wb_stb_i <= 1;
            @(posedge clk);
            while (!wb_ack_o) @(posedge clk);
            data     = wb_dat_o;
            wb_cyc_i <= 0;
            wb_stb_i <= 0;
            @(posedge clk);
        end
    endtask

    // -------------------------------------------------------------------------
    // Test sequence
    // -------------------------------------------------------------------------

    reg [7:0] read_data;
    integer   errors = 0;

    initial begin
        $dumpfile("tb_wb_video_ctrl.vcd");
        $dumpvars(0, tb_wb_video_ctrl);

        $display("=== wb_video_ctrl Testbench ===");

        // Test 1: Reset
        $display("Test 1: Reset behavior");
        rst_n = 0;
        #(CLK_PERIOD * 5);
        if (wb_ack_o !== 0) begin
            $error("  FAIL: wb_ack_o should be 0 during reset, got %b", wb_ack_o);
            errors = errors + 1;
        end else begin
            $display("  PASS: wb_ack_o=0 during reset");
        end

        // Release reset
        @(posedge clk);
        rst_n = 1;
        #(CLK_PERIOD * 3);

        // Test 2: Default pattern mode register should be 0x03 (text mode)
        $display("Test 2: Default pattern mode = 0x03 (text mode)");
        wb_read(8'h10, read_data);
        if (read_data !== 8'h03) begin
            $error("  FAIL: pattern_mode default should be 0x03, got 0x%02X", read_data);
            errors = errors + 1;
        end else begin
            $display("  PASS: default pattern_mode = 0x03");
        end

        // Test 3: Write pattern mode (color bars = 0x00)
        $display("Test 3: Write pattern mode 0x00 (color bars)");
        wb_write(8'h10, 8'h00);
        wb_read(8'h10, read_data);
        if (read_data !== 8'h00) begin
            $error("  FAIL: pattern_mode should be 0x00, got 0x%02X", read_data);
            errors = errors + 1;
        end else begin
            $display("  PASS: pattern_mode = 0x00 after write");
        end

        // Test 4: Switch to grid pattern (0x01)
        $display("Test 4: Write pattern mode 0x01 (grid)");
        wb_write(8'h10, 8'h01);
        wb_read(8'h10, read_data);
        if (read_data !== 8'h01) begin
            $error("  FAIL: pattern_mode should be 0x01, got 0x%02X", read_data);
            errors = errors + 1;
        end else begin
            $display("  PASS: pattern_mode = 0x01");
        end

        // Test 5: Read version register (address 0x11)
        $display("Test 5: Read version register 0x11");
        wb_read(8'h11, read_data);
        if (read_data !== 8'h02) begin
            $error("  FAIL: version should be 0x02, got 0x%02X", read_data);
            errors = errors + 1;
        end else begin
            $display("  PASS: version = 0x02");
        end

        // Test 6: Write to non-existent register (should be ignored)
        $display("Test 6: Write to unused address 0x1F (should be ignored)");
        wb_write(8'h1F, 8'hAB);
        wb_read(8'h10, read_data);   // pattern_mode should still be 0x01
        if (read_data !== 8'h01) begin
            $error("  FAIL: pattern_mode changed unexpectedly to 0x%02X", read_data);
            errors = errors + 1;
        end else begin
            $display("  PASS: write to unused address had no effect");
        end

        // Summary
        $display("\n=== Summary ===");
        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $error("%0d TEST(S) FAILED", errors);

        $finish;
    end

    // Timeout
    initial begin
        #1000000;
        $error("TIMEOUT");
        $finish;
    end

endmodule
