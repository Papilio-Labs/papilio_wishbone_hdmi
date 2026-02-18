// color_bar_generator.v
// Generates 8 vertical color bars for testing

module color_bar_generator (
    input wire clk,
    input wire video_active,
    input wire [9:0] pixel_x,
    input wire [9:0] pixel_y,
    input wire enable,  // Enable color bars (can be controlled via Wishbone)
    output reg [7:0] red,
    output reg [7:0] green,
    output reg [7:0] blue
);

    // 8 color bars, each 80 pixels wide (640 / 8 = 80)
    wire [2:0] bar_number;
    assign bar_number = pixel_x[9:7]; // Divide by 128 gives us rough 5 bars, use [9:7] for 8 bars
    
    always @(posedge clk) begin
        if (!video_active || !enable) begin
            red <= 0;
            green <= 0;
            blue <= 0;
        end else begin
            case (bar_number)
                3'd0: begin // White
                    red <= 8'hFF;
                    green <= 8'hFF;
                    blue <= 8'hFF;
                end
                3'd1: begin // Yellow
                    red <= 8'hFF;
                    green <= 8'hFF;
                    blue <= 8'h00;
                end
                3'd2: begin // Cyan
                    red <= 8'h00;
                    green <= 8'hFF;
                    blue <= 8'hFF;
                end
                3'd3: begin // Green
                    red <= 8'h00;
                    green <= 8'hFF;
                    blue <= 8'h00;
                end
                3'd4: begin // Magenta
                    red <= 8'hFF;
                    green <= 8'h00;
                    blue <= 8'hFF;
                end
                3'd5: begin // Red
                    red <= 8'hFF;
                    green <= 8'h00;
                    blue <= 8'h00;
                end
                3'd6: begin // Blue
                    red <= 8'h00;
                    green <= 8'h00;
                    blue <= 8'hFF;
                end
                3'd7: begin // Black
                    red <= 8'h00;
                    green <= 8'h00;
                    blue <= 8'h00;
                end
            endcase
        end
    end
    
endmodule
