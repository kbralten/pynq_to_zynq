# **Loopback Project Step 7: HDMI Video Output (Programmable Logic)**

## **1. The Goal**

To create a complete **video display pipeline** in the Zynq FPGA that outputs 720p60 HDMI video.

We are building a custom "graphics card" inside the programmable logic:

* **Input:** Framebuffer data in DDR RAM (written by Linux DRM driver)
* **Processing:** VDMA fetches pixels → axis_to_video synchronizes with timing → rgb2hdmi encodes to HDMI
* **Output:** 1280×720 @ 60Hz HDMI signal on physical HDMI connector

### Pipeline Architecture

```
┌─────────────┐    ┌──────────────────┐    ┌──────────┐    ┌──────┐
│  AXI VDMA   │───►│  axis_to_video   │───►│ rgb2hdmi │───►│ HDMI │
│(Framebuffer)│    │  (custom RTL)    │    │(Digilent)│    │ Out  │
└─────────────┘    └──────────────────┘    └──────────┘    └──────┘
      ▲                     ▲                                     
   DDR RAM             VTC Timing                                 
                                                                  
DRM writes pixels → VDMA streams → sync with VTC → encode → display
```

**Key Features:**
- **Resolution:** 1280×720 (720p)
- **Refresh Rate:** 60 Hz
- **Pixel Clock:** 74.25 MHz
- **Pixel Format:** 32-bit XRGB8888 (Linux DRM standard)
- **Memory Interface:** AXI HP0 (high-performance port for video bandwidth)

*Note: This step covers Vivado hardware design only. Linux driver configuration is Step 8.*

## **2. Prerequisites**

Before starting:

* ✅ **Vivado 2025.1** or compatible version installed
* ✅ **loopback_system** project from Step 2 (or equivalent Zynq design)
* ✅ **Internet connection** to download Digilent IP library
* ✅ **Git** installed for cloning repositories
* ✅ **axis_to_video.v** module (located in project root directory)

## **3. Step-by-Step Instructions**

### **Part A: Prepare Dependencies**

We need two external components: a custom Verilog module for timing synchronization and the Digilent IP library for HDMI encoding.

**1. Download Custom RTL:**
Download the helper module that bridges standard AXI-Stream video to the native video timing signals. This is a small module that is tailored to the specific requirements of the project, there is also a Xilinx IP core that can be used, but it is much larger and more complex.
*   **Download:** [`axis_to_video.v`](axis_to_video/axis_to_video.v)
*   **Action:** Save this file to your project root directory.

**2. Clone the Digilent Vivado Library:**

The PYNQ-Z2 HDMI port uses TMDS signaling, which requires a specialized encoder. Xilinx doesn't provide native TMDS IP for Zynq-7000, so we use Digilent's open-source rgb2hdmi encoder.

```bash
# Navigate to a directory for third-party IP (outside your project)
cd ~/xilinx_ip  # Or C:\xilinx_ip on Windows
git clone https://github.com/Digilent/vivado-library.git
```

**3. Add Repository to Vivado:**

1. Open your Vivado project
2. Go to **Settings** → **IP** → **Repository**
3. Click the **+** button
4. Navigate to and select the `vivado-library` folder you just cloned
5. Click **Select**
6. Click **OK** to close Settings

**Verification:** You should see a message in the Tcl Console:
```
INFO: Repository 'vivado-library' added.
INFO: Found 1 IP(s) and 0 interfaces and 0 design(s) in '.../vivado-library/ip'
```

The IP catalog should now include **RGB to DVI Video Encoder** (Digilent).

### **Part B: Configure Zynq Processing System**

The PS needs high-bandwidth access to DDR RAM for video data and additional clocks for video processing.

**1. Open Block Design:**
- Open your existing block design (e.g., `system_design.bd`)
- Double-click the **ZYNQ7 Processing System** block

**2. Enable High-Performance Port:**
- Navigate to **PS-PL Configuration** → **HP Slave AXI Interface**
- ✅ **Enable S_AXI_HP0** (unchecked by default)
  - **Data Width:** 64 bits (default)
  - **Why:** Video requires ~400 MB/s bandwidth (1280×720×4 bytes×60 fps ≈ 221 MB/s + overhead). The HP port provides direct DDR access bypassing CPU cache.

**3. Enable PL Fabric Clocks:**
- Navigate to **Clock Configuration** → **PL Fabric Clocks**
- ✅ **FCLK_CLK0**: 100 MHz (likely already enabled)

**4. Enable Interrupts:**
- Navigate to **Interrupts** → **Fabric Interrupts**
- ✅ **Enable PL-PS Interrupt Ports**
- ✅ **Enable IRQ_F2P[15:0]** (Fabric to PS interrupts)

**5. Apply Changes:**
- Click **OK** to close the configuration
- The Zynq PS block should now show the HP0 port on the left side
- *Note:* You may receive a warning about various DDR timing parameters having negative values. This is normal and can be safely ignored.

---

### **Part C: Add and Configure IP Cores**

We'll add the IP blocks that form the video pipeline.

**1. Add Clocking Wizard:**

**Add IP:**
- Click **+** in the block design canvas
- Search: **Clocking Wizard**
- Double-click to add

**Configure:**
- Double-click the clocking wizard block
- **Clocking Options:**
  - **Input Clock:** 
    - Source: Global Buffer
    - Input Frequency: 100 MHz (from FCLK_CLK0)
- **Output Clocks:**
  - **clk_out1:** 
    - ✅ Enable
    - Output Freq: **74.250 MHz** (720p60 pixel clock)
    - Phase: 0
  - **clk_out2:**
    - ✅ Enable  
    - Output Freq: **371.25 MHz** (5× pixel clock for TMDS serialization)
    - Phase: 0
- **Reset Type:** Active Low
- **Port Renaming (optional):**
  - Rename `clk_out1` → `pixel_clk`
  - Rename `clk_out2` → `serial_clk`
- Click **OK**

**2. Add AXI VDMA:**

**Add IP:**
- Search: **AXI Video Direct Memory Access**
- Double-click to add

**Configure:**
- Double-click the VDMA block
- **Basic Tab:**
  - ❌ **Uncheck "Enable Write Channel"** (S2MM not needed)
  - ✅ **Enable Read Channel** (MM2S only)
  - **Address Width:** 32 bits
  - **Frame Buffers:** 3 (triple buffering)
  - **Read Channel (MM2S):**
    - **Stream Data Width:** 32 (for XRGB8888 format)
- **Advanced Tab:**
  - **Read Channel Options:**
    - **Fsync Options:** None
    - **GenLock Mode:** Master
- Click **OK**

**3. Add Video Timing Controller (VTC):**

**Add IP:**
- Search: **Video Timing Controller**
- Double-click to add

**Configure:**
- Double-click the VTC block
- **Detection/Generation Tab:**
  - ✅ **Enable Generator**
  - ❌ **Uncheck "Enable Detection"** (we only generate, not detect)
- **Default/Constant Tab:**
  - **Video Mode:** 720p (leave default)
  - **Active Polarity:**
    - **Horizontal:** Active Low
    - **Vertical:** Active High
- Click **OK**

**4. Add axis_to_video Custom Module:**

This module bridges the AXI-Stream from VDMA to parallel video signals synchronized with VTC timing.

1. In Vivado, go to **Sources** → **Add Sources** (Alt+A)
2. Select **Add or create design sources**
3. Click **Add Files**
4. Navigate to your project root and select [`axis_to_video.v`](axis_to_video\axis_to_video.v)
5. ✅ Check **Copy sources into project** (optional, keeps project self-contained)
6. Click **Finish**
7. In the block design, right-click canvas → **Add Module**
8. Select **axis_to_video** from the list
9. Click **OK**

**Configure axis_to_video:**

The module has parameters with defaults:
- **STREAM_WIDTH**: 32
- **VIDEO_DATA_WIDTH**: 24

No GUI configuration needed if using default parameters.

**5. Add RGB to DVI Video Encoder (Digilent):**

**Add IP:**
- Search: **RGB to DVI Video Encoder** (should appear if Digilent library was added)
- If not found: verify repository was added correctly in Part A
- Double-click to add

**Configure:**
- Double-click the rgb2hdmi (RGB to DVI) block
- **Parameters:**
  - **Reset Active High:** `false` (Active Low reset)
  - **Generate SerialClk internally from pixel clock:** ❌unchecked
- Click **OK**

---

### **Part D: Connect the Pipeline (Critical Wiring)**

Video pipelines are sensitive to clock domains. Each signal must be on the correct clock. Follow carefully.

#### **1. Clock Connections**

**Connect Clocking Wizard Input:**
- `clk_in1` → Zynq PS `FCLK_CLK0` (100 MHz)
- `resetn` → Processor System Reset `peripheral_aresetn[0]`

**Run Connection Automation:**
- Click **Run Connection Automation** (Alt+Shift+C)
- This will connect most signals automatically

**100 MHz Clock Domain (AXI Control):**

Connect Zynq PS `FCLK_CLK0` to *this should be done already by Connection Automation*:
- VDMA `s_axi_lite_aclk` (control register access)
- VDMA `m_axi_mm2s_aclk` (DDR memory read clock)
- VTC `s_axi_aclk` (control registers)
- All AXI Interconnect clocks
- Zynq PS `M_AXI_GP0_ACLK` (already connected via automation)
- Zynq PS `S_AXI_HP0_ACLK` (HP port clock)

**74.25 MHz Clock Domain (Pixel Clock):**

Connect Clocking Wizard `pixel_clk` (74.25 MHz) to:
- VDMA `m_axis_mm2s_aclk` (AXI-Stream output clock)
- VTC `clk` (generates timing at pixel rate)
- axis_to_video `video_clk`
- rgb2hdmi `PixelClk`

**371.25 MHz Clock Domain (Serial Clock):**

Connect Clocking Wizard `serial_clk` (371.25 MHz) to:
- rgb2hdmi `SerialClk`

**2. Add Reset Controller for Video Domain:**

The 74.25MHz domain needs its own reset controller.
- **Add IP:** Processor System Reset.
- **Connect:**
  - `slowest_sync_clk` ← `pixel_clk` (from Clocking Wizard)
  - `ext_reset_in` ← `PS FCLK_RESET0_N`
  - `dcm_locked` ← `locked` (from Clocking Wizard)

**3. Reset Connections (74.25 MHz Domain):**

Connect `peripheral_aresetn` from this **new** Reset block to:
- VTC `resetn`
- axis_to_video `resetn`
- rgb2hdmi `aRst_n` (if present)

**4. LED Status Wiring:**
- Locate `locked` pin on Clocking Wizard.
- Right-click → **Make External**.
- Rename port to `clk_locked`.
- (This connects to LED0 via constraints to visually confirm clock stability).

**5. Interrupt Connection (Critical for Linux):**
- Locate **Zynq Processing System** block
- Locate **AXI VDMA** block
- Connect `mm2s_introut` (VDMA) → `IRQ_F2P` (Zynq PS)
  - *Note:* If `IRQ_F2P` is a bus, connect it to the first bit `[0:0]` or use an AXI Concat block if you have multiple interrupts. For this single connection, direct wire usually works and defaults to ID 61 (29 + 32).

#### **3. Data Path Wiring (Manual Connections)**

Vivado automation often fails here. Perform these manually:

**A. VDMA to Axis_to_Video:**
**A. VDMA to Axis_to_Video:**
- Connect VDMA `M_AXIS_MM2S` directly to axis_to_video `s_axis`.
  *(Vivado should automatically group the TDATA, TVALID, TREADY, etc. signals)*

**B. VTC to Axis_to_Video (Video Timing):**
- Expand VTC `vtiming_out` interface.
- Connect individual wires to `axis_to_video`:
  - `active_video` → `vtc_active_video`
  - `hsync_out` → `vtc_hsync`
  - `vsync_out` → `vtc_vsync`
  - `f_sync_out` → `vtc_fsync`

**C. Axis_to_Video to RGB2HDMI:**
- Expand RGB2HDMI `RGB` interface.
- Connect `axis_to_video` outputs to `rgb2hdmi` inputs:
  - `vid_active_video` → `vid_pVDE`
  - `vid_data` → `vid_pData`
  - `vid_hsync` → `vid_pHSync`
  - `vid_vsync` → `vid_pVSync`

#### **6. External Ports**

**HDMI Output:**

Make the HDMI TMDS signals external:
1. Locate the rgb2hdmi block output: `TMDS` (differential pair bus)
2. Right-click `TMDS` → **Make External**
3. Vivado creates external ports: `TMDS_0_clk_n`, `TMDS_0_clk_p`, etc.
4. **Rename Port:**
   - Click the port `TMDS_0` (the bus) in the diagram.
   - In "External Interface Properties", change Name to: `hdmi_tx`
   - *Result:* Vivado will automatically map this to the constraint names (`hdmi_tx_clk_p`, etc.).

**Debug Signal (optional but recommended):**

Expose the PLL lock status to an LED:
1. Locate Clocking Wizard `locked` output
2. Right-click `locked` → **Make External**
3. Rename to `clk_locked`

#### **7. Validate Design**

Before generating bitstream:
1. Click **Validate Design** (F6) button in toolbar
2. Fix any errors (warnings about unconnected optional ports are usually OK)
3. **Save** the block design

**Expected Validation Messages:**
- ✅ "Validation successful. There are no errors or critical warnings in this design."
- ⚠️ Warnings about optional clocks/resets not connected are acceptable
- ⚠️ Warnings about the PS DDR interface is expected
- ⚠️ Warnings about the TDATA_NUM_BYTES for the axis_to_video block is expected

---

### **Part E: Physical Constraints (Pin Mapping)**

The abstract `hdmi_tx` port must be mapped to actual FPGA pins on the PYNQ-Z2 board.

**1. Create Constraints File:**

1. In Vivado, go to **Sources** panel
2. Right-click **Constraints** folder → **Add Sources** (or Create File)
3. Select **Add or create constraints**
4. Click **Create File**
5. Name it `hdmi_pinout.xdc`
6. Click **Finish**

**2. Add Pin Constraints:**

Open `hdmi_pinout.xdc` and add the following:

```tcl
# HDMI TX Signals
set_property -dict { PACKAGE_PIN L16   IOSTANDARD TMDS_33  } [get_ports { hdmi_tx_clk_p }]; 
set_property -dict { PACKAGE_PIN L17   IOSTANDARD TMDS_33  } [get_ports { hdmi_tx_clk_n }]; 
set_property -dict { PACKAGE_PIN K17   IOSTANDARD TMDS_33  } [get_ports { hdmi_tx_data_p[0] }]; 
set_property -dict { PACKAGE_PIN K18   IOSTANDARD TMDS_33  } [get_ports { hdmi_tx_data_n[0] }]; 
set_property -dict { PACKAGE_PIN K19   IOSTANDARD TMDS_33  } [get_ports { hdmi_tx_data_p[1] }]; 
set_property -dict { PACKAGE_PIN J19   IOSTANDARD TMDS_33  } [get_ports { hdmi_tx_data_n[1] }]; 
set_property -dict { PACKAGE_PIN J18   IOSTANDARD TMDS_33  } [get_ports { hdmi_tx_data_p[2] }]; 
set_property -dict { PACKAGE_PIN H18   IOSTANDARD TMDS_33  } [get_ports { hdmi_tx_data_n[2] }]; 

# Debug LED (LD0) - Maps to Clock Lock status
set_property -dict { PACKAGE_PIN R14   IOSTANDARD LVCMOS33 } [get_ports { clk_locked }];
```
Save the file.

---

### **Part F: Generate Bitstream and Export Hardware**

Now we build the design and create the hardware description for PetaLinux.

**Generate Bitstream:**

1. In Flow Navigator, click **Generate Bitstream**
2. (Optional) Review synthesis/implementation settings:
   - **Strategy:** Vivado Implementation Defaults
   - For timing issues: try **Performance_ExplorePostRoutePhysOpt**
3. Click **OK** to start the build

**Expected Duration:** 10-30 minutes depending on your machine

**Build Progress:**
- ✅ Synthesis (5-10 min)
- ✅ Implementation (10-20 min)
- ✅ Bitstream generation (1-2 min)

**Check for Errors:**

After completion, check the **Messages** panel:
- ❌ **Critical Warnings about clock domain crossing:** Review carefully
- ⚠️ **Warnings about unconnected optional ports:** Usually safe to ignore
- ❌ **Timing violations (negative slack):** See Part G below

**Export Hardware:**

Once bitstream generation succeeds:

1. Go to **File** → **Export** → **Export Hardware**
2. Select **Include bitstream** ✅
3. Choose export location:
   - Navigate to: `<petalinux_project>/project-spec/hw-description/`
   - Or export to a temporary location and copy later
4. **XSA file name:** `system.xsa` (or `system_design_wrapper.xsa`)
5. Click **OK**

The XSA file contains:
- Hardware configuration (IP addresses, interrupts, clocks)
- Device tree metadata
- Compiled bitstream (.bit file)
- FPGA initialization code

---

## **4. Testing the Hardware (Optional)**

You can test the bitstream before configuring Linux.

**Program FPGA via JTAG:**

1. Power on PYNQ-Z2
2. Connect the Micro-USB cable (PROG/UART) to your PC.
   * *Note:* The PYNQ-Z2 has onboard JTAG built-in via this port; no external JTAG adapter is needed.
3. Vivado: **Flow Navigator** → **Program and Debug** → **Open Hardware Manager**
4. Click **Open Target** → **Auto Connect**
5. Right-click on the FPGA device → **Program Device**
6. Select your `.bit` file: `<project>/impl_1/system_design_wrapper.bit` (_this should automatically be selected_)
7. Click **Program**

**Expected Behavior:**

✅ **LED0 (LD0) turns ON:** PLL is locked, clocks are stable  
❌ **LED0 off or flickering:** Clock generation issue - check power supply or PLL config  
❓ **HDMI monitor shows "No Signal":** Expected - VDMA not configured yet (needs Linux driver)

**At this stage:** The hardware is programmed but idle. The VDMA has no framebuffer address configured, so no video data flows. This is normal and will be fixed in Step 8 when we configure the DRM driver.

---

## **5. Summary and Next Steps**

### **What You Built:**

You've created a complete **video output pipeline** in the Zynq FPGA:

✅ **AXI VDMA** - Fetches framebuffer pixels from DDR RAM  
✅ **axis_to_video** - Synchronizes AXI-Stream with video timing, strips alpha channel  
✅ **Video Timing Controller** - Generates 720p60 sync signals  
✅ **rgb2hdmi** - Encodes RGB to HDMI TMDS for physical output  
✅ **Clock generation** - Produces 74.25 MHz pixel clock and 371.25 MHz serial clock  
✅ **Pin constraints** - Maps signals to physical PYNQ-Z2 HDMI connector  

### **Hardware Architecture:**

```
Linux DRM → DDR RAM ← VDMA → axis_to_video + VTC → rgb2hdmi → HDMI Monitor
         (framebuffer)  (read)    (sync)         (encode)   (display)
```

### **Key Deliverables:**

1. ✅ `system.xsa` - Hardware description exported to PetaLinux
2. ✅ `system_design_wrapper.bit` - FPGA bitstream
3. ✅ Documented IP addresses (VDMA: 0x43000000, VTC: 0x43C10000)
4. ✅ Verified timing closure (WNS > 0)

### **What's Next:**

**Step 8: Linux Configuration (Software Side)**

Now that the hardware exists, we need to configure PetaLinux to:
1. ✅ **Device Tree** - Describe the video hardware to Linux kernel
2. ✅ **Kernel Config** - Enable DRM drivers (`CONFIG_DRM_XLNX_PL_DISP=y`)
3. ✅ **Kernel Module** - Load `xlnx_dummy_connector` for display mode reporting
4. ✅ **Test** - Verify `/dev/fb0` and `/dev/dri/card0` appear
5. ✅ **Display** - Use `modetest` to show test patterns

The hardware is ready. Next step: teach Linux how to use it!

---

## **Troubleshooting**

### **Common Issues**

**Problem: Bitstream generation fails with timing violations**

**Solution:**
- Use **Performance_ExplorePostRoutePhysOpt** strategy
- Check if 371.25 MHz serial clock is too fast - may need better power supply
- Simplify design: Remove unused features or debug signals

**Problem: Can't find rgb2hdmi IP in catalog**

**Solution:**
- Verify Digilent library was added: Settings → IP → Repository
- Check repository path is correct and contains `ip/` subdirectory
- Refresh IP catalog: Tools → Reports → Report IP Status → Refresh

**Problem: Port names don't match constraints**

**Solution:**
```tcl
# List all external ports
report_ports
# Or in Tcl console:
get_ports *hdmi*
# Update constraint file with actual names
```

**Problem: Design validation shows unconnected ports**

**Solution:**
- Check if reset ports need connections
- Optional ports (like VTC detector inputs) can be left unconnected
- Use **Constant** IP blocks to tie unused inputs to '0' or '1'

**Problem: Address Editor shows overlapping addresses**

**Solution:**
- Right-click IP with address conflict → **Unassign**
- Click **Assign All** to let Vivado auto-assign non-conflicting addresses
- Manually set address: Right-click → **Assign Address** → Enter specific address

---

## **Additional Resources**

- **PYNQ-Z2 Reference Manual:** https://reference.digilentinc.com/reference/programmable-logic/pynq-z2/reference-manual
- **Digilent rgb2dvi IP:** https://github.com/Digilent/vivado-library/tree/master/ip/rgb2dvi
- **Xilinx VDMA Product Guide:** PG020
- **Video Timing Controller Guide:** PG016
- **Zynq-7000 TRM:** UG585 (Technical Reference Manual)

For detailed software configuration, see **Step 8** and the main [README.md](../README.m

# Input Clock from PS (100 MHz)
create_clock -period 10.000 -name fclk0 [get_pins processing_system7_0/inst/PS7_i/FCLKCLK[0]]

# Mark clock domains as asynchronous (prevents false timing violations)
set_clock_groups -asynchronous \
    -group [get_clocks fclk0] \
    -group [get_clocks pixel_clk] \
    -group [get_clocks serial_clk]
```

**Key Points:**
- **TMDS_33:** I/O standard for HDMI differential signaling at 3.3V
- **clk_locked LED:** If this LED is solid ON after programming, clocks are stable
- **Timing constraints:** Help Vivado optimize the design to meet timing requirements
- **Asynchronous clock groups:** Tell Vivado these clocks are unrelated (prevents false path analysis)

**3. Verify Port Names Match:**

If your external port names differ (e.g., `TMDS_0_clk_p` instead of `hdmi_tx_clk_p`), update the constraint file accordingly:

```tcl
# Check actual port names in the block design
# Flow Navigator → Open Elaborated Design → I/O Ports window
```

Or use generic wildcards:
```tcl
set_property -dict {PACKAGE_PIN L16 IOSTANDARD TMDS_33} [get_ports {*clk_p}]
```

### **Part F: Design Validation (Quality Control)**

Before we start fighting with Linux drivers, we must verify the "Digital Physics" of our design.

1\. The "Heartbeat" Check (LED Debugging)  
We want physical proof that our 74.25MHz/371MHz clocks are stable.

* **Action (In Block Design):** Find the **Clocking Wizard** block. Locate the locked output pin.  
* **Wire it:** Right-click locked \-\> **Make External**. Rename the port to clk\_locked.  
* **Result:** When you program this bitstream later, **LED0 (LD0)** on the board should light up SOLID. If it flickers or stays off, your power supply is weak or the PLL configuration is wrong.

2\. Timing Closure Analysis  
The HDMI serializer runs at 371.25 MHz. This is fast for the Zynq-7000 fabric.

* **Action:** After Bitstream Generation completes, open the **Implementation Run**.  
* **Check:** Look at the **Timing Summary** report.  
* **Metric:** Check **WNS (Worst Negative Slack)**.  
  * **Positive Number (e.g., 0.120 ns):** PASS. The signal arrives on time.  
  * **Negative Number (e.g., \-0.450 ns):** FAIL. The signal arrives too late. The video will glitch or show "No Signal".  
* **Fix (If Negative):** You may need to use "Performance\_Explore" implementation strategies in Vivado settings.

## **4\. Recap & What's Next**

You have physically wired a Video Card inside your chip.

* **VDMA** acts as the card's memory controller.  
* **VTC** acts as the CRT controller (sync generator).  
* **RGB2DVI** acts as the physical transmitter (PHY).

**Next Step:** In Step 8, we will return to PetaLinux to enable the xlnx-drm drivers, which will detect this pipeline and expose it to Debian as /dev/dri/card0 (a standard graphics card).

## **5. Next Step**

The video pipeline is wired. Now we need to teach Linux how to drive it.

**[Go to Step 8: Linux DRM Driver](loopback_step8.md)**