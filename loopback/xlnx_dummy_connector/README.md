# Xilinx DRM Dummy Connector Driver

## **Why do we need this?**

The Xilinx DRM usage model (`xlnx-pl-disp`) is strictly pipeline-based. It expects a chain of hardware components:
`CRTC (Video Timing) -> Encoder -> Connector (Physical Output)`

In a typical professional system (like the ZCU102 or PYNQ-Z2's default HDMI input), the "Connector" involves an I2C channel to read the **EDID** (Extended Display Identification Data) from the connected monitor. This allows the Linux kernel to ask the monitor: *"What resolution do you support?"*

**The Problem:**
Our simplistic FPGA design ("Loopback Step 7") outputs raw video signals (VSYNC, HSYNC, DATA) directly to the HDMI pins. **We did not implement an I2C controller for DDC (Data Display Channel).**

When the standard Linux DRM driver tries to initialize, it looks for an I2C bus to talk to the monitor. When it finds none, or if we don't provide a "Bridge" driver, the entire pipeline fails to initialize because the graph is incomplete. The kernel says: *"I have a video generator, but I don't know what it's connected to, so I will do nothing."*

## **How it works**

This module (`xlnx_dummy_connector`) acts as a **Software Lie**. It registers itself with the Linux DRM subsystem as a legitimate physical connector.

When the kernel asks: *"Is anything connected?"*
*   **Dummy Driver:** *"Yes, always."*

When the kernel asks: *"What modes do you support?"*
*   **Dummy Driver:** *"I support exactly one mode: 1280x720 at 60Hz."*

### **Technical Details**

1.  **Device Tree Linkage:**
    It sits at the end of the `ports` graph in the Device Tree.
    `xlnx-pl-disp (CRTC) -> ports -> endpoint -> dummy-connector`

2.  **Hardcoded Timings:**
    It provides a `drm_display_mode` struct filled with the exact timing parameters (front porch, back porch, sync width) that match our fixed hardware configuration in the FPGA's **Video Timing Controller (VTC)**.

3.  **Hotplug Emulation:**
    It reports a status of `connector_status_connected` immediately on initialization, tricking the desktop environment or console into waking up the display output.

## **Usage**

### **1. Compilation**
This is a standard Linux kernel module. In the context of PetaLinux:
```bash
petalinux-create -t modules --name xlnx-dummy-connector --enable
```
(Then replace the generated `.c` file with the one in this directory).

### **2. Device Tree Configuration**
It requires a corresponding node in `system-user.dtsi`:

```dts
hdmi_out: hdmi-output {
    compatible = "xlnx,dummy-connector";
    status = "okay";
    
    port {
        dummy_in: endpoint {
            remote-endpoint = <&pl_disp_out>;
        };
    };
};
```

### **3. Verification**
Once loaded, it appears in `dmesg`:
```
[drm] Found connector HDMI-A-1
```
And enables functionality for `/dev/dri/card0`.
