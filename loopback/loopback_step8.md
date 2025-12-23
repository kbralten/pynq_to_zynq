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

### **Part A: Create Custom Kernel Module (xlnx_dummy_connector)**

The Xilinx PL Display driver requires a DRM connector/bridge to report display modes. Since we have a simple HDMI output without DDC/EDID, we create a dummy connector that reports a fixed 720p60 mode.

#### **1. Create Module Directory Structure**

```bash
cd ~/loopback_system/loopback_os
mkdir -p project-spec/meta-user/recipes-modules/xlnx-dummy-connector/files
cd project-spec/meta-user/recipes-modules/xlnx-dummy-connector/files
```

#### **2. Create the Module Source Code**

Create `xlnx_dummy_connector.c`:

```c
// SPDX-License-Identifier: GPL-2.0
---

### **Part C: Device Tree Configuration**

The device tree describes the hardware to the Linux kernel. This is critical for driver initialization.

#### **1. Open Device Tree File**

```bash
cd ~/loopback_system/loopback_os
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
	.reset = drm_atomic_helper_connector_reset,
	.atomic_duplicate_state = drm_atomic_helper_connector_duplicate_state,
	.atomic_destroy_state = drm_atomic_helper_connector_destroy_state,
};

/* Encoder functions */
static const struct drm_encoder_funcs xlnx_dummy_encoder_funcs = {
	.destroy = drm_encoder_cleanup,
};

/* Component binding */
static int xlnx_dummy_bind(struct device *dev, struct device *master, void *data)
{
	struct xlnx_dummy *dummy = dev_get_drvdata(dev);
	struct drm_device *drm = data;
	struct drm_encoder *encoder = &dummy->encoder;
	struct drm_connector *connector = &dummy->connector;
	int ret;

	dummy->drm = drm;

	encoder->possible_crtcs = 1;
	ret = drm_simple_encoder_init(drm, encoder, DRM_MODE_ENCODER_NONE);
	if (ret) {
		dev_err(dev, "Failed to initialize encoder: %d\n", ret);
		return ret;
	}

	connector->polled = 0;
	ret = drm_connector_init(drm, connector, &xlnx_dummy_connector_funcs,
				 DRM_MODE_CONNECTOR_HDMIA);
	if (ret) {
		dev_err(dev, "Failed to initialize connector: %d\n", ret);
		drm_encoder_cleanup(encoder);
		return ret;
	}

	drm_connector_helper_add(connector, &xlnx_dummy_connector_helper_funcs);

	ret = drm_connector_attach_encoder(connector, encoder);
	if (ret) {
		dev_err(dev, "Failed to attach connector: %d\n", ret);
		drm_connector_cleanup(connector);
		drm_encoder_cleanup(encoder);
		return ret;
	}

	dev_info(dev, "Dummy encoder/connector bound successfully\n");
	return 0;
}

static void xlnx_dummy_unbind(struct device *dev, struct device *master, void *data)
{
	struct xlnx_dummy *dummy = dev_get_drvdata(dev);

	drm_connector_cleanup(&dummy->connector);
	drm_encoder_cleanup(&dummy->encoder);
}

static const struct component_ops xlnx_dummy_component_ops = {
	.bind = xlnx_dummy_bind,
	.unbind = xlnx_dummy_unbind,
};

/* Platform driver */
static int xlnx_dummy_probe(struct platform_device *pdev)
{
	struct xlnx_dummy *dummy;

	dummy = devm_kzalloc(&pdev->dev, sizeof(*dummy), GFP_KERNEL);
	if (!dummy)
		return -ENOMEM;

	platform_set_drvdata(pdev, dummy);

	return component_add(&pdev->dev, &xlnx_dummy_component_ops);
}

static void xlnx_dummy_remove(struct platform_device *pdev)
{
	component_del(&pdev->dev, &xlnx_dummy_component_ops);
}

static const struct of_device_id xlnx_dummy_of_match[] = {
	{ .compatible = "xlnx,dummy-connector" },
	{ /* sentinel */ }
};
MODULE_DEVICE_TABLE(of, xlnx_dummy_of_match);

static struct platform_driver xlnx_dummy_driver = {
	.probe = xlnx_dummy_probe,
	.remove = xlnx_dummy_remove,
	.driver = {
		.name = DRIVER_NAME,
		.of_match_table = xlnx_dummy_of_match,
	},
};

module_platform_driver(xlnx_dummy_driver);

MODULE_AUTHOR("Custom");
MODULE_DESCRIPTION("Xilinx DRM Dummy Encoder/Connector");
MODULE_LICENSE("GPL");
```

#### **3. Create Module Makefile**

Create `Makefile`:

```makefile
obj-m := xlnx_dummy_connector.o

SRC := $(shell pwd)

all:
	$(MAKE) -C $(KDIR) M=$(SRC) modules

modules_install:
	$(MAKE) -C $(KDIR) M=$(SRC) modules_install

clean:
	rm -f *.o *~ core .depend .*.cmd *.ko *.mod.c
	rm -f Module.markers Module.symvers modules.order
	rm -rf .tmp_versions Modules.symvers
```

#### **4. Create BitBake Recipe**

Go back to the recipe directory:

```bash
cd ~/loopback_system/loopback_os/project-spec/meta-user/recipes-modules/xlnx-dummy-connector
```

Create `xlnx-dummy-connector_1.0.bb`:

```bitbake
SUMMARY = "Xilinx DRM Dummy Connector Kernel Module"
DESCRIPTION = "A simple DRM encoder/connector module for xlnx-drm framework"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6"

inherit module

SRC_URI = "file://xlnx_dummy_connector.c \
           file://Makefile \
          "

S = "${WORKDIR}"

# Extra flags
EXTRA_OEMAKE += "KDIR=${STAGING_KERNEL_DIR}"
```

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

### **Part B: Kernel Configuration**

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

### **Part D: Build the System**

Now we compile the kernel, modules, device tree, and create boot images.

#### **1. Clean Previous Builds (Optional)**

If you've made significant changes:

```bash
cd ~/loopback_system/loopback_os

# Clean kernel
petalinux-build -c kernel -x cleansstate

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

### **Next Steps**

**Step 9: Desktop Environment (Optional)**

Now that the display hardware is functional, you can install a graphical desktop:

```bash
# Install X11 and XFCE desktop
apt install -y xserver-xorg-core xserver-xorg-video-fbdev
apt install -y xfce4 xfce4-terminal

# Or install a lightweight window manager
apt install -y matchbox-window-manager xterm
```

See [GUI.md](../GUI.md) for detailed desktop setup instructions.

**Alternative Applications:**
- **Embedded GUI:** Use Qt5/GTK with DRM backend
- **Custom graphics:** Direct DRM/KMS API programming
- **Video playback:** ffmpeg with DRM output
- **Framebuffer graphics:** Direct `/dev/fb0` access

---

## **6. Additional Resources**

- **Main README:** [../README.md](../README.md) - Complete system documentation
- **GUI Setup:** [../GUI.md](../GUI.md) - Desktop environment installation
- **Xilinx DRM Wiki:** https://xilinx-wiki.atlassian.net/wiki/spaces/A/pages/18842546/Linux+DRM+KMS
- **DRM Programming:** https://dri.freedesktop.org/docs/drm/
- **PetaLinux Reference:** UG1144 - PetaLinux Tools Reference Guide
- **Device Tree Spec:** https://www.devicetree.org/

---

**🎉 Congratulations!** You've successfully created a complete video output system from hardware to software, including custom kernel drivers and device tree configuration. The PYNQ-Z2 now has a fully functional HDMI output controlled by Linux!


```bash
# Check framebuffer
ls -l /dev/fb*

# Expected output:
# /dev/fb0      (framebuffer device)
```

```bash
# Check framebuffer info
cat /sys/class/graphics/fb0/virtual_size
# Expected: 1280,720

cat /sys/class/graphics/fb0/bits_per_pixel
# Expected: 32
```

#### **3. Test with modetest**

This utility directly interfaces with the DRM driver:

```bash
# List connectors and modes
modetest -M xlnx -c

# Expected output:
# Connector 0: type HDMI-A-1, status: connected
#   Modes:
#     1280x720 60 74250 1280 1390 1430 1650 720 725 730 750 9000 flags: phsync, pvsync; type: preferred, driver
```

**If you see the above, your driver is working! 🎉**

```bash
# Display test pattern (color bars)
# Note: Get connector ID and CRTC ID from previous command
modetest -M xlnx -s <connector_id>@<crtc_id>:1280x720

# Example (adjust IDs based on your output):
modetest -M xlnx -s 31@30:1280x720
```

**Expected Result:** HDMI monitor displays colorful test pattern with color bars

#### **4. Test Framebuffer Directly**

```bash
# Fill screen with solid red
dd if=/dev/zero bs=4 count=$((1280*720)) | \
    tr '\000' '\377' | dd of=/dev/fb0 bs=4 count=$((1280*720))

# Clear screen (black)
dd if=/dev/zero of=/dev/fb0 bs=$((1280*720*4)) count=1
```

**Expected Result:** Screen turns red, then black

#### **5. Display Test Image**

If you installed `fbi`:

```bash
# Display an image file
fbi -d /dev/fb0 -T 1 /path/to/image.png
```

#### **6. Check System Status**

```bash
# Verify kernel modules loaded
lsmod | grep -E "xlnx|drm"

# Expected modules:
# xlnx_dummy_connector
# drm
# drm_kms_helper
# (possibly others)
```

```bash
# Check CMA memory allocation
cat /proc/meminfo | grep Cma

# Expected:
# CmaTotal:       16384 kB
# CmaFree:        ~15000 kB (varies)
```

```bash
# Check interrupts (VDMA should show activity)
cat /proc/interrupts | grep vdma
```
# 4. Build complete system (rootfs, etc.)
petalinux-build
```

**Expected Build Time:** 20-60 minutes depending on system (first full build can take longer)

**Monitor Progress:**
- Kernel build: ~10-20 minutes
- Module build: ~1-2 minutes
- Device tree: ~1 minute
- Full system: additional 10-30 minutes for rootfs

#### **3. Package Boot Image**

Create BOOT.BIN with FSBL, bitstream, and U-Boot:

```bash
petalinux-package --boot \
    --fsbl images/linux/zynq_fsbl.elf \
    --fpga images/linux/system.bit \
    --u-boot images/linux/u-boot.elf \
    --force
```

**Output:** `images/linux/BOOT.BIN`

#### **4. Verify Build Artifacts**

Check that all necessary files exist:

```bash
ls -lh images/linux/
```

Expected files:
- ✅ `BOOT.BIN` (First-stage boot loader + bitstream)
- ✅ `image.ub` (FIT image: kernel + device tree + optional initramfs)
- ✅ `boot.scr` (U-Boot boot script)
- ✅ `system.dtb` (Device tree blob)
- ✅ `rootfs.tar.gz` or `rootfs.ext4` (Root filesystem)

#### **5. Check Module Installation**

Verify the module is included in rootfs:

```bash
# Extract and check (if using tar.gz)
tar -tzf images/linux/rootfs.tar.gz | grep xlnx_dummy_connector

# Should show:
# ./lib/modules/6.12.10-xilinx-.../updates/xlnx_dummy_connector.ko
```

Or if using ext4:

```bash
mkdir -p /tmp/rootfs_check
sudo mount -o loop images/linux/rootfs.ext4 /tmp/rootfs_check
ls /tmp/rootfs_check/lib/modules/*/updates/xlnx_dummy_connector.ko
sudo umount /tmp/rootfs_check
```

---

### **Part E: Deploy to SD Card**

Update the SD card with new boot files and kernel.

#### **Option 1: Update Boot Partition Only (Preserves Debian)**

If you have an existing Debian installation and want to keep it:

```bash
# Mount boot partition
sudo mount /dev/sdX1 /mnt/boot

# Copy new files
sudo cp images/linux/BOOT.BIN /mnt/boot/
sudo cp images/linux/image.ub /mnt/boot/
sudo cp images/linux/boot.scr /mnt/boot/

# Unmount
sudo umount /mnt/boot
```

**Note:** Replace `/dev/sdX1` with your actual SD card boot partition

#### **Option 2: Full SD Card Image**

For a complete fresh install:

```bash
# Create WIC image (includes everything)
petalinux-package --wic --images-dir images/linux/ \
    --bootfiles "BOOT.BIN boot.scr image.ub"

# Flash to SD card
sudo dd if=images/linux/petalinux-sdimage.wic of=/dev/sdX bs=4M status=progress conv=fsync

# Wait for completion
sync
```

**⚠️ Warning:** This erases the entire SD card!

#### **Option 3: Update Kernel in Existing Debian**

If you only changed kernel/modules/device tree:

```bash
# Mount rootfs
sudo mount /dev/sdX2 /mnt/rootfs

# Update kernel modules
sudo tar -xzf images/linux/rootfs.tar.gz -C /mnt/rootfs ./lib/modules

# Update device tree (if needed)
sudo cp images/linux/system.dtb /mnt/rootfs/boot/

# Unmount
sudo umount /mnt/rootfs
```

---

### **Part F: Configure Debian (On Target)**

After booting with the new kernel, perform final configuration on the target system.

#### **1. Boot the System**

1. Insert SD card into PYNQ-Z2
2. Connect HDMI monitor
3. Connect serial console (115200 baud)
4. Power on

**Watch Boot Messages:**
- Check for "xlnx-pl-disp" driver initialization
- Look for "drm" device registration
- Verify no critical errors

#### **2. Login and Check System**

```bash
# Login via serial console
# Username: root (or your configured user)
# Password: (your password, or none if debug-tweaks enabled)

# Check kernel version
uname -a
# Should show: 6.12.10-xilinx-... or similar

# Check module loaded
lsmod | grep xlnx_dummy
# Should show: xlnx_dummy_connector ...
```

#### **3. Install Required Packages**

Update package database and install DRM utilities:

```bash
# Set correct date (important for apt)
date -s "2025-12-23 12:00:00"

# Update package list
apt update

# Install DRM/video utilities
apt install -y libdrm-tests mesa-utils

# Install framebuffer utilities (optional)
apt install -y fbi fbset

# Install development tools (optional)
apt install -y build-essential git
```

#### **4. Check Locale (If Needed)**

If you see locale warnings:

```bash
apt install -y locales
dpkg-reconfigure locales
# Select: en_US.UTF-8
```
           type \= "a"; /\* Type A connector \*/

           port {  
               hdmi\_connector\_in: endpoint {  
                   remote-endpoint \= \<\&dvi\_encoder\_out\>;  
               };  
           };  
       };

       /\* 2\. Define the Digilent RGB2DVI as a "Simple Encoder" \*/  
       dvi\_encoder: encoder {  
           compatible \= "linux,simple-encoder";

           ports {  
               \#address-cells \= \<1\>;  
               \#size-cells \= \<0\>;

               port@0 {  
                   reg \= \<0\>;  
                   dvi\_encoder\_in: endpoint {  
                       remote-endpoint \= \<\&xilinx\_drm\_out\>;  
                   };  
               };

               port@1 {  
                   reg \= \<1\>;  
                   dvi\_encoder\_out: endpoint {  
                       remote-endpoint \= \<\&hdmi\_connector\_in\>;  
                   };  
               };  
           };  
       };  
   };

   /\* 3\. Link the VDMA and VTC to the DRM Subsystem \*/  
   \&axi\_vdma\_0 {  
       dma-ranges \= \<0x00000000 0x00000000 0x40000000\>; // Allow DMA to access first 1GB RAM  
   };

   /\* 4\. Define the Xilinx DRM PL Display Subsystem \*/  
   \&amba {  
       xilinx\_drm: xilinx\_drm {  
           compatible \= "xlnx,pl-disp";  
           dmas \= \<\&axi\_vdma\_0 0\>; /\* Link to your VDMA IP \*/  
           dma-names \= "dma";

           ports {  
               \#address-cells \= \<1\>;  
               \#size-cells \= \<0\>;

               port@0 {  
                   reg \= \<0\>;  
                   xilinx\_drm\_out: endpoint {  
                       remote-endpoint \= \<\&dvi\_encoder\_in\>;  
                       xlnx,video-format \= \<24\>; /\* RGB888 \*/  
                       xlnx,video-width \= \<8\>;  
                   };  
               };  
           };  
       };  
   };

   /\* 5\. Ensure VTC is claimed by the driver \*/  
   \&v\_tc\_0 {  
       compatible \= "xlnx,v-tc-5.01.a";  
   };

   * **Critical Warning:** Ensure the names \&axi\_vdma\_0 and \&v\_tc\_0 match exactly what is in your components/plnx\_workspace/device-tree/device-tree/pl.dtsi. If Vivado named them axi\_vdma\_1, you must update this file.

### **Part C: Rebuild and Deploy**

We need to update the Kernel (modules) and Device Tree (system.dtb).

1. **Build:**  
   petalinux-build \-c kernel  
   petalinux-build \-c device-tree

2. Package Boot Image:  
   (Because we changed the hardware in Step 7, we need a new BOOT.BIN with the new bitstream).  
   petalinux-package \--boot \--fsbl images/linux/zynq\_fsbl.elf \--fpga images/linux/system.bit \--u-boot \--force

3. **Update SD Card:**  
   * Copy BOOT.BIN, image.ub, and boot.scr to the FAT32 partition.  
   * **Note:** You do NOT need to wipe the Debian partition. The new kernel will seamlessly load the old Debian filesystem, but now with working video drivers.

### **Part D: Validation (The moment of truth)**

1. **Boot the Board:** Connect an HDMI monitor.  
2. **Check Kernel Logs:**  
   dmesg | grep drm

   * *Success:* You should see \[drm\] Initialized xlnx\_pl\_disp and \[drm\] Found connector HDMI-A-1.  
3. **Check Devices:**  
   ls /dev/dri/

   * *Success:* You should see card0 and controlD64.  
4. Run Modetest:  
   This tool talks directly to the kernel driver, bypassing X11.  
   \# Verify connector status  
   modetest \-M xlnx \-c

   \# Run a test pattern (Connector ID 31, 720p60)  
   \# Note: Replace '31' with the ID found in the previous command  
   modetest \-M xlnx \-s 31@30:1280x720-60

   * *Visual:* You should see a color bar pattern on your monitor\!

## **4\. Troubleshooting**

**Issue: dmesg says "deferred probe pending"**

* **Cause:** The VDMA or VTC driver is waiting for a clock that hasn't started.  
* **Fix:** Ensure your fclk\_clk1 (100MHz) is enabled in the Zynq PS settings in Vivado.

**Issue: Monitor shows "No Signal" but modetest runs**

* **Cause:** Physical timing failure.  
* **Check:** Did your "Heartbeat LED" (Step 7 Part F) light up? If not, the Clock Wizard isn't locked, and the HDMI PHY is dead.

## **5. Recap**

You have done something very few developers accomplish: you built a custom video card from scratch.

* **Vivado:** Wired the pixels.
* **Device Tree:** Wired the drivers.
* **Linux:** Is now rendering graphics to a piece of silicon *you* designed.

## **7. Next Step**

We have video. Now let's add the keyboard, mouse, and other peripherals to make it a real computer.

**[Go to Step 9: Peripheral Integration](loopback_step9.md)**