// hdmi_timing.v
// HDMI/DVI timing generator for 640x480@60Hz
// Pixel clock: 25.175 MHz (we'll use 27MHz / 2 = 13.5MHz as approximation, or generate proper clock)

module hdmi_timing (
    input wire clk_pixel,  // 25.175 MHz pixel clock
    input wire rst,
    output reg hsync,
    output reg vsync,
    output reg video_active,
    output reg [9:0] pixel_x,
    output reg [9:0] pixel_y
);

    // 640x480@60Hz timing parameters
    // Horizontal timing (pixels)
    localparam H_ACTIVE     = 640;
    localparam H_FRONT      = 16;
    localparam H_SYNC       = 96;
    localparam H_BACK       = 48;
    localparam H_TOTAL      = H_ACTIVE + H_FRONT + H_SYNC + H_BACK; // 800
    
    // Vertical timing (lines)
    localparam V_ACTIVE     = 480;
    localparam V_FRONT      = 10;
    localparam V_SYNC       = 2;
    localparam V_BACK       = 33;
    localparam V_TOTAL      = V_ACTIVE + V_FRONT + V_SYNC + V_BACK; // 525
    
    reg [9:0] h_count;
    reg [9:0] v_count;
    
    always @(posedge clk_pixel or posedge rst) begin
        if (rst) begin
            h_count <= 0;
            v_count <= 0;
            hsync <= 1;
            vsync <= 1;
            video_active <= 0;
            pixel_x <= 0;
            pixel_y <= 0;
        end else begin
            // Horizontal counter
            if (h_count == H_TOTAL - 1) begin
                h_count <= 0;
                // Vertical counter
                if (v_count == V_TOTAL - 1)
                    v_count <= 0;
                else
                    v_count <= v_count + 1;
            end else begin
                h_count <= h_count + 1;
            end
            
            // Generate hsync (negative polarity)
            hsync <= ~((h_count >= (H_ACTIVE + H_FRONT)) && 
                      (h_count < (H_ACTIVE + H_FRONT + H_SYNC)));
            
            // Generate vsync (negative polarity)
            vsync <= ~((v_count >= (V_ACTIVE + V_FRONT)) && 
                      (v_count < (V_ACTIVE + V_FRONT + V_SYNC)));
            
            // Generate video active
            video_active <= (h_count < H_ACTIVE) && (v_count < V_ACTIVE);
            
            // Output pixel coordinates
            if (h_count < H_ACTIVE)
                pixel_x <= h_count;
            else
                pixel_x <= 0;
                
            if (v_count < V_ACTIVE)
                pixel_y <= v_count;
            else
                pixel_y <= 0;
        end
    end
    
endmodule
