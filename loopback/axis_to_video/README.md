# AXI-Stream to Video Out (axis_to_video)

## **What is this?**

This Verilog module is the critical **Bridge** between the Memory world (VDMA) and the Physical Display world (HDMI).

*   **Input:** AXI4-Stream (from VDMA). This is "bursty" data—it arrives in chunks whenever the memory controller is free.
*   **Input:** Video Timing (from VTC). These are steady, unrelenting heartbeat signals (HSYNC, VSYNC, ACTIVE_VIDEO) generated at exactly 74.25 MHz.
*   **Output:** Parallel Video Data (RGB + Syncs). This must be perfectly continuous pixel data sent to the HDMI encoder.

## **Why do we need it?**

You cannot simply wire a VDMA to an HDMI port.

1.  **Clock Domains:** VDMA runs on the efficient memory clock (100MHz+). The Display requires a specific Pixel Clock (74.25 MHz for 720p).
2.  **Data Flow:**
    *   **VDMA** is a "Push" Master. It throws data at you as fast as it can.
    *   **HDMI** is a "Pull" consumer (effectively). The monitor scans across the screen and *demands* a pixel at exact microsecond intervals. If you miss that window, the screen flickers or goes black.

This module acts as the **Rate Matcher** and **Synchronizer**.

## **How it Works**

### **1. The Concept of Backpressure (TREADY)**

The most important signal in this core is `s_axis_tready`. This is the "Backpressure" valve.

*   **The Problem:** The VDMA reads from DDR RAM much faster than the HDMI display needs pixels. If we accepted data constantly, we'd run out of RAM bandwidth or buffer space instantly.
*   **The Solution:** The `axis_to_video` core holds `s_axis_tready` **LOW** (busy) most of the time.
*   **The Flow:**
    1.  The **VTC (Video Timing Controller)** asserts `active_video` when the electron beam (metaphorically) is inside the visible screen area.
    2.  Only when `active_video` is HIGH does the core raise `s_axis_tready` to HIGH.
    3.  This tells the VDMA: *"Okay, give me one pixel now."*
    4.  The VDMA sends one pixel, and pauses until the next clock cycle.

By modulating `tready`, we force the wildly fast VDMA to slow down and march in perfect lockstep with the display's pixel clock.

### **2. Frame Synchronization (The "Rolling Image" Fix)**

Simply pumping pixels isn't enough. We need to ensure **Pixel (0,0)** in memory appears at **Pixel (0,0)** on the screen. If they are misaligned, the image will appear "rolled" (split dynamically in the middle) or jittery.

We use two signals to achieve synchronization:

*   **`fsync` (from VTC):** This pulses once per frame, exactly when the vertical blanking interval begins (Top of Screen).
*   **`tuser` (from VDMA):** The AXI-Stream standard uses the `TUSER` sideband signal to mark the **Start of Frame (SOF)**. The VDMA asserts this bit only for the very first pixel of the image buffer.

**The Logic:**

1.  **Wait State:** When the core starts up (or after a reset), it enters a `WAIT` state. It blocks all data `tval` and `tready`.
2.  **The Handshake:** It waits until it sees `fsync` (VTC says "Start of Frame") **AND** `s_axis_tuser` (VDMA says "Here is Pixel 0").
3.  **Lock:** Only when both happen effectively simultaneously/within the blanking window does the core state machine unlock.
4.  **Streaming:** It then passes pixels normally.

### **3. Color Channel Swapping**

Crucially, this core also fixes a color format mismatch between the Xilinx VDMA and the Digilent `rgb2hdmi` core.

*   **Linux/VDMA Standard:** `XR24` (XRGB8888). In memory (Little Endian), this often results in `[23:16]=Red`, `[15:8]=Green`, `[7:0]=Blue`.
*   **Digilent encoder expectation:** It expects `[23:16]=Red`, `[15:8]=Blue`, `[7:0]=Green`.

If we connected them directly, the Green and Blue channels would be swapped (Blue sky would look Green).  
**The Fix:** This core internally swaps the wires: `vid_data = {in[23:16], in[7:0], in[15:8]}`.

### **Technical Summary**
*   **Latency:** 1 clock cycle (pipelined)
*   **Backpressure:** Strict `active_video` gating
*   **Sync:** `fsync` & `tuser` coincident detection
*   **Format:** RBG Output (swapped)

