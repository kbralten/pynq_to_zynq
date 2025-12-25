# **Loopback Project Step 8: Linux DRM Driver Configuration**

## **1. The Goal**

Configure the Linux kernel and device tree to recognize our FPGA video pipeline as a standard DRM graphics device (`/dev/dri/card0` and `/dev/fb0`).

By the end of this step, the system will:
- ✅ Expose the HDMI output as a DRM device
- ✅ Create a framebuffer (`/dev/fb0`) for direct pixel access
- ✅ Support DRM/KMS for X11 and Wayland compositors
- ✅ Display test patterns via `modetest` utility

### What We're Building

```
Linux Software Stack:
┌─────────────────────────────────────┐
│   Userspace (X11/Wayland/Apps)      │
├─────────────────────────────────────┤
│   DRM/KMS Framework (/dev/dri/)     │
├─────────────────────────────────────┤
│  xlnx-pl-disp Driver (Kernel)       │
│  xlnx_dummy_connector Module        │
├─────────────────────────────────────┤
│     Device Tree Configuration       │
├─────────────────────────────────────┤
│    Hardware (VDMA, VTC, HDMI)       │ ← Created in Step 7
└─────────────────────────────────────┘
```

*Note: This step covers Linux kernel and device tree configuration only. Desktop environment setup is covered in later steps. USB support is not included in this step.*

## **2. Prerequisites**

Before starting, ensure:

* ✅ **Step 7 completed:** Hardware design with video pipeline created in Vivado
* ✅ **XSA file exported:** `system.xsa` available in `project-spec/hw-description/`
* ✅ **PetaLinux project:** `loopback_os` project environment sourced
* ✅ **IP addresses noted:** VDMA and VTC base addresses from Vivado Address Editor
  - Example: VDMA @ 0x43000000, VTC @ 0x43C10000
* ✅ **axis_to_video.v:** Custom RTL module in project root (used in hardware)

## **3. Step-by-Step Instructions**

### **Part A: Update Hardware Definition (Import XSA)**

Before configuring drivers, we must tell PetaLinux about the new hardware design (XSA) we exported in Step 7.

1.  **Locate your XSA:**
    Ensure you know where you exported `system_design_wrapper.xsa` in Step 7.

2.  **Import to PetaLinux:**
    ```bash
    cd ~/projects/loopback_os
    petalinux-config --get-hw-description=<path-to-folder-containing-xsa> --silentconfig
    ```
    *   *Example:* `petalinux-config --get-hw-description=~/projects/loopback_system/ --silentconfig`
    *   **Note:** The `--silentconfig` flag accepts default settings, which preserves our previous rootfs configuration. If you updated the bitstream, this is critical to ensure `system.bit` is updated.

### **Part C: Create Custom Kernel Module (xlnx_dummy_connector)**

The Xilinx PL Display driver requires a DRM connector/bridge to report display modes. We will create a new kernel module for this.

#### **1. Create the Module**

Use the PetaLinux tool to strictly create and register the module recipe. This prevents "Nothing PROVIDES" errors.

```bash
cd ~/projects/loopback_os
petalinux-create -t modules --name xlnx-dummy-connector --enable
```

#### **2. Replace the Source Code**

PetaLinux creates a template "Hello World" driver. We need to replace it with our dummy connector code.

1.  **Download Our Driver Source:**
    *   **Source:** [`xlnx_dummy_connector.c`](xlnx_dummy_connector/xlnx_dummy_connector.c)

2.  **Overwrite the PetaLinux File:**
    ```bash
    # Go to the module source directory
    cd project-spec/meta-user/recipes-modules/xlnx-dummy-connector/files/
    
    # Copy our file here BUT rename it to match the recipe name (dashes)
    cp <path-to-downloaded>/xlnx_dummy_connector.c ./xlnx-dummy-connector.c
    ```

3.  **Update Makefile:**
    Ensure the Makefile targets the new filename (with dashes).

    Overwrite `Makefile` with:
    ```makefile
    obj-m := xlnx-dummy-connector.o

    SRC := $(shell pwd)

    all:
    	$(MAKE) -C $(KERNEL_SRC) M=$(SRC) modules

    modules_install:
    	$(MAKE) -C $(KERNEL_SRC) M=$(SRC) modules_install

    clean:
    	rm -f *.o *~ core .depend .*.cmd *.ko *.mod.c
    	rm -f Module.markers Module.symvers modules.order
    	rm -rf .tmp_versions Modules.symvers
    ```


### **Part D: Device Tree Configuration**

The device tree describes the hardware to the Linux kernel. This is critical for driver initialization.

#### **1. Open Device Tree File**

```bash
cd ~/projects/loopback_os
vi project-spec/meta-user/recipes-bsp/device-tree/files/system-user.dtsi
```

Or use your preferred editor.

#### **2. Add Complete Device Tree Configuration**

Replace or merge with the following complete configuration:

```dts
/include/ "system-conf.dtsi"

/ {
    /* Boot Arguments: Enable debugging and prevent clock shutdown */
    chosen {
        bootargs = "console=ttyPS0,115200 root=/dev/mmcblk0p2 rw rootwait earlyprintk clk_ignore_unused loglevel=8 drm.debug=0x1f";
    };

    /* 1. Define Reserved Memory for Video Buffers (CMA) */
    reserved-memory {
        #address-cells = <1>;
        #size-cells = <1>;
        ranges;

        video_mem: video_mem {
            compatible = "shared-dma-pool";
            reusable;
            size = <0x01000000>; /* 16MB - enough for triple-buffered 720p */
            alignment = <0x100000>; /* 1MB alignment */
            linux,cma-default;
        };
    };

    /* 2. Dummy Regulator (if needed by encoder) */
    reg_3v3: regulator-3v3 {
        compatible = "regulator-fixed";
        regulator-name = "3v3-supply";
        regulator-min-microvolt = <3300000>;
        regulator-max-microvolt = <3300000>;
        regulator-always-on;
    };

    /* 3. Dummy Connector Node */
    hdmi_out: hdmi-output {
        compatible = "xlnx,dummy-connector";
        status = "okay";
        
        port {
            dummy_in: endpoint {
                remote-endpoint = <&pl_disp_out>;
            };
        };
    };

    /* 4. Xilinx PL Display Driver */
    drm_pl_disp: drm-pl-disp-drv {
        compatible = "xlnx,pl-disp";
        status = "okay";
        
        /* DMA channel for video data */
        dmas = <&axi_vdma_0 0>;
        dma-names = "dma0";
        
        /* Video format: XR24 = XRGB8888 (32-bit) */
        xlnx,vformat = "XR24";
        
        /* VTC bridge for timing */
        xlnx,bridge = <&v_tc_0>;
        
        /* Use reserved CMA memory */
        memory-region = <&video_mem>;
        
        /* Output port to dummy connector */
        ports {
            #address-cells = <1>;
            #size-cells = <0>;
            
            port@0 {
                reg = <0>;
                pl_disp_out: endpoint {
                    remote-endpoint = <&dummy_in>;
                };
            };
        };
    };
};

/* MODIFY EXISTING NODES (auto-generated from .xsa) */

/* 5. Configure VDMA for DRM usage */
&axi_vdma_0 {
    status = "okay";
    #dma-cells = <1>;
    dma-ranges = <0x00000000 0x00000000 0x40000000>;
    xlnx,addrwidth = <32>;
    xlnx,num-fstores = <3>;
    
    /* Force VDMA MM2S stream clock to match VTC clock (74.25MHz) */
    clocks = <&clkc 15>, <&clkc 15>, <&misc_clk_0>, <&clkc 15>, <&clkc 15>;
    clock-names = "s_axi_lite_aclk", "m_axi_mm2s_aclk", "m_axis_mm2s_aclk", 
                  "m_axi_s2mm_aclk", "s_axis_s2mm_aclk";
    
    /* MM2S channel data width for 32-bit XRGB8888 */
    dma-channel@43000000 {
        xlnx,datawidth = <0x20>;  /* 32 bits */
    };
};

/* 6. Configure VTC with proper compatible strings and clocks */
&v_tc_0 {
    compatible = "xlnx,v-tc-6.2", "xlnx,v-tc-6.1", "xlnx,bridge-v-tc-6.1", "xlnx,bridge-vtc";
    status = "okay";
    
    /* VTC needs both pixel clock AND AXI clock */
    clock-names = "clk", "s_axi_aclk";
    clocks = <&misc_clk_0>, <&clkc 15>;
    
    /* Pixels per clock */
    xlnx,pixels-per-clock = <1>;
};

/* 7. Define pixel clock (74.25 MHz) */
/ {
    misc_clk_0: misc_clk_0 {
        compatible = "fixed-clock";
        #clock-cells = <0>;
        clock-frequency = <74250000>;   /* 74.25 MHz pixel clock */
    };
};
```

#### **Important Notes:**

1. **IP Names:** Verify that `&axi_vdma_0` and `&v_tc_0` match your Vivado IP names
   - Check: `build/tmp/work-shared/*/device-tree/pl.dtsi`
   - If names differ (e.g., `axi_vdma_1`), update the device tree accordingly

2. **Base Addresses:** The VDMA channel address (0x43000000) should match Vivado
   - Check in Vivado: Address Editor → axi_vdma_0 base address
   - Update `dma-channel@43000000` if different

3. **Clock References:**
   - `<&clkc 15>`: PS clock controller, typically FCLK_CLK0 (100 MHz)
   - `<&misc_clk_0>`: Custom pixel clock (74.25 MHz) defined above
   - If using Clocking Wizard output, reference it appropriately

4. **xlnx,vformat = "XR24":** Must match VDMA 32-bit data width
   - X = unused/alpha channel (8 bits)
   - R = Red (8 bits)
   - G = Green (8 bits)
   - B = Blue (8 bits)

5. **Boot Arguments:**
   - `clk_ignore_unused`: Prevents kernel from disabling unused clocks (critical!)
   - `drm.debug=0x1f`: Enables DRM debugging (remove after testing)
   - `loglevel=8`: Verbose kernel messages

#### **5. Add Module to Build**



Edit `project-spec/meta-user/conf/user-rootfsconfig`:

Add the following line at the end:
```
CONFIG_xlnx-dummy-connector
```

Or add to your layer configuration by editing `project-spec/meta-user/conf/layer.conf`:

```bitbake
IMAGE_INSTALL:append = " xlnx-dummy-connector"
```

---

### **Part E: Kernel Configuration**

Enable the necessary DRM drivers and video subsystem support.

#### **1. Create Kernel Configuration Fragment**

Create `project-spec/meta-user/recipes-kernel/linux/linux-xlnx/video_drm.cfg`:

```properties
# DRM Core
CONFIG_DRM=y
CONFIG_DRM_KMS_HELPER=y
CONFIG_DRM_FBDEV_EMULATION=y

# Xilinx DRM
CONFIG_DRM_XLNX=y
CONFIG_DRM_XLNX_BRIDGE=y
CONFIG_DRM_XLNX_BRIDGE_VTC=y
CONFIG_DRM_XLNX_PL_DISP=y

# Framebuffer Support
CONFIG_FB=y
CONFIG_FB_SYS_FILLRECT=y
CONFIG_FB_SYS_COPYAREA=y
CONFIG_FB_SYS_IMAGEBLIT=y
CONFIG_FB_SYS_FOPS=y
CONFIG_FB_DEFERRED_IO=y

# Framebuffer Console
CONFIG_FRAMEBUFFER_CONSOLE=y
CONFIG_FRAMEBUFFER_CONSOLE_DETECT_PRIMARY=y
CONFIG_LOGO=y
CONFIG_LOGO_LINUX_CLUT224=y

# Video Mode Helpers
CONFIG_VIDEOMODE_HELPERS=y
CONFIG_XILINX_FRMBUF=y

# CMA (Contiguous Memory Allocator)
CONFIG_DMA_CMA=y
CONFIG_CMA=y
CONFIG_CMA_SIZE_MBYTES=16
CONFIG_CMA_ALIGNMENT=8

# DMA Engine
CONFIG_XILINX_DMA=y
CONFIG_XILINX_DPDMA=y

# Debug (optional, remove in production)
CONFIG_DEBUG_KERNEL=y
CONFIG_DYNAMIC_DEBUG=y
```

#### **2. Update Kernel Recipe**

Edit or create `project-spec/meta-user/recipes-kernel/linux/linux-xlnx_%.bbappend`:

```bitbake
FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI += "file://video_drm.cfg"
```

This tells PetaLinux to apply your configuration fragment during kernel build.
---

### **Part F: Build the System**

We need to update the Kernel (modules) and Device Tree (system.dtb).

1. **Build:**
   ```bash
   petalinux-build -c kernel
   petalinux-build -c xlnx-dummy-connector
   petalinux-build -c device-tree
   ```

2. Package Boot Image:  
   (Because we changed the hardware in Step 7, we need a new BOOT.BIN with the new bitstream).  
   ```bash
   petalinux-package --boot --fsbl images/linux/zynq_fsbl.elf --fpga project-spec/hw-description/system_design_wrapper.bit --u-boot --force
   ```
   *   **Important:** We point to `project-spec/hw-description/system.bit` because `images/linux/system.bit` might be stale if we didn't run a full system build. The file in `project-spec` was updated when we imported the XSA in Part A.

3. **Update SD Card (Windows Friendly Method):**
   
   Since Windows cannot read the ext4 root partition, we will use the FAT32 boot partition as a bridge.

   *   **Copy Files to SD Card (BOOT partition):**
       From the `images/linux/` directory, copy:
       1.  `BOOT.BIN`
       2.  `image.ub`
       3.  `boot.scr`
       4.  **`xlnx-dummy-connector.ko`** (Copy this file here so we can access it from Linux later).
           *   *Find it here:* `/build/tmp/sysroots-components/zynq_generic_7z020/xlnx-dummy-connector/lib/modules/6.12.10-xilinx-g0a0f70e531c7/updates/xlnx-dummy-connector.ko` 
           *   *(Or use `find . -name xlnx-dummy-connector.ko` to locate it)*

### **Part G: Final Configuration (On Target)**

1.  **Boot the Board:**
    Insert SD card, connect HDMI, and power on.

2.  **Install the Module:**
    The module is currently sitting in `/boot` (pynq-2.7/debian automatically mounts the FAT32 partition there).

    ```bash
    # 1. Create the extra modules directory
    sudo mkdir -p /lib/modules/$(uname -r)/extra/

    # 2. Copy the module from the boot partition
    sudo cp /boot/xlnx-dummy-connector.ko /lib/modules/$(uname -r)/extra/

    # 3. Register the module
    sudo depmod -a
    
    # 4. Verify it loads
    sudo modprobe xlnx-dummy-connector
    ```

### **Part H: Validation (The moment of truth)**

1. **Boot the Board:** Connect an HDMI monitor.  
2. **Check Kernel Logs:**  
   ```bash
   dmesg | grep drm
   ```

   * *Success:* You should see \[drm\] Initialized xlnx\_pl\_disp and \[drm\] Found connector HDMI-A-1.  
3. **Check Devices:**  
   ```bash
   ls /dev/dri/
   ```

   * *Success:* You should see card0 and controlD64.  
4. Run Modetest:  
   This tool talks directly to the kernel driver, bypassing X11.  
   ```bash
   #install the necessary packages
   sudo apt-get install libdrm-tests

   # List available connectors
   modetest -M xlnx -c

   # Run a test pattern (Connector ID 31, 720p60)  
   # Note: Replace '31' with the ID found in the previous command  
   modetest -M xlnx -s 31@30:1280x720-60
   ```

   * *Visual:* You should see a color bar pattern on your monitor\!

---

### **Part G: Testing and Verification**

Now verify that the hardware and drivers are working correctly.

#### **1. Check Kernel Driver Initialization**

```bash
# Check DRM subsystem messages
dmesg | grep -i drm

# Expected output (example):
# [drm] Initialized
# xlnx 1.0.0
# [drm] xlnx-pl-disp: found 1 planes
# [drm] Initialized xlnx 1.0.0 20130509 for drm-pl-disp-drv on minor 0
```

```bash
# Check for xlnx_dummy_connector
dmesg | grep -i dummy
---

## **4. Troubleshooting**

### **Issue: VDMA Probe Failed (No IRQ)**

**Symptoms:**
`dmesg` shows:
```
xilinx-vdma 43000000.dma: error -EINVAL: failed to get irq
xilinx-vdma 43000000.dma: probe with driver xilinx-vdma failed with error -22
```

**Cause:**
Authentication of the interrupt connection failed. You missed connecting the VDMA `mm2s_introut` signal to the Zynq PS `IRQ_F2P` port in Vivado (Step 7), or the XSA wasn't updated.

**Fix:**
1.  Open Vivado (Step 7).
2.  Enable `IRQ_F2P` in Zynq PS.
3.  Connect `axi_vdma_0` interrupt to Zynq PS.
4.  **Re-generate Bitstream** and **Export Hardware (XSA)**.
5.  Re-run Step 8 Part A (Import XSA) and Part F (Package/Deploy).

### **Issue: No /dev/dri/card0 or /dev/fb0**

**Symptoms:** DRM device not created

**Diagnosis:**
```bash
dmesg | grep -E "drm|xlnx|error"
lsmod | grep drm
ls /sys/class/drm/
```

**Common Causes:**
1. Module not loaded: `modprobe xlnx_dummy_connector`
2. Device tree mismatch: Check `compatible` strings
3. Missing kernel config: Verify `CONFIG_DRM_XLNX_PL_DISP=y`
4. VDMA not initialized: Check base address in device tree

**Fix:**
```bash
# Check device tree was applied
dtc -I dtb -O dts /boot/system.dtb | grep -A 20 "pl-disp"

# Verify hardware addresses
devmem 0x43000000  # Should return register value, not 0xFFFFFFFF

# Check for deferred probes
cat /sys/kernel/debug/devices_deferred
```

### **Issue: "Deferred probe pending"**

**Symptoms:** `dmesg` shows driver waiting indefinitely

**Cause:** Missing clock or dependency not met

**Fix:**
1. Ensure `clk_ignore_unused` in bootargs
2. Check VTC and VDMA clocks are enabled
3. Verify all device tree references are valid

```bash
# Check clock status
cat /sys/kernel/debug/clk/clk_summary | grep -E "74250000|pixel"
```

### **Issue: Black screen / No HDMI output**

**Symptoms:** Device created but no image

**Diagnosis:**
```bash
# Test framebuffer update
md5sum /dev/fb0  # Run twice, values should differ if updating

# Test with pattern
cat /dev/urandom | dd of=/dev/fb0 bs=1M count=4
```

**Common Causes:**
1. Clock not running (74.25 MHz pixel clock)
2. LED0 not lit (PLL not locked)
3. axis_to_video sync issue
4. Wrong pixel format

**Fix:**
```bash
# Check LED0 on board - should be solid ON
# If not, check power supply or PLL configuration

# Force pattern with modetest
modetest -M xlnx -s 31@30:1280x720

# Check VTC registers (example address)
devmem 0x43c10000
```

### **Issue: Display corruption / wrong colors**

**Symptoms:** Image appears but colors are wrong

**Cause:** Pixel format mismatch or channel swap issue

**Fix:**
- Verify `xlnx,vformat = "XR24"` in device tree
- Check VDMA data width is 32 bits
- axis_to_video might need channel reordering adjustment

### **Issue: Module build fails**

**Symptoms:** `petalinux-build -c xlnx-dummy-connector` fails

**Fix:**
```bash
# Rebuild kernel first to generate Module.symvers
petalinux-build -c kernel -x cleansstate
petalinux-build -c kernel

# Then build module
petalinux-build -c xlnx-dummy-connector
```

### **Issue: Device tree compilation errors**

**Symptoms:** `petalinux-build -c device-tree` fails

**Common Issues:**
- Syntax errors (missing semicolons, braces)
- Invalid phandle references
- Overlapping address ranges

**Fix:**
```bash
# Check device tree syntax
dtc -I dts -O dtb project-spec/meta-user/recipes-bsp/device-tree/files/system-user.dtsi

# View compiled tree
dtc -I dtb -O dts images/linux/system.dtb > /tmp/compiled.dts
less /tmp/compiled.dts
```

### **Useful Debug Commands**

```bash
# View all kernel messages
dmesg -w

# Check DRM state
cat /sys/kernel/debug/dri/0/state

# Check memory allocations
cat /proc/buddyinfo
cat /proc/meminfo | grep -E "Cma|Vma"

# List all loaded modules
lsmod

# Check interrupt activity
watch -n1 'cat /proc/interrupts | grep -E "vdma|Name"'

# Test DRM modesetting
modetest -M xlnx -c  # List connectors
modetest -M xlnx -e  # List encoders
modetest -M xlnx -p  # List CRTCs and planes
```

---

## **5. Summary and Next Steps**

### **What You Accomplished**

✅ **Created custom kernel module** (`xlnx_dummy_connector`) for DRM connector support  
✅ **Configured kernel** with DRM and framebuffer support  
✅ **Wrote device tree** describing video hardware to Linux  
✅ **Built PetaLinux system** with all components integrated  
✅ **Deployed to hardware** and verified DRM device creation  
✅ **Tested display** with modetest and framebuffer utilities  

### **System Architecture**

```
Application Layer:        X11 / Wayland / Direct Framebuffer
                                    ↓
DRM/KMS Layer:           /dev/dri/card0, /dev/fb0
                                    ↓
Kernel Drivers:          xlnx-pl-disp, xlnx_dummy_connector
                                    ↓
Device Tree:             Hardware description (VDMA, VTC)
                                    ↓
Hardware (PL):           VDMA → axis_to_video → rgb2hdmi → HDMI
```

### **What's Working**

- ✅ Hardware video pipeline (Step 7)
- ✅ Linux DRM driver recognizing hardware
- ✅ Framebuffer device for pixel access
- ✅ Test patterns via modetest
- ✅ Direct framebuffer writes
---

## **6. Additional Resources**

- **Xilinx DRM Wiki:** https://xilinx-wiki.atlassian.net/wiki/spaces/A/pages/18842546/Linux+DRM+KMS
- **DRM Programming:** https://dri.freedesktop.org/docs/drm/
- **PetaLinux Reference:** UG1144 - PetaLinux Tools Reference Guide
- **Device Tree Spec:** https://www.devicetree.org/

---

**🎉 Congratulations!** You've successfully created a complete video output system from hardware to software, including custom kernel drivers and device tree configuration. The PYNQ-Z2 now has a fully functional HDMI output controlled by Linux!

## **7. Next Step**

We have video. Now let's add the keyboard, mouse, and other peripherals to make it a real computer.

**[Go to Step 9: Peripheral Integration](loopback_step9.md)**