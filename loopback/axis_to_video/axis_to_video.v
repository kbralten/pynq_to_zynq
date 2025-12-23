// Simple AXI-Stream to Video Out Bridge
// Synchronizes AXI-Stream (with TUSER frame markers) to VTC timing


module axis_to_video #(
    parameter STREAM_WIDTH = 24,  // RGB888
    parameter VIDEO_DATA_WIDTH = 24  // RGB888
)(
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 video_clk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_axis, ASSOCIATED_RESET resetn, FREQ_HZ 74250000" *)
    // Clock and reset
    input wire video_clk,           // 74.25 MHz pixel clock
    
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 resetn RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input wire resetn,
    
    // AXI-Stream input (from VDMA)
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis TDATA" *)
    input wire [STREAM_WIDTH-1:0] s_axis_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis TVALID" *)
    input wire s_axis_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis TREADY" *)
    output wire s_axis_tready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis TUSER" *)
    input wire s_axis_tuser,        // Start of frame
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis TLAST" *)
    (* X_INTERFACE_PARAMETER = "TDATA_NUM_BYTES 3, TUSER_WIDTH 1, HAS_TREADY 1, HAS_TKEEP 0, HAS_TLAST 1" *)
    input wire s_axis_tlast,        // End of line
    
    // VTC timing inputs
    input wire vtc_fsync,           // Frame sync pulse
    input wire vtc_active_video,    // Active video region
    input wire vtc_hsync,
    input wire vtc_vsync,
    
    // Video output
    output reg [VIDEO_DATA_WIDTH-1:0] vid_data,
    output reg vid_hsync,
    output reg vid_vsync,
    output reg vid_active_video,
    
    //status
    output wire [1:0] state_debug,
    output wire frame_pending_debug
);

    // State machine
    localparam UNLOCKED = 2'b00;
    localparam WAIT_FSYNC = 2'b01;
    localparam LOCKED = 2'b10;
    
    reg [1:0] state;
    reg frame_pending;
    
    assign state_debug = state;
    assign frame_pending_debug = frame_pending;
    
    // Pipeline registers for timing signals - ALL signals need same delay for alignment
    reg vtc_fsync_d1, vtc_fsync_d2;
    reg vtc_active_d1;
    reg vtc_hsync_d1, vtc_vsync_d1;
    wire vtc_fsync_rising;
    
    // Capture register for pixel data
    reg [VIDEO_DATA_WIDTH-1:0] pixel_data_r;
    
    // Swapped pixel data (swap Blue and Green channels)
    // Input from VDMA XR24: tdata[23:16]=R, tdata[15:8]=G, tdata[7:0]=B
    // rgb2hdmi expects: [23:16]=R, [15:8]=B, [7:0]=G (or similar swap)
    wire [VIDEO_DATA_WIDTH-1:0] pixel_swapped;
    assign pixel_swapped = {pixel_data_r[23:16], pixel_data_r[7:0], pixel_data_r[15:8]};
    
    // Detect rising edge of fsync
    always @(posedge video_clk) begin
        vtc_fsync_d1 <= vtc_fsync;
        vtc_fsync_d2 <= vtc_fsync_d1;
        vtc_active_d1 <= vtc_active_video;
        vtc_hsync_d1 <= vtc_hsync;
        vtc_vsync_d1 <= vtc_vsync;
    end
    assign vtc_fsync_rising = vtc_fsync_d1 & ~vtc_fsync_d2;
    
    // Capture pixel data when we consume it (tready & tvalid)
    always @(posedge video_clk) begin
        if (!resetn) begin
            pixel_data_r <= {VIDEO_DATA_WIDTH{1'b0}};
        end else if (s_axis_tready && s_axis_tvalid) begin
            pixel_data_r <= s_axis_tdata;
        end
    end
    
    // Synchronization state machine
    always @(posedge video_clk) begin
        if (!resetn) begin
            state <= UNLOCKED;
            frame_pending <= 1'b0;
        end else begin
            case (state)
                UNLOCKED: begin
                    // Drain stream until we find TUSER (start of frame)
                    if (s_axis_tvalid && s_axis_tuser) begin
                        // Found start of frame, now wait for fsync
                        frame_pending <= 1'b1;
                        state <= WAIT_FSYNC;
                    end
                end
                
                WAIT_FSYNC: begin
                    // Hold at first pixel of stream frame, wait for VTC fsync
                    if (vtc_fsync_rising) begin
                        state <= LOCKED;
                        frame_pending <= 1'b0;
                    end
                    // If we somehow miss the frame start, go back
                    if (!s_axis_tvalid) begin
                        state <= UNLOCKED;
                        frame_pending <= 1'b0;
                    end
                end
                
                LOCKED: begin
                    // Stay locked as long as data is flowing
                    // Don't require TUSER every frame (VDMA may not send it if stuck)
                    if (!s_axis_tvalid) begin
                        // Only lose lock if stream completely stops
                        state <= UNLOCKED;
                    end
                    // Track stream frame starts if they arrive
                    if (s_axis_tvalid && s_axis_tuser) begin
                        frame_pending <= 1'b1;
                    end
                    if (vtc_fsync_rising) begin
                        frame_pending <= 1'b0;
                    end
                end
                
                default: state <= UNLOCKED;
            endcase
        end
    end
    
    // Video output generation - use captured pixel data and delayed timing signals
    // All outputs now have consistent 1-cycle latency
    always @(posedge video_clk) begin
        if (!resetn) begin
            vid_data <= {VIDEO_DATA_WIDTH{1'b0}};
            vid_hsync <= 1'b0;
            vid_vsync <= 1'b0;
            vid_active_video <= 1'b0;
        end else begin
            // All timing signals delayed by same amount (1 cycle via _d1 registers)
            vid_hsync <= vtc_hsync_d1;
            vid_vsync <= vtc_vsync_d1;
            vid_active_video <= vtc_active_d1;
            
            // Output captured pixel data during active video (with B/G swap)
            if (vtc_active_d1) begin
                vid_data <= pixel_swapped;
            end else begin
                vid_data <= {VIDEO_DATA_WIDTH{1'b0}};  // Black during blanking
            end
        end
    end
    
    // AXI-Stream ready signal
    // UNLOCKED: drain freely to find TUSER (frame start)
    // WAIT_FSYNC: stall at first pixel until timing aligns  
    // LOCKED: consume ONLY during active_video (undelayed!) to get exactly 1280 pixels/line
    // Using undelayed signal ensures we stop consuming immediately when blanking starts
    assign s_axis_tready = (state == UNLOCKED) || ((state == LOCKED) && vtc_active_video);

endmodule
