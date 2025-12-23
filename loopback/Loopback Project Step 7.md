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

*Note: This step covers Vivado hardware design only. Linux driver configuration is Step 8. USB support is not included in this step.*

## **2. Prerequisites**

Before starting:

* ✅ **Vivado 2025.1** or compatible version installed
* ✅ **loopback_system** project from Step 2 (or equivalent Zynq design)
* ✅ **Internet connection** to download Digilent IP library
* ✅ **Git** installed for cloning repositories
* ✅ **axis_to_video.v** module (located in project root directory)

## **3. Step-by-Step Instructions**

### **Part A: Install Digilent IP Library**

The PYNQ-Z2 HDMI port uses TMDS signaling, which requires a specialized encoder. Xilinx doesn't provide native TMDS IP for Zynq-7000, so we use Digilent's open-source rgb2hdmi encoder.

**1. Clone the Digilent Vivado Library:**

```bash
# Navigate to a directory for third-party IP (outside your project)
cd ~/xilinx_ip  # Or C:\xilinx_ip on Windows
git clone https://github.com/Digilent/vivado-library.git
```

**2. Add Repository to Vivado:**

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
- ✅ **FCLK_CLK1**: 100 MHz (enable this for video subsystem)
  - This provides the base clock for AXI-Lite control registers and general PL logic

**4. Apply Changes:**
- Click **OK** to close the configuration
- The Zynq PS block should now show the HP0 port on the left side

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
    - Source: Single ended clock capable pin
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
- **Read Channel (MM2S) Tab:**
  - **Stream Data Width:** 32 (for XRGB8888 format)
  - **Frame Buffers:** 3 (triple buffering)
  - **Enable Frame Counter:** ✅ (useful for debugging)
  - **GenLock Mode:** Disabled
- **Advanced Tab:**
  - **Address Width:** 32 bits
  - **Enable Internal GenLock:** Unchecked
  - **Max Burst Length:** 16 (default)
- Click **OK**

**3. Add Video Timing Controller (VTC):**

**Add IP:**
- Search: **Video Timing Controller**
- Double-click to add

**Configure:**
- Double-click the VTC block
- **Generator Tab:**
  - ✅ **Enable Generator**
  - **Active Samples per Line:** 1280
  - **Active Lines per Frame:** 720
  - **Horizontal Blank:** 370 (110 + 40 + 220)
  - **Vertical Blank:** 30 (5 + 5 + 20)
  - **Horizontal Front Porch:** 110
  - **Horizontal Sync Width:** 40
  - **Horizontal Back Porch:** 220
  - **Vertical Front Porch:** 5
  - **Vertical Sync Width:** 5
  - **Vertical Back Porch:** 20
  - **Horizontal Sync Polarity:** Active High
  - **Vertical Sync Polarity:** Active High
- **Detector Tab:**
  - ❌ **Uncheck "Enable Detection"** (we only generate, not detect)
- **General Tab:**
  - **Max Lines per Frame:** 2200 (leave default)
  - **Max Pixels per Line:** 4096 (leave default)
- Click **OK**

**Note:** These timing values define 720p60 (1280×720 @ 60 Hz with 74.25 MHz pixel clock).

**4. Add axis_to_video Custom Module:**

This module bridges the AXI-Stream from VDMA to parallel video signals synchronized with VTC timing.

**Option A: Add as RTL Module (Recommended)**

1. In Vivado, go to **Sources** → **Add Sources** (Alt+A)
2. Select **Add or create design sources**
3. Click **Add Files**
4. Navigate to your project root and select `axis_to_video.v`
5. ✅ Check **Copy sources into project** (optional, keeps project self-contained)
6. Click **Finish**
7. In the block design, right-click canvas → **Add Module**
8. Select **axis_to_video** from the list
9. Click **OK**

**Option B: Package as IP (Alternative)**

If you prefer to package it as reusable IP:
1. Tools → **Create and Package New IP**
2. Select **Package your current project** or **Package a specified directory**
3. Follow the IP packaging wizard
4. Once packaged, add it like any other IP block

**Configure axis_to_video:**

The module has parameters with defaults:
- `STREAM_WIDTH`: 24 (default) - we'll override connections for 32-bit
- `VIDEO_DATA_WIDTH`: 24 (output RGB)

No GUI configuration needed if using default parameters.

**5. Add RGB to DVI Video Encoder (Digilent):**

**Add IP:**
- Search: **RGB to DVI Video Encoder** (should appear if Digilent library was added)
- If not found: verify repository was added correctly in Part A
- Double-click to add

**Configure:**
- Double-click the rgb2hdmi (RGB to DVI) block
- **Parameters:**
  - **kRstActiveHigh:** `false` (Active Low reset)
  - **kClkPrimitive:** `MMCM` (default)
  - **kClkRange:** 1 (for 74.25 MHz, range 1 is suitable)
  - **kEdidFileName:** (leave default or blank)
- Click **OK**

---

### **Part D: Connect the Pipeline (Critical Wiring)**

Video pipelines are sensitive to clock domains. Each signal must be on the correct clock. Follow carefully.

#### **1. Clock Connections**

**Connect Clocking Wizard Input:**
- `clk_in1` → Zynq PS `FCLK_CLK0` (100 MHz)
- `resetn` → Processor System Reset `peripheral_aresetn[0]`

**100 MHz Clock Domain (AXI Control):**

Connect Zynq PS `FCLK_CLK0` (or use a separate 100 MHz from clocking wizard) to:
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
##################################################
---

### **Part F: Generate Bitstream and Export Hardware**

Now we build the design and create the hardware description for PetaLinux.

**1. Create HDL Wrapper (if not done):**

If your block design doesn't have a wrapper:
1. In Sources panel, right-click `system_design.bd`
2. Select **Create HDL Wrapper**
3. Choose **Let Vivado manage wrapper and auto-update**
4. Click **OK**

This creates `system_design_wrapper.v` as the top-level module.

**2. Generate Bitstream:**

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

**3. Check for Errors:**

After completion, check the **Messages** panel:
- ❌ **Critical Warnings about clock domain crossing:** Review carefully
- ⚠️ **Warnings about unconnected optional ports:** Usually safe to ignore
- ❌ **Timing violations (negative slack):** See Part G below

**4. Export Hardware:**

Once bitstream generation succeeds:

1. Go to **File** → **Export** → **Export Hardware**
2. Select **Include bitstream** ✅
3. Choose export location:
   - Navigate to: `<petalinux_project>/project-spec/hw-description/`
   - Or export to a temporary location and copy later
4. **XSA file name:** `system.xsa` (or `system_wrapper.xsa`)
5. Click **OK**

The XSA file contains:
- Hardware configuration (IP addresses, interrupts, clocks)
- Device tree metadata
- Compiled bitstream (.bit file)
- FPGA initialization code

---

### **Part G: Validation and Timing Closure**

Before deploying to hardware, verify the design meets requirements.

#### **1. Timing Analysis**

High-speed video clocks (371.25 MHz) are challenging for the Zynq-7000 fabric. We must verify timing closure.

**Open Timing Summary:**
1. After bitstream generation, Flow Navigator → **Open Implemented Design**
2. Go to **Reports** → **Timing** → **Report Timing Summary**
3. Or: Already opened automatically in the Implemented Design window

**Check Critical Metrics:**

**Worst Negative Slack (WNS):**
- **Value > 0** (e.g., +0.120 ns): ✅ **PASS** - All paths meet timing
- **Value < 0** (e.g., -0.450 ns): ❌ **FAIL** - Some signals arrive too late

**Worst Hold Slack (WHS):**
- **Value > 0**: ✅ **PASS** - No hold violations
- **Value < 0**: ❌ **FAIL** - Data changes too quickly

**Worst Pulse Width Slack (WPWS):**
- **Value > 0**: ✅ **PASS** - Clock duty cycle is acceptable

**If Timing Fails (WNS or WHS < 0):**

1. **Check failing paths:**
   - Click on the negative slack value to see detailed path report
   - Usually involves the 371.25 MHz serial clock domain

2. **Solutions:**
   - **Re-run implementation:** Sometimes different routing solves it
     - Flow Navigator → Implementation → Right-click → **Implementation Options**
     - Strategy: **Performance_ExplorePostRoutePhysOpt**
   - **Add pipeline registers:** Modify axis_to_video or rgb2hdmi to add register stages
   - **Reduce clock frequency:** Lower to 720p30 (37.125 MHz pixel clock) for testing
   - **Check power supply:** Weak power can cause PLL instability

3. **For persistent issues:**
   ```tcl
   # In Tcl console, relax timing slightly (not recommended for production)
   set_clock_uncertainty -setup 0.5 [get_clocks serial_clk]
   ```

#### **2. Resource Utilization**

Check FPGA resource usage:

**Open Utilization Report:**
- Reports → **Utilization** → **Report Utilization**

**Key Resources (Zynq-7020):**

| Resource | Used | Available | Utilization | Status |
|----------|------|-----------|-------------|--------|
| LUTs | ~5,000 | 53,200 | ~9% | ✅ Good |
| Flip-Flops | ~7,000 | 106,400 | ~7% | ✅ Good |
| DSPs | 0-5 | 220 | <2% | ✅ Good |
| BRAMs | 10-30 | 140 | ~20% | ✅ Good |
| MMCM/PLL | 1-2 | 4 | 25-50% | ✅ Good |

**⚠️ If any resource >80%:** Consider optimizing or using a larger FPGA

#### **3. Visual Inspection (Block Design)**

**Sanity checks:**
- ✅ All clock domains properly connected
- ✅ No red or orange warning icons on IP blocks
- ✅ All data paths have correct bit widths (e.g., 32-bit VDMA → 24-bit video)
- ✅ Resets are active-low where expected
- ✅ AXI addresses don't overlap

**Generate PDF schematic (optional):**
1. File → **Export** → **Export Block Design**
2. Choose format: PDF
3. Useful for documentation and debugging

#### **4. Hardware Validation Checklist**

Before moving to software:

| Check | Status | Notes |
|-------|--------|-------|
| Bitstream generated without errors | ☐ | |
| Timing closure achieved (WNS > 0) | ☐ | Critical for stability |
| XSA file exported to PetaLinux | ☐ | |
| Pin constraints match PYNQ-Z2 | ☐ | Verify against schematic |
| `clk_locked` signal routed to LED | ☐ | For visual debugging |
| VDMA base address noted | ☐ | Needed for device tree |
| VTC base address noted | ☐ | Needed for device tree |

**Record IP Addresses:**

From **Address Editor** tab, note these for the device tree (Step 8):
```
VDMA (axi_vdma_0):     0x43000000
VTC (v_tc_0):          0x43C10000
```

---

## **4. Testing the Hardware (Optional)**

If you have hardware access, you can test the bitstream before configuring Linux.

**Program FPGA via JTAG:**

1. Power on PYNQ-Z2
2. Connect JTAG cable (USB-JTAG or Digilent adapter)
3. Vivado: **Flow Navigator** → **Program and Debug** → **Open Hardware Manager**
4. Click **Open Target** → **Auto Connect**
5. Right-click on the FPGA device → **Program Device**
6. Select your `.bit` file: `<project>/impl_1/system_design_wrapper.bit`
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

**Connect Resets:**

100 MHz domain:
- All AXI IP `aresetn` ports → `peripheral_aresetn[0]` from 100 MHz reset block

74.25 MHz domain:
- axis_to_video `resetn` → `peripheral_aresetn[0]` from 74.25 MHz reset block
- rgb2hdmi `aRst_n` → `peripheral_aresetn[0]` from 74.25 MHz reset block
- VTC might use 100 MHz reset since it's AXI-controlled

#### **3. Data Path Connections**

**VDMA → axis_to_video:**

Connect VDMA AXI-Stream output to axis_to_video input:
- `M_AXIS_MM2S` → `s_axis` (full interface)
  - `TDATA[31:0]` → `s_axis_tdata[23:0]` (only lower 24 bits)
  - `TVALID` → `s_axis_tvalid`
  - `TREADY` → `s_axis_tready`
  - `TUSER` → `s_axis_tuser` (frame start indicator)
  - `TLAST` → `s_axis_tlast` (line end indicator)

**Note:** If VDMA outputs 32-bit but axis_to_video expects 24-bit, you may need:
- Option 1: Change axis_to_video parameter `STREAM_WIDTH` to 32
- Option 2: Use an AXI4-Stream Subset Converter to drop upper 8 bits
- Option 3: Manually connect lower 24 bits: `TDATA[23:0]` → `s_axis_tdata[23:0]`

**VTC → axis_to_video:**

Connect VTC timing signals:
- VTC `fsync` → axis_to_video `vtc_fsync`
- VTC `active_video` → axis_to_video `vtc_active_video`
- VTC `hsync` → axis_to_video `vtc_hsync`
- VTC `vsync` → axis_to_video `vtc_vsync`

**Note:** VTC outputs these signals on the `vtiming_out` interface. You may need to:
- Expand the `vtiming_out` bus by clicking the **+** icon
- Manually connect individual signals

**axis_to_video → rgb2hdmi:**

Connect video output:
- axis_to_video `vid_data[23:0]` → rgb2hdmi `vid_pData[23:0]`
- axis_to_video `vid_hsync` → rgb2hdmi `vid_pHSync`
- axis_to_video `vid_vsync` → rgb2hdmi `vid_pVSync`
- axis_to_video `vid_active_video` → rgb2hdmi `vid_pVDE` (Video Data Enable)

#### **4. Control Path (AXI Interconnect)**

Let Vivado automate the AXI control connections:

1. Click **Run Connection Automation** at the top of the block design
2. Select **All Automation** checkbox
3. Review the connections:
   - VDMA `S_AXI_LITE` → Zynq PS `M_AXI_GP0` (via AXI Interconnect)
   - VTC `ctrl` → Zynq PS `M_AXI_GP0`
4. Click **OK**

This creates an AXI Interconnect (or uses existing one) to connect PS master port to IP slave ports.

#### **5. High-Performance Data Path**

**VDMA memory read:**
- VDMA `M_AXI_MM2S` → Zynq PS `S_AXI_HP0`
- May require an AXI Interconnect if other masters share HP0
- Or direct connection if VDMA is the only master

**Assign Address:**
1. Open **Address Editor** tab
2. Verify VDMA and VTC have assigned addresses in GP0 space (0x4000_0000 - 0x7FFF_FFFF range)
3. If unassigned, right-click → **Assign Address**
4. Note the addresses (needed for device tree later)

#### **6. External Ports**

**HDMI Output:**

Make the HDMI TMDS signals external:
1. Locate the rgb2hdmi block output: `TMDS` (differential pair bus)
2. Right-click `TMDS` → **Make External**
3. Vivado creates external ports: `TMDS_0_clk_n`, `TMDS_0_clk_p`, `TMDS_0_data_n[2:0]`, `TMDS_0_data_p[2:0]`
4. Rename for clarity:
   - `TMDS_0` → `hdmi_tx` (Vivado will append `_clk_p`, `_clk_n`, etc.)

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

### **Part D: Constraints (Physical Mapping)**

We must map the abstract hdmi\_tx port to the actual pins on the PYNQ-Z2 board. Also, we will map a debug LED.

1. **Create Constraints File:**  
   * Sources \> Constraints \> Add New File (hdmi\_constraints.xdc).  
2. Add Pinout:  
   Copy the standard PYNQ-Z2 HDMI TX constraints:  
   \# HDMI TX Signals  
   set\_property \-dict { PACKAGE\_PIN L16   IOSTANDARD TMDS\_33  } \[get\_ports { hdmi\_tx\_clk\_p }\];   
   set\_property \-dict { PACKAGE\_PIN L17   IOSTANDARD TMDS\_33  } \[get\_ports { hdmi\_tx\_clk\_n }\];   
   set\_property \-dict { PACKAGE\_PIN K17   IOSTANDARD TMDS\_33  } \[get\_ports { hdmi\_tx\_data\_p\[0\] }\];   
   set\_property \-dict { PACKAGE\_PIN K18   IOSTANDARD TMDS\_33  } \[get\_ports { hdmi\_tx\_data\_n\[0\] }\];   
   set\_property \-dict { PACKAGE\_PIN K19   IOSTANDARD TMDS\_33  } \[get\_ports { hdmi\_tx\_data\_p\[1\] }\];   
   set\_property \-dict { PACKAGE\_PIN J19   IOSTANDARD TMDS\_33  } \[get\_ports { hdmi\_tx\_data\_n\[1\] }\];   
   set\_property \-dict { PACKAGE\_PIN H16   IOSTANDARD TMDS\_33  } \[get\_ports { hdmi\_tx\_data\_p\[2\] }\];   
   set\_property \-dict { PACKAGE\_PIN H17   IOSTANDARD TMDS\_33  } \[get\_ports { hdmi\_tx\_data\_n\[2\] }\]; 

   \# Debug LED (LD0) \- Maps to Clock Lock status  
   set\_property \-dict { PACKAGE\_PIN R14   IOSTANDARD LVCMOS33 } \[get\_ports { clk\_locked }\];

### **Part E: Build & Export**

1. **Generate Bitstream:** Run the build. (This may take longer due to timing constraints on the video clock).  
2. **Export Hardware:** Export system\_wrapper.xsa (Include Bitstream).

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