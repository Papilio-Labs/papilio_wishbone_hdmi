`timescale 1ns / 1ps

/**
 * tb_wb_char_ram.v - Testbench for wb_char_ram.v
 *
 * Tests:
 *   1. Reset state
 *   2. Write cursor position (X, Y)
 *   3. Read back cursor position
 *   4. Write a character at cursor (auto-advance)
 *   5. Verify cursor auto-advance after character write
 *   6. Write attribute register
 *   7. Set control register (clear screen bit)
 */

module tb_wb_char_ram;

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

    // Video readout interface (stub)
    reg  [11:0] video_char_addr = 0;
    wire [7:0]  video_char_data;
    wire [7:0]  video_attr_data;

    // Custom font RAM interface
    wire        custom_font_we;
    wire [5:0]  custom_font_addr;
    wire [7:0]  custom_font_data;

    // Instantiate DUT
    wb_char_ram dut (
        .clk              (clk             ),
        .rst_n            (rst_n           ),
        .wb_adr_i         (wb_adr_i        ),
        .wb_dat_i         (wb_dat_i        ),
        .wb_dat_o         (wb_dat_o        ),
        .wb_cyc_i         (wb_cyc_i        ),
        .wb_stb_i         (wb_stb_i        ),
        .wb_we_i          (wb_we_i         ),
        .wb_ack_o         (wb_ack_o        ),
        .video_char_addr  (video_char_addr ),
        .video_char_data  (video_char_data ),
        .video_attr_data  (video_attr_data ),
        .custom_font_we   (custom_font_we  ),
        .custom_font_addr (custom_font_addr),
        .custom_font_data (custom_font_data)
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
        $dumpfile("tb_wb_char_ram.vcd");
        $dumpvars(0, tb_wb_char_ram);

        $display("=== wb_char_ram Testbench ===");

        // Test 1: Reset
        $display("Test 1: Reset behavior");
        rst_n = 0;
        #(CLK_PERIOD * 5);
        if (wb_ack_o !== 0) begin
            $error("  FAIL: wb_ack_o should be 0 during reset");
            errors = errors + 1;
        end else begin
            $display("  PASS: wb_ack_o=0 during reset");
        end
        @(posedge clk);
        rst_n = 1;
        #(CLK_PERIOD * 3);

        // Test 2: Default cursor should be (0, 0)
        $display("Test 2: Default cursor position = (0, 0)");
        wb_read(8'h21, read_data);  // cursor_x
        if (read_data !== 8'h00) begin
            $error("  FAIL: cursor_x default should be 0, got %d", read_data);
            errors = errors + 1;
        end else
            $display("  PASS: cursor_x = 0");

        wb_read(8'h22, read_data);  // cursor_y
        if (read_data !== 8'h00) begin
            $error("  FAIL: cursor_y default should be 0, got %d", read_data);
            errors = errors + 1;
        end else
            $display("  PASS: cursor_y = 0");

        // Test 3: Write cursor position
        $display("Test 3: Write cursor to (5, 3)");
        wb_write(8'h21, 8'd5);   // cursor_x = 5
        wb_write(8'h22, 8'd3);   // cursor_y = 3

        wb_read(8'h21, read_data);
        if (read_data !== 8'd5) begin
            $error("  FAIL: cursor_x should be 5, got %d", read_data);
            errors = errors + 1;
        end else
            $display("  PASS: cursor_x = 5");

        wb_read(8'h22, read_data);
        if (read_data !== 8'd3) begin
            $error("  FAIL: cursor_y should be 3, got %d", read_data);
            errors = errors + 1;
        end else
            $display("  PASS: cursor_y = 3");

        // Test 4: Write attribute register
        $display("Test 4: Write default attribute (white on black = 0x0F)");
        wb_write(8'h23, 8'h0F);
        wb_read(8'h23, read_data);
        if (read_data !== 8'h0F) begin
            $error("  FAIL: default_attr should be 0x0F, got 0x%02X", read_data);
            errors = errors + 1;
        end else
            $display("  PASS: default_attr = 0x0F");

        // Test 5: Write character - cursor should auto-advance
        $display("Test 5: Write character 'A' at (5,3); cursor should advance to (6,3)");
        wb_write(8'h24, 8'h41);  // 'A' = 0x41

        wb_read(8'h21, read_data);
        if (read_data !== 8'd6) begin
            $error("  FAIL: cursor_x should be 6 after write, got %d", read_data);
            errors = errors + 1;
        end else
            $display("  PASS: cursor_x auto-advanced to 6");

        wb_read(8'h22, read_data);
        if (read_data !== 8'd3) begin
            $error("  FAIL: cursor_y should still be 3, got %d", read_data);
            errors = errors + 1;
        end else
            $display("  PASS: cursor_y unchanged = 3");

        // Test 6: Write multiple characters and verify line wrap
        $display("Test 6: Fill to end of row, verify wrap to next line");
        // cursor is at (6, 3); fill to column 79
        wb_write(8'h21, 8'd79);  // jump cursor_x to 79
        wb_write(8'h24, 8'h42);  // write 'B' - should wrap to (0, 4)

        wb_read(8'h21, read_data);
        if (read_data !== 8'd0) begin
            $error("  FAIL: cursor_x should wrap to 0, got %d", read_data);
            errors = errors + 1;
        end else
            $display("  PASS: cursor_x wrapped to 0");

        wb_read(8'h22, read_data);
        if (read_data !== 8'd4) begin
            $error("  FAIL: cursor_y should advance to 4, got %d", read_data);
            errors = errors + 1;
        end else
            $display("  PASS: cursor_y advanced to 4");

        // Test 7: Control register write (clear screen bit)
        $display("Test 7: Write control register (clear screen bit 0)");
        wb_write(8'h20, 8'h01);   // bit 0 = clear screen trigger
        // Just verify the write completes without hang
        #(CLK_PERIOD * 5);
        $display("  PASS: control register write completed");

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
        #2000000;
        $error("TIMEOUT");
        $finish;
    end

endmodule
