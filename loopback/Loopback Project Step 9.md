# **Loopback Project Step 9: Peripheral Integration (USB, SPI, I2C, and Activity LED)**

## **1. The Goal**

Enable the standard connectivity and feedback interfaces on the PYNQ-Z2 board:

1. **USB Host:** Support keyboards, mice, storage devices, and other USB peripherals
2. **SPI Interface:** Access SPI bus for sensors and external devices  
3. **I2C Interface:** Access I2C bus for sensors and external devices
4. **Activity LED:** Create a visual indicator that blinks with system activity

By the end of this step, you will be able to:
- ✅ Connect USB keyboard and mouse for input
- ✅ Plug in USB flash drives and mount them
- ✅ Use USB serial adapters (FTDI, CP210x, etc.)
- ✅ Access SPI devices via `/dev/spidev`
- ✅ Access I2C devices via `/dev/i2c-*`
- ✅ See LED blink with CPU/disk activity

### USB Architecture

```
┌─────────────────────────────────────────────────┐
│          Linux USB Subsystem                    │
│  (Storage, HID, Serial, Network drivers)        │
├─────────────────────────────────────────────────┤
│     ChipIdea USB Host Controller Driver         │
│          (ci_hdrc / USB EHCI)                   │
├─────────────────────────────────────────────────┤
│         ULPI PHY Interface                      │
│     (USB Low Pin Interface Protocol)            │
├─────────────────────────────────────────────────┤
│        TUSB1210 USB PHY (Hardware)              │
│         (MIO 28-39 + GPIO 46 reset)             │
├─────────────────────────────────────────────────┤
│          USB Type-A Connector                   │
└─────────────────────────────────────────────────┘
```

**Key Components:**
- **Zynq PS USB Controller:** Built-in ChipIdea USB controller
- **TUSB1210 PHY:** External USB PHY chip on PYNQ-Z2
- **ULPI Interface:** MIO pins 28-39 for USB data
- **PHY Reset:** MIO GPIO pin 46 for PHY reset control

*Note: This step focuses on USB host support. Display functionality from Steps 7-8 is not modified. I2C/SPI peripheral support may be covered in future steps but is not included here.*

## **2. Prerequisites**

Before starting:**

### **Overview of Peripherals**

| Peripheral | Type | Location | Configuration Needed |
|------------|------|----------|---------------------|
| USB | PS | MIO 28-39 + GPIO 46 | Verify in PS config (already done) |
| SPI | PS | EMIO → PL pins | Verify PS config + add constraints |
| I2C | PS | EMIO → PL pins | Verify PS config + add constraints |
| Activity LED | PL | AXI GPIO → LED pin | **Add new IP + constraints** |

**Important Notes:**
- **USB:** Pure PS peripheral, uses MIO pins (no PL routing)
- **SPI/I2C:** PS controllers using EMIO (routed through PL fabric to external pins)
- **Activity LED:** Requires new AXI GPIO IP block in PL

### **Part A: Verify and Configure Zynq PSnly peripheral)
* ✅ **Understanding:** USB is a PS (Processing System) feature, no FPGA changes needed

## **3. Hardware Configuration (Optional)**

**Important:** USB on the Zynq-7000 is a **Processing System (PS) peripheral**, not a Programmable Logic (PL/FPGA) feature. The USB controller, PHY interface (ULPI), and MIO pins are all part of the PS silicon.

### **Vivado Configuration (If Modifying Hardware)**

If you need to verify or modify the PS configuration in Vivado:

**1. Open Block Design:**
```bash
# In Vivado
Open Block Design → system_design.bd
```

**2. Edit Zynq PS Block:**
- Double-click **ZYNQ7 Processing System** block
- Navigate to **Peripheral I/O Pins** section

**3. Verify USB Configuration:**
- **USB 0:**
  - ✅ **Enable USB 0**
  - **USB 0 IO:** MIO 28 .. 39
  - This should already be configured if using PYNQ-Z2 preset
  
**4. Verify GPIO Configuration:**
- **GPIO MIO:**
  - ✅ **Enable** (for PHY reset on MIO 46)
  - Verify MIO pin 46 is available (not conflicting with other peripherals)

**5. Check Clock Configuration:**
- **Clock Configuration → PL Fabric Clocks:**
  - FCLK_CLK0: 100 MHz (already configured from previous steps)
  - No additional clocks needed for USB

**6. Enable SPI and I2C via EMIO:**

- Navigate to **MIO Configuration** section
- **SPI 0:**
  - ✅ **Enable SPI 0**
  - **SPI 0 IO:** Select **EMIO** (routes through PL fabric)
  - This makes SPI signals available as ports on the Zynq PS block
  
- **I2C 0:**
  - ✅ **Enable I2C 0**  
  - **I2C 0 IO:** Select **EMIO** (routes through PL fabric)
  - This makes I2C signals available as ports on the Zynq PS block

**7. Apply Changes:**
- Click **OK** to close PS configuration
- The Zynq block should now show new ports: `IIC_0` and `SPI_0`

---

### **Part B: Add AXI GPIO for Activity LED**

Create a GPIO controller in the PL for the activity LED.

**1. Add AXI GPIO IP:**

In the block design:
- Click **+** button to add IP
- Search for: **AXI GPIO**
- Double-click to add

**2. Configure AXI GPIO:**

Double-click the AXI GPIO block:
- **Board Interface:** None (custom configuration)
- **IP Configuration:**
  - **GPIO Width:** 4 (for 4 LEDs on PYNQ-Z2)
  - ✅ **All Outputs** (LEDs are outputs only)
  - **GPIO 2:** Disable (not needed)
- Click **OK**

**3. Run Connection Automation:**

- Click **Run Connection Automation** at top of block design
- Select **axi_gpio_0/S_AXI**
- Master: `/processing_system7_0/M_AXI_GP0`
- Clock: Auto
- Click **OK**

This connects the GPIO control registers to the PS via AXI-Lite.

**4. Make GPIO External:**

- Locate the `gpio_io_o` port on the AXI GPIO block (4-bit output)
- Right-click → **Make External**
- Rename the external port to `leds_4bits`

**5. Make SPI and I2C External:**

If not already done:
- Locate `IIC_0` on Zynq PS block → Right-click → **Make External** → Rename to `iic_0`
- Locate `SPI_0` on Zynq PS block → Right-click → **Make External** → Rename to `spi_0`

---

### **Part C: Pin Constraints**

Map the abstract ports to physical PYNQ-Z2 pins.

**1. Open Constraints File:**

Open your existing constraints file (e.g., `hdmi_pinout.xdc`) or create a new one.

**2. Add LED Constraints:**

Add the following to constrain the 4 LEDs:

```tcl
##################################################
# PYNQ-Z2 LED Constraints
##################################################

# LED 0 (LD0) - Red/Green bicolor LED, Red component
set_property -dict {PACKAGE_PIN R14 IOSTANDARD LVCMOS33} [get_ports {leds_4bits[0]}]

# LED 1 (LD1) - Red/Green bicolor LED, Red component  
set_property -dict {PACKAGE_PIN P14 IOSTANDARD LVCMOS33} [get_ports {leds_4bits[1]}]

# LED 2 (LD2) - Red/Green bicolor LED, Red component
set_property -dict {PACKAGE_PIN N16 IOSTANDARD LVCMOS33} [get_ports {leds_4bits[2]}]

# LED 3 (LD3) - Red/Green bicolor LED, Red component
set_property -dict {PACKAGE_PIN M14 IOSTANDARD LVCMOS33} [get_ports {leds_4bits[3]}]
```

**Note:** PYNQ-Z2 has 4 bicolor LEDs (red/green). We're using the red component here. Green components are on different pins if you want to expand later.

**3. Add SPI Constraints (Arduino Header):**

SPI is typically routed to Arduino-compatible pins:

```tcl
##################################################
# SPI Interface (Arduino Header)
##################################################

# SPI Clock - Arduino D13
set_property -dict {PACKAGE_PIN W14 IOSTANDARD LVCMOS33} [get_ports {spi_0_sck_io}]

# SPI MISO - Arduino D12
set_property -dict {PACKAGE_PIN Y14 IOSTANDARD LVCMOS33} [get_ports {spi_0_io0_io}]

# SPI MOSI - Arduino D11  
set_property -dict {PACKAGE_PIN T15 IOSTANDARD LVCMOS33} [get_ports {spi_0_io1_io}]

# SPI SS (Chip Select) - Arduino D10
set_property -dict {PACKAGE_PIN T10 IOSTANDARD LVCMOS33} [get_ports {spi_0_ss_io}]
```

**4. Add I2C Constraints (Arduino Header):**

I2C is typically routed to Arduino-compatible pins:

```tcl
##################################################
# I2C Interface (Arduino Header)
##################################################

# I2C SCL (Clock) - Arduino A5
set_property -dict {PACKAGE_PIN Y11 IOSTANDARD LVCMOS33} [get_ports {iic_0_scl_io}]

# I2C SDA (Data) - Arduino A4
set_property -dict {PACKAGE_PIN Y12 IOSTANDARD LVCMOS33} [get_ports {iic_0_sda_io}]
```

**Important:** Verify these pin assignments match the PYNQ-Z2 schematic. Arduino header pinout may vary by board revision.

---

### **Part D: Validate and Generate**

**1. Validate Block Design:**

- Click **Validate Design** (F6)
- Fix any errors
- Warnings about unconnected optional ports are usually OK

**2. Assign Addresses:**

- Open **Address Editor** tab
- Verify `axi_gpio_0` has an assigned address (e.g., 0x4120_0000)
- Note this address for device tree later

**3. Generate Bitstream:**

```bash
# In Vivado
Generate Bitstream
```

**Expected Duration:** 15-30 minutes

**4. Export Hardware:**

```bash
File → Export → Export Hardware (Include Bitstream)
# Export to: project-spec/hw-description/system.xsa
```

---

### **Part E: Update PetaLinux Hardware Description**

If you regenerated the hardware:

```bash
cd ~/loopback_system/loopback_os
petalinux-config --get-hw-description=project-spec/hw-description/

# Just save and exit - this updates the device tree templates
```

## **4\. Software Configuration (PetaLinux)**

### **Part E: Update Hardware Definition**

1. **Copy XSA:** Move the new .xsa to your Linux build machine.  
2. **Update Config:**  
   cd \~/loopback\_system/loopback\_os  
   pet. Kernel Configuration**

Enable USB host support and all necessary device drivers.

### **Part A: Create USB Configuration Fragment**

Create a comprehensive kernel configuration file for USB support.

**1. Create the Configuration File:**

```bash
cd ~/loopback_system/loopback_os
vi project-spec/meta-user/recipes-kernel/linux/linux-xlnx/usb_input.cfg
```

**2. Add Complete USB Configuration:**

Copy the following configuration (this matches the actual tested configuration):

```properties
# USB Host Controller Support for Zynq-7000
CONFIG_USB_SUPPORT=y
CONFIG_USB=y
CONFIG_USB_ANNOUNCE_NEW_DEVICES=y
---

## **5. Device Tree Configuration**

Configure the USB PHY and controller in the device tree.

### **Part A: Edit Device Tree File**

```bash
cd ~/loopback_system/loopback_os
vi project-spec/meta-user/recipes-bsp/device-tree/files/system-user.dtsi
```

### **Part B: Add USB Configuration**

Add the following USB configuration to your device tree. This should be in addition to any video configuration from Step 8.

**Complete USB Device Tree Configuration:**

```dts
/include/ "system-conf.dtsi"

/ {
    chosen {
        bootargs = "console=ttyPS0,115200 root=/dev/mmcblk0p2 rw rootwait earlyprintk clk_ignore_unused loglevel=8";
    };

    /* ... video configuration from Step 8 here ... */
};

/* 8. Add USB PHY with TUSB1210 reset GPIO on MIO 46 */
/ {
    usb_phy0: phy0 {
        compatible = "ulpi-phy";
        #phy-cells = <0>;
        reg = <0xe0002000 0x1000>;
        view-port = <0x170>;
        reset-gpios = <&gpio0 46 1>;  /* MIO 46, active-low */
        drv-vbus;
    };
};

/* 9. Configure USB0 Controller */
&usb0 {
    status = "okay";
    dr_mode = "host";
    usb-phy = <&usb_phy0>;
};

/* 10. Configure SPI0 for userspace access */
&spi0 {
    status = "okay";
    is-decoded-cs = <0>;
    num-cs = <1>;
    
    spidev@0 {
        compatible = "rohm,dh2228fv";  /* Generic spidev compatible string */
        reg = <0>;  /* Chip select 0 */
        spi-max-frequency = <50000000>;  /* 50 MHz max */
    };
};

/* 11. Configure I2C0 for userspace access */
&iic0 {
    status = "okay";
    clock-frequency = <100000>;  /* 100 kHz standard mode */
    
    /* I2C devices can be added here when connected */
    /* Example:
    eeprom@50 {
        compatible = "atmel,24c02";
        reg = <0x50>;
    };
    */
};

/* 12. Configure GPIO for LEDs with Activity Triggers */
/ {
    leds {
        compatible = "gpio-leds";
        
        led0 {
            label = "pynq:red:ld0";
            gpios = <&axi_gpio_0 0 0>;  /* GPIO 0, active high */
            linux,default-trigger = "heartbeat";  /* CPU heartbeat pattern */
            default-state = "off";
        };
        
        led1 {
            label = "pynq:red:ld1";
            gpios = <&axi_gpio_0 1 0>;  /* GPIO 1, active high */
            linux,default-trigger = "mmc0";  /* SD card activity */
            default-state = "off";
        };
        
        led2 {
            label = "pynq:red:ld2";
            gpios = <&axi_gpio_0 2 0>;  /* GPIO 2, active high */
            linux,default-trigger = "cpu0";  /* CPU0 activity */
            default-state = "off";
        };
        
        led3 {
            label = "pynq:red:ld3";
            gpios = <&axi_gpio_0 3 0>;  /* GPIO 3, active high */
            linux,default-trigger = "none";  /* Manual control */
            default-state = "on";  /* Always on for power indicator */
        };
    };
};
```

**Key Device Tree Elements:**

**USB Configuration:**

1. **USB PHY Node (`usb_phy0`):**
   - `compatible = "ulpi-phy"`: ULPI PHY driver
   - `reg = <0xe0002000 0x1000>`: USB0 ULPI viewport register address
   - `view-port = <0x170>`: ULPI viewport register offset
   - `reset-gpios = <&gpio0 46 1>`: MIO pin 46 for PHY reset (active-low)
   - `drv-vbus`: Enable VBUS power control

2. **USB Controller (`&usb0`):**
   - `status = "okay"`: Enable the controller
   - `dr_mode = "host"`: Configure as USB host (not device/OTG)
   - `usb-phy = <&usb_phy0>`: Link to the PHY node

**SPI Configuration:**

3. **SPI Controller (`&spi0`):**
   - `status = "okay"`: Enable SPI0
   - `spidev@0`: Creates `/dev/spidev0.0` for userspace access
   - `compatible = "rohm,dh2228fv"`: Generic spidev compatible string
   - `spi-max-frequency = <50000000>`: 50 MHz maximum

**I2C Configuration:**

4. **I2C Controller (`&iic0`):**
   - `status = "okay"`: Enable I2C0
   - `clock-frequency = <100000>`: 100 kHz standard mode
   - Creates `/dev/i2c-0` for userspace access
   - I2C devices can be added as child nodes

**LED Configuration:**

5. **GPIO LEDs:**
   - `compatible = "gpio-leds"`: Use Linux LED subsystem
   - Each LED has:
     - `gpios`: Reference to AXI GPIO pin
     - `linux,default-trigger`: Activity trigger type
     - `default-state`: Initial state at boot
   
   **Available Triggers:**
   - `heartbeat`: Rhythmic CPU heartbeat pattern
   - `mmc0`: Flashes on SD card activity
   - `cpu0`: Flashes on CPU0 activity  
   - `disk-activity`: Flashes on any disk I/O
   - `timer`: Configurable blink rate
   - `none`: Manual control via sysfs

**Important Notes:**

- **GPIO Reference:** 
  - `&gpio0` = PS GPIO controller (MIO pins)
  - `&axi_gpio_0` = PL GPIO controller (for LEDs)
- **Active-Low Reset:** The `1` flag indicates active-low (reset by pulling low)
- **ULPI Viewport:** 0xe0002000 is the USB0 controller base address in Zynq PS
- **VBUS Power:** `drv-vbus` enables 5V USB power output
- **SPI/I2C Names:** Zynq PS names I2C as `iic`, but Linux typically uses `i2c` in device nodes
- **LED Triggers:** Can be changed at runtime via `/sys/class/leds/*/trigger`

**3. Verify Configuration:**

Your complete `system-user.dtsi` should now include:
- Video configuration (from Step 8)
- USB PHY and controller configuration
- SPI configuration
- I2C configuration
- LED GPIO configuration

Example structure:

```dts
/include/ "system-conf.dtsi"

/ {
    chosen {
        bootargs = "...";
    };

    reserved-memory { /* Video CMA from Step 8 */ };
    
    /* Video nodes from Step 8 */
    hdmi_out: hdmi-output { ... };
    drm_pl_disp: drm-pl-disp-drv { ... };
    
    /* USB PHY node */
    usb_phy0: phy0 { ... };
    
    /* LED configuration */
    leds { ... };
};

/* Video VDMA and VTC from Step 8 */
&axi_vdma_0 { ... };
&v_tc_0 { ... };

/* USB Controller */
&usb0 { ... };

/* SPI Controller */
&spi0 { ... };

/* I2C Controller */
&iic0 { ... };
```

---

## **6. Build and Deploy**

Build the updated kernel and device tree, then deploy to the board.

### **Part A: Clean and Build**

```bash

## **7. Testing and Validation**

Boot the system and verify USB functionality.

### **Part A: Boot and Initial Checks**

**1. Boot the System:**
- Insert SD card into PYNQ-Z2
- Connect serial console (115200 baud)
- Connect USB keyboard/mouse to USB Type-A port
- Power on

**2. Check Kernel Messages:**

```bash
# Login via serial console
# Check USB initialization
dmesg | grep -i usb

# Expected output (example):
# ci_hdrc ci_hdrc.0: EHCI Host Controller
# ci_hdrc ci_hdrc.0: new USB bus registered, assigned bus 1
# hub 1-0:1.0: USB hub found
# usb 1-1: New USB device found, idVendor=XXXX, idProduct=XXXX
```

```bash
# Check PHY initialization
dmesg | grep -i phy

# Expected output:
# tusb1210 ci_hdrc.0:ulpi: USB PHY ... registered
```

### **Part B: USB Device Detection**

**1. Check USB Controller:**

```bash
# List USB buses and devices
lsusb

# Expected output (with devices connected):
# Bus 001 Device 001: ID 1d6b:0002 Linux Foundation 2.0 root hub
# Bus 001 Device 002: ID 046d:c077 Logitech, Inc. Mouse
# Bus 001 Device 003: ID 04d9:1603 Holtek Semiconductor Keyboard
```

**2. Check USB Devices in Detail:**

```bash
# Detailed device information
lsusb -v

# Tree view of USB topology
lsusb -t

# Expected output:
# /:  Bus 01.Port 1: Dev 1, Class=root_hub, Driver=ci_hdrc/1p, 480M
#     |__ Port 1: Dev 2, If 0, Class=Human Interface Device, Driver=usbhid, 12M
#     |__ Port 1: Dev 3, If 0, Class=Mass Storage, Driver=usb-storage, 480M
```

### **Part C: Test Input Devices**

**1. Check Input Device Nodes:**

```bash
# List input devices
ls -l /dev/input/

# Expected output:
# event0 -> keyboard
# event1 -> mouse
# mice -> mouse pointer device
```

**2. View Input Device Details:**

```bash
# List all input devices with names
cat /proc/bus/input/devices

# Expected output:
# I: Bus=0003 Vendor=04d9 Product=1603 Version=0111
# N: Name="USB Keyboard"
# H: Handlers=sysrq kbd event0
# ...
# I: Bus=0003 Vendor=046d Product=c077 Version=0111
# N: Name="Logitech USB Mouse"
# H: Handlers=mouse0 event1
```

**3. Test Keyboard Input:**

```bash
# Install evtest utility (if not already installed)
apt install -y evtest

# Test keyboard
evtest /dev/input/event0

# Press keys, should see:
# Event: time 1234567.123456, type 4 (EV_MSC), code 4 (MSC_SCAN), value 70004
# Event: time 1234567.123456, type 1 (EV_KEY), code 30 (KEY_A), value 1
```

**4. Test Mouse Input:**

```bash
# Test mouse
evtest /dev/input/event1

# Move mouse and click, should see events for:
# - REL_X, REL_Y (movement)
# - BTN_LEFT, BTN_RIGHT (clicks)
```

**5. Simple Keyboard Test:**

```bash
# Raw keyboard test (shows key events as hex)
cat /dev/input/event0 | hexdump -C

# Press keys, should see data streaming
# Press Ctrl+C to stop
```

### **Part D: Test USB Storage**

**1. Plug in USB Flash Drive:**

Watch kernel messages in real-time:

```bash
# In one terminal, monitor kernel messages
dmesg -w

# In another terminal or after plugging in drive:
dmesg | tail -30
```

Expected messages:

```
usb 1-1: new high-speed USB device number 2 using ci_hdrc
usb-storage 1-1:1.0: USB Mass Storage device detected
scsi host0: usb-storage 1-1:1.0
scsi 0:0:0:0: Direct-Access     SanDisk  Cruzer Blade     1.00 PQ: 0 ANSI: 6
sd 0:0:0:0: [sda] 30842880 512-byte logical blocks: (15.8 GB/14.7 GiB)
sd 0:0:0:0: [sda] Write Protect is off
sda: sda1
sd 0:0:0:0: [sda] Attached SCSI removable disk
```

**2. List Block Devices:**

```bash
# Check for new storage device
lsblk

# Expected output:
# NAME        MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
# mmcblk0     179:0    0 14.9G  0 disk
# ├─mmcblk0p1 179:1    0  512M  0 part /boot
# └─mmcblk0p2 179:2    0 14.4G  0 part /
# sda           8:0    1 14.7G  0 disk
# └─sda1        8:1    1 14.7G  0 part
```

**3. Mount USB Drive:**

```bash
# Create mount point
mkdir -p /mnt/usb

# Mount the drive (adjust partition if needed)
mount /dev/sda1 /mnt/usb

# List contents
ls -lh /mnt/usb

# Test read
cat /mnt/usb/somefile.txt

# Test write
echo "USB test from PYNQ-Z2" > /mnt/usb/test.txt
sync

# Unmount
umount /mnt/usb
```

**4. Test Transfer Speed:**

```bash
# Write test (1GB)
dd if=/dev/zero of=/mnt/usb/testfile bs=1M count=1024

# Expected speed: 10-30 MB/s for USB 2.0 High-Speed

# Read test
dd if=/mnt/usb/testfile of=/dev/null bs=1M

# Clean up
rm /mnt/usb/testfile
umount /mnt/usb
```

### **Part E: Test USB Serial Adapters**

**1. Plug in USB Serial Adapter (FTDI, CP210x, etc.):**

```bash
# Check device detection
dmesg | tail -20

# Expected for FTDI:
# ftdi_sio 1-1:1.0: FTDI USB Serial Device converter detected
# usb 1-1: FTDI USB Serial Device converter now attached to ttyUSB0

# Expected for CP210x:
# cp210x 1-1:1.0: cp210x converter detected
# usb 1-1: cp210x converter now attached to ttyUSB0
```

**2. List Serial Devices:**

```bash
ls -l /dev/ttyUSB*

# Expected output:
# /dev/ttyUSB0
```

**3. Test Serial Communication:**

```bash
# Install minicom or screen
apt install -y minicom

# Connect to serial device
minicom -D /dev/ttyUSB0 -b 115200

# Or using screen
screen /dev/ttyUSB0 115200
```

### **Part F: Check Loaded Modules**

```bash
# Check USB-related kernel modules
lsmod | grep usb

# Expected modules:
# usbhid                 - USB HID support
# usb_storage            - USB mass storage
# ci_hdrc                - ChipIdea USB controller
# phy_tusb1210           - TUSB1210 PHY driver
# ulpi                   - ULPI interface
```

```bash
# Check HID modules
lsmod | grep hid

# Expected modules:
# hid_generic            - Generic HID driver
# usbhid                 - USB HID
# hid                    - HID core
```

### **Part G: Check System Interrupts**

```bash
# View USB interrupt activity
cat /proc/interrupts | grep -i usb

# Should show interrupt counts for USB controller
```

---

## **8. Test SPI and I2C**

### **Part A: Verify SPI Device**

**1. Check SPI Device Node:**

```bash
# List SPI devices
ls -l /dev/spidev*

# Expected output:
# /dev/spidev0.0
```

**2. Check SPI Driver:**

```bash
# Check SPI driver loaded
lsmod | grep spi

# Check kernel messages
dmesg | grep -i spi

# Expected output:
# spi_master spi0: registered child spi0.0
```

**3. Test SPI Loopback (Hardware Required):**

To test SPI, you need to physically connect MISO to MOSI (pins D11 and D12 on Arduino header).

Install SPI tools:

```bash
apt install -y python3-spidev

# Or install spi-tools
apt install -y spi-tools
```

Python SPI test script:

```python
#!/usr/bin/env python3
import spidev
import time

# Open SPI bus 0, device 0
spi = spidev.SpiDev()
spi.open(0, 0)

# Configure SPI
spi.max_speed_hz = 1000000  # 1 MHz
spi.mode = 0

# Send and receive data (loopback test if MISO connected to MOSI)
tx_data = [0x12, 0x34, 0x56, 0x78]
rx_data = spi.xfer2(tx_data)

print(f"Sent:     {[hex(x) for x in tx_data]}")
print(f"Received: {[hex(x) for x in rx_data]}")

if tx_data == rx_data:
    print("✓ SPI loopback test PASSED")
else:
    print("✗ SPI loopback test FAILED (MISO/MOSI not connected?)")

spi.close()
```

Save as `test_spi.py` and run:

```bash
chmod +x test_spi.py
./test_spi.py
```

**4. Check SPI Kernel Interface:**

```bash
# View SPI bus information
cat /sys/class/spi_master/spi0/uevent

# View SPI device information
cat /sys/bus/spi/devices/spi0.0/uevent
```

### **Part B: Verify I2C Device**

**1. Check I2C Device Node:**

```bash
# List I2C devices
ls -l /dev/i2c*

# Expected output:
# /dev/i2c-0
```

**2. Check I2C Driver:**

```bash
# Check I2C driver loaded
lsmod | grep i2c

# Check kernel messages
dmesg | grep -i i2c

# Expected output:
# i2c i2c-0: Xilinx I2C at 0xe0004000 mapped to 0x...
```

**3. Install I2C Tools:**

```bash
apt install -y i2c-tools
```

**4. Detect I2C Devices:**

```bash
# Scan I2C bus 0 for devices
i2cdetect -y 0

# Expected output (if no devices connected):
#      0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
# 00:          -- -- -- -- -- -- -- -- -- -- -- -- -- 
# 10: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
# 20: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
# 30: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
# 40: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
# 50: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
# 60: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
# 70: -- -- -- -- -- -- -- --
```

If devices are connected, their addresses will show as numbers instead of `--`.

**5. Test I2C Read/Write (with device):**

Example: Reading from an I2C EEPROM at address 0x50:

```bash
# Read 16 bytes starting from address 0x00
i2cdump -y 0 0x50 b

# Write a byte to address 0x00
i2cset -y 0 0x50 0x00 0x42

# Read back the byte
i2cget -y 0 0x50 0x00
```

**6. Python I2C Test (if device connected):**

```python
#!/usr/bin/env python3
import smbus
import time

# Open I2C bus 0
bus = smbus.SMBus(0)

# Example: Read from device at address 0x50
device_addr = 0x50

try:
    # Read a byte from register 0x00
    data = bus.read_byte_data(device_addr, 0x00)
    print(f"Read from 0x{device_addr:02x}: 0x{data:02x}")
except Exception as e:
    print(f"Error: {e}")
    print("No device at address 0x50 (this is normal if no I2C device connected)")
finally:
    bus.close()
```

---

## **9. Test Activity LEDs**

### **Part A: Check LED Subsystem**

**1. List LEDs:**

```bash
# List all LEDs
ls /sys/class/leds/

# Expected output:
# pynq:red:ld0
# pynq:red:ld1
# pynq:red:ld2
# pynq:red:ld3
```

**2. Check LED Triggers:**

```bash
# View available triggers for LD0
cat /sys/class/leds/pynq:red:ld0/trigger

# Expected output (current trigger in brackets):
# none cpu0 cpu1 [heartbeat] timer oneshot disk-activity mmc0 mmc1 rfkill-any rfkill-none
```

**3. Check Current State:**

```bash
# Check if LED is on or off
cat /sys/class/leds/pynq:red:ld0/brightness

# 0 = off, 255 = on (full brightness)
```

### **Part B: Observe Activity Patterns**

**Watch the LEDs on the board:**

- **LD0 (Heartbeat):** Should pulse in a heartbeat pattern (thump-thump... pause... thump-thump)
- **LD1 (MMC/SD):** Should flash when accessing SD card (brief flickers during file I/O)
- **LD2 (CPU0):** Should flash with CPU activity
- **L123 (Power):** Should be solid ON (power indicator)

**Generate activity to test:**

```bash
# Genonfigured Zynq PS SPI controller** via EMIO to Arduino header  
✅ **Configured Zynq PS I2C controller** via EMIO to Arduino header  
✅ **Added AXI GPIO IP block** for LED control in programmable logic  
✅ **Created pin constraints** for LEDs, SPI, and I2C  
✅ **Created comprehensive kernel configuration** for USB host, storage, HID, and serial  
✅ **Wrote device tree configuration** for all peripherals (USB, SPI, I2C, LEDs)  
✅ **Configured LED activity triggers** for visual system feedback  
✅ **Built and deployed** updated kernel and bitstream  
✅ **Tested all peripherals** with real hardware and software tool

**USB Peripherals:**
- ✅ **Input Devices:** USB keyboards and mice for interactive use
- ✅ **Storage:** USB flash drives and hard drives
- ✅ **Serial Adapters:** FTDI, CP210x, PL2303 USB-to-serial converters
- ✅ **WiFi Adapters:** USB WiFi dongles (with appropriate drivers)
- ✅ **Printers:** USB printers (with CUPS)
- ✅ **Webcams:** USB video devices (with V4L2)

**Communication Interfaces:**
- ✅ **SPI:** Access via `/dev/spidev0.0` for SPI sensors and devices
- ✅ **I2C:** Access via `/dev/i2c-0` for I2C sensors and E───────────┐
│                     Application Layer                              │
│     (Desktop, Python scripts, C programs, Web Browser)             │
├────────────────────────────────────────────────────────────────────┤
│                      Linux Subsystems                              │
│  ┌──────────┐ ┌──────────┐ ┌─────────┐ ┌──────┐ ┌──────┐ ┌─────┐│
│  │ DRM/KMS  │ │USB Stack │ │  Input  │ │ SPI  │ │ I2C  │ │ LED ││
│  │(Display) │ │(Devices) │ │(HID)    │ │      │ │      │ │     ││
│  └──────────┘ └──────────┘ └─────────┘ └──────┘ └──────┘ └─────┘│
├────────────────────────────────────────────────────────────────────┤
│               Hardware (Zynq PS + PL)                              │
│  ┌──────────────┐ ┌───────────┐ ┌─────────────┐ ┌─────────────┐ │
│  │Video Pipeline│ │    USB    │ │  SPI/I2C    │ │  AXI GPIO   │ │
│  │(PL: VDMA,   │ │(PS: ULPI) │ │(PS: EMIO→PL)│ │(PL: LEDs)   │ │
│  │ VTC, HDMI)   │ │→ USB Port │ │→ Pins       │ │→ 4x LEDs    │ │
│  └──────────────┘ └───────────┘ └─────────────┘ └─────────────┘ │
└───────────
# Turn LED on
echo 255 > /sys/class/leds/pynq:red:ld3/brightness

# Turn LED off
echo 0 > /sys/class/leds/pynq:red:ld3/brightness
```

**2. Set Different Triggers:**

```bash
# Change LD0 to timer mode
echo timer > /sys/class/leds/pynq:red:ld0/trigger

# Set blink rate (milliseconds)
echo 100 > /sys/class/leds/pyn
- ✅ SPI interface accessible via `/dev/spidev0.0`
- ✅ I2C interface accessible via `/dev/i2c-0`
- ✅ Activity LEDs with multiple trigger modes
- ✅ Visual system feedback (heartbeat, disk, CPU activity)q:red:ld0/delay_on
echo 100 > /sys/class/leds/pynq:red:ld0/delay_off

# Change to disk activity
echo disk-activity > /sys/class/leds/pynq:red:ld0/trigger

# Change back to heartbeat
echo heartbeat > /sys/class/leds/pynq:red:ld0/trigger
```

**3. LED Brightness Control:**

LEDs can have variable brightness (0-255):

```bash
# Set to manual control
echo none > /sys/class/leds/pynq:red:ld3/trigger

# Half brightness (if supported by hardware)
echo 128 > /sys/class/leds/pynq:red:ld3/brightness

# Full brightness
echo 255 > /sys/class/leds/pynq:red:ld3/brightness
```

**Note:** Simple on/off LEDs may only support 0 (off) and 255 (on), ignoring intermediate values.

### **Part D: Python LED Control**

Create a simSensor Integration**

Connect sensors and devices:

```bash
# I2C sensors (temperature, pressure, accelerometer)
i2cdetect -y 0
i2cget -y 0 0x48 0x00  # Example: TMP102 temperature sensor

# SPI devices (ADCs, DACs, displays)
# Use Python spidev library or C/C++ with /dev/spidev0.0
```

**Option 4: Custom Applications**

Develop embedded applications using:
- Python with USB, SPI, I2C, GPIO, and display access
- Qt5/GTK GUI applications with DRM backend
- Real-time sensor data acquisition and logging
- LED feedback for system status
- Hardware control via SPI/I2C peripherals

**Example: Combined System Application**

```python
#!/usr/bin/env python3
# Complete system status display
import os
import time

def set_led(num, state):
    path = f"/sys/class/leds/pynq:red:ld{num}"
    os.system(f"echo none > {path}/trigger")
    os.system(f"echo {state} > {path}/brightness")

# Show boot sequence on LEDs
for i in range(4):
    set_led(i, 255)
    time.sleep(0.2)

# Restore activity triggers
os.system("echo heartbeat > /sys/class/leds/pynq:red:ld0/trigger")
os.system("echo mmc0 > /sys/class/leds/pynq:red:ld1/trigger")
os.system("echo cpu0 > /sys/class/leds/pynq:red:ld2/trigger")
set_led(3, 255)  # Power indicator

print("System ready!")
print("- USB devices active")
print("- SPI available at /dev/spidev0.0")
print("- I2C available at /dev/i2c-0")
print("- Display output at 720p60")
print("- Activity LEDs configured")
```

---

## **13te: 0 (off) or 255 (on)
    """
    led_path = f"/sys/class/leds/pynq:red:ld{led_num}"
    
    # Set to manual control
    with open(f"{led_path}/trigger", "w") as f:
        f.write("none")
    
    # Set brightness
    with open(f"{led_path}/brightness", "w") as f:
        f.write(str(state))

# Blink all LEDs in sequence
print("Blinking LEDs in sequence...")
for _ in range(3):
    for led in range(4):
        set_led(led, 255)
        time.sleep(0.2)
        set_led(led, 0)
        time.sleep(0.2)

# Restore triggers
print("Restoring default triggers...")
os.system("echo heartbeat > /sys/class/leds/pynq:red:ld0/trigger")
os.system("echo mmc0 > /sys/class/leds/pynq:red:ld1/trigger")
os.system("echo cpu0 > /sys/class/leds/pynq:red:ld2/trigger")
os.system("echo 255 > /sys/class/leds/pynq:red:ld3/brightness")

print("Done!")
```

Save as `led_test.py` and run:

```bash
chmod +x led_test.py
sudo ./led_test.py
```

---

## **10. Troubleshooting**

### **SPI Issues**

**Issue: No `/dev/spidev*` device**

**Diagnosis:**
```bash
dmesg | grep -i spi
ls /sys/bus/spi/devices/
```

**Common Causes:**
1. Device tree not configured correctly
2. SPI driver not loaded
3. EMIO routing not correct

**Fix:**
```bash
# Check device tree
dtc -I dtb -O dts /boot/system.dtb | grep -A 20 "spi0"

# Load SPI driver manually
modprobe spidev

# Check EMIO routing in Vivado (ensure SPI_0 is set to EMIO)
```

---

### **I2C Issues**

**Issue: No `/dev/i2c-*` device**

**Diagnosis:**
```bash
dmesg | grep -i i2c
ls /sys/bus/i2c/devices/
lsmod | grep i2c
```

**Common Causes:**
1. Device tree not configured correctly
2. I2C driver not loaded
3. EMIO routing not correct

**Fix:**
```bash
# Check device tree
dtc -I dtb -O dts /boot/system.dtb | grep -A 20 "iic0"

# Load I2C driver manually
modprobe i2c-dev
modprobe i2c-xiic

# Check EMIO routing in Vivado (ensure IIC_0 is set to EMIO)
```

**Issue: `i2cdetect` shows all addresses as busy**

**Cause:** Wrong I2C mode or bus speed too high

**Fix:**
```bash
# Try slower speed in device tree:
# clock-frequency = <100000>;  /* 100 kHz standard mode */
```

---

### **LED Issues**

**Issue: LEDs don't light up**

**Diagnosis:**
```bash
ls /sys/class/leds/
cat /sys/class/leds/pynq:red:ld0/brightness
dmesg | grep -i gpio
```

**Common Causes:**
1. AXI GPIO not in device tree
2. GPIO address mismatch
3. Pin constraints wrong

**Fix:**
```bash
# Check GPIO device tree
dtc -I dtb -O dts /boot/system.dtb | grep -A 30 "axi_gpio"

# Verify GPIO exists in sysfs
ls /sys/class/gpio/

# Check constraints match LED pins (R14, P14, N16, M14)
```

**Issue: LED trigger not working**

**Cause:** Trigger module not loaded

**Fix:**
```bash
# Load trigger modules
modprobe ledtrig-heartbeat
modprobe ledtrig-cpu
modprobe ledtrig-disk

# Check available triggers
cat /sys/class/leds/pynq:red:ld0/trigger
```

**Issue: Manual control doesn't work**

**Cause:** Trigger still active

**Fix:**
```bash
# Must set trigger to 'none' first
echo none > /sys/class/leds/pynq:red:ld0/trigger
echo 255 > /sys/class/leds/pynq:red:ld0/brightness
```

---

## **11. Troubleshooting (USB)**

### **Issue: No USB Devices Detected**

**Symptoms:** `lsusb` shows only root hub, no devices detected

**Diagnosis:**

```bash
dmesg | grep -i "usb\|phy\|ci_hdrc"
ls /sys/bus/usb/devices/
cat /sys/kernel/debug/usb/devices
```

**Common Causes:**

1. **PHY not reset properly**
   - Check GPIO 46 is configured correctly
   - Verify `reset-gpios = <&gpio0 46 1>` in device tree

2. **ULPI clock missing**
   - Check ULPI_CLK signal in hardware
   - Verify PHY chip is powered (3.3V)

3. **VBUS not enabled**
   - Check `drv-vbus` in device tree
   - Verify 5V USB power is present (check with multimeter)

4. **Wrong dr_mode**
   - Ensure `dr_mode = "host"` in device tree
   - Check if USB is configured for device mode by mistake

**Fix:**

```bash
# Manually reset USB PHY via GPIO
echo 46 > /sys/class/gpio/export
echo out > /sys/class/gpio/gpio46/direction
echo 0 > /sys/class/gpio/gpio46/value
sleep 1
echo 1 > /sys/class/gpio/gpio46/value

# Check if PHY is now detected
dmesg | tail -20

# Reload USB controller driver
rmmod ci_hdrc_msm
modprobe ci_hdrc_msm
```

### **Issue: USB Keyboard/Mouse Not Working**

**Symptoms:** Device detected but no input events

**Diagnosis:**

```bash
ls /dev/input/
evtest
dmesg | grep -i hid
lsmod | grep hid
```

**Common Causes:**

1. **HID driver not loaded**
   ```bash
   modprobe usbhid
   modprobe hid_generic
   ```

2. **Wrong event device**
   - Use `evtest` to identify correct device
   - Check `/proc/bus/input/devices` for device names

3. **Input subsystem not configured**
   - Verify `CONFIG_INPUT_EVDEV=y` in kernel config
   - Check `CONFIG_USB_HID=y`

**Fix:**

```bash
# Load HID modules
modprobe usbhid
modprobe hid_generic

# Test input
cat /dev/input/by-id/*-kbd | hexdump -C
# Press keys, should see data
```

### **Issue: USB Storage Not Mounting**

**Symptoms:** Drive detected but no `/dev/sda`

**Diagnosis:**

```bash
dmesg | grep -E "sd|scsi"
ls /sys/block/
cat /proc/partitions
```

**Common Causes:**

1. **usb-storage driver not loaded**
   ```bash
   modprobe usb_storage
   ```

2. **Drive not partitioned**
   ```bash
   fdisk -l /dev/sda
   ```

3. **Filesystem not supported**
   ```bash
   # Install filesystem support
   apt install -y ntfs-3g exfat-fuse exfat-utils
   ```

**Fix:**

```bash
# Reload storage driver
modprobe -r usb_storage
modprobe usb_storage

# Force rescan
echo "- - -" > /sys/class/scsi_host/host0/scan

# Check partition table
fdisk -l /dev/sda

# Mount manually
mount -t vfat /dev/sda1 /mnt/usb
# or
mount -t ext4 /dev/sda1 /mnt/usb
```

### **Issue: Slow USB Transfer Speed**

**Symptoms:** Transfer speed < 5 MB/s

**Cause:** USB running in Full-Speed (12 Mbps) instead of High-Speed (480 Mbps)

**Check:**

```bash
lsusb -t
# Look for "480M" (High-Speed) vs "12M" (Full-Speed)

dmesg | grep "high-speed\|full-speed"
```

**Fix:**

- Ensure USB 2.0 compliant cable
- Check TUSB1210 PHY configuration
- Verify ULPI clock is stable

### **Issue: "Device not accepting address" Error**

**Symptoms:** Device plugged in but enumeration fails

**Error in dmesg:**

```
usb 1-1: device not accepting address 2, error -71
```

**Common Causes:**

1. **Insufficient power supply**
   - Check 5V rail voltage (should be 4.75-5.25V)
   - Use powered USB hub for high-power devices

2. **Signal integrity issues**
   - Try shorter USB cable
   - Try different USB device

3. **PHY configuration issue**
   - Check device tree PHY settings
   - Verify ULPI viewport register

**Fix:**

```bash
# Reset USB subsystem
echo -n "ci_hdrc.0" > /sys/bus/platform/drivers/ci_hdrc/unbind
sleep 1
echo -n "ci_hdrc.0" > /sys/bus/platform/drivers/ci_hdrc/bind

# Check power supply voltage
# Use multimeter on 5V USB pin
```

### **Useful Debug Commands**

```bash
# Monitor USB events in real-time
udevadm monitor --kernel --subsystem-match=usb

# View USB device tree
lsusb -v | less

# Check USB power consumption
lsusb -v | grep -i "MaxPower"

# View USB controller status
cat /sys/bus/platform/drivers/ci_hdrc/ci_hdrc.0/power/runtime_status

# Enable USB debugging
echo 'module usbcore =p' > /sys/kernel/debug/dynamic_debug/control
echo 'module ci_hdrc =p' > /sys/kernel/debug/dynamic_debug/control

# View debugging messages
dmesg -w
```

---

## **9. Summary and Next Steps**

### **What You Accomplished**

✅ **Configured Zynq PS USB controller** with ULPI PHY support  
✅ **Created comprehensive kernel configuration** for USB host, storage, HID, and serial  
✅ **Wrote device tree configuration** for TUSB1210 PHY and USB controller  
✅ **Built and deployed** updated kernel with USB support  
✅ **Tested USB functionality** with keyboards, mice, storage, and serial adapters  
✅ **Verified driver operation** with multiple device types  

### **System Capabilities**

Your PYNQ-Z2 now supports:

- ✅ **Input Devices:** USB keyboards and mice for interactive use
- ✅ **Storage:** USB flash drives and hard drives
- ✅ **Serial Adapters:** FTDI, CP210x, PL2303 USB-to-serial converters
- ✅ **WiFi Adapters:** USB WiFi dongles (with appropriate drivers)
- ✅ **Printers:** USB printers (with CUPS)
- ✅ **Webcams:** USB video devices (with V4L2)

### **Combined System Architecture**

```
┌─────────────────────────────────────────────────────────┐
│                   Application Layer                     │
│  (Desktop, Terminal, File Manager, Web Browser)         │
├─────────────────────────────────────────────────────────┤
│           Linux Subsystems                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │ DRM/KMS     │  │  USB Stack  │  │Input System │    │
│  │ (Display)   │  │  (Devices)  │  │ (HID/evdev) │    │
│  └─────────────┘  └─────────────┘  └─────────────┘    │
├─────────────────────────────────────────────────────────┤
│              Hardware (Zynq PS + PL)                    │
│  ┌─────────────────────┐  ┌──────────────────────┐    │
│  │  Video Pipeline     │  │   USB Controller     │    │
│  │  (PL: VDMA, VTC)   │  │   (PS: ChipIdea)     │    │
│  │  → HDMI Output      │  │   → USB Type-A       │    │
│  └SPI on Linux:** https://www.kernel.org/doc/html/latest/spi/index.html
- **I2C on Linux:** https://www.kernel.org/doc/html/latest/i2c/index.html
- **LED Subsystem:** https://www.kernel.org/doc/html/latest/leds/index.html
- **Zynq TRM:** UG585 - Zynq-7000 Technical Reference Manual
  - Chapter 36: USB Controller
  - Chapter 19: SPI Controller
  - Chapter 20: I2C Controller
- **PYNQ-Z2 Schematics:** https://reference.digilentinc.com/reference/programmable-logic/pynq-z2/reference-manual

---

## **Quick Reference Commands**

**USB:**
```bash
lsusb                          # List USB devices
lsusb -t                       # USB device tree
evtest                         # Test keyboard/mouse
```

**SPI:**
```bash
ls /dev/spidev*                # Check SPI devices
python3 -c "import spidev; print('SPI available')"
```

**I2C:**
```bash
ls /dev/i2c*                   # Check I2C devices
i2cdetect -y 0                 # Scan I2C bus 0
i2cget -y 0 0x50 0x00          # Read from device
```

**LEDs:**
```bash
ls /sys/class/leds/            # List LEDs
cat /sys/class/leds/pynq:red:ld0/trigger  # Show trigger
echo none > /sys/class/leds/pynq:red:ld0/trigger  # Manual mode
echo 255 > /sys/class/leds/pynq:red:ld0/brightness  # Turn on
```

---

**🎉 Congratulations!** Your PYNQ-Z2 is now a complete embedded computing platform with:
- HDMI video output for display
- USB host support for peripherals  
- SPI and I2C for sensor integration
- Visual feedback via activity LEDs
- Complete Linux userspace access to all hardware

You have successfully integrated Processing System (PS) and Programmable Logic (PL) to create a versatile development

From previous steps:
- ✅ Debian Linux bootable system (Steps 1-6)
- ✅ HDMI video output at 720p60 (Steps 7-8)
- ✅ DRM/KMS graphics support (Step 8)
- ✅ Framebuffer device `/dev/fb0` (Step 8)

From this step:
- ✅ USB host mode enabled
- ✅ USB keyboard and mouse input
- ✅ USB storage device support
- ✅ USB serial adapter support

### **Next Steps**

**Option 1: Desktop Environment**

Now that you have display output and USB input, install a full desktop:

```bash
# Install X11 and XFCE
apt install -y xserver-xorg-core xserver-xorg-video-fbdev
apt install -y xfce4 xfce4-terminal

# Start desktop
startxfce4
```

See [GUI.md](../GUI.md) for detailed desktop setup.

**Option 2: Networking**

Add network connectivity:

```bash
# Wired Ethernet (if enabled in Zynq PS)
ip link set eth0 up
dhclient eth0

# WiFi USB adapter
apt install -y wpasupplicant wireless-tools
# Configure via /etc/wpa_supplicant/wpa_supplicant.conf
```

**Option 3: Custom Applications**

Develop embedded applications using:
- Python with USB, GPIO, and display access
- Qt5/GTK GUI applications with DRM backend
- Custom bare-metal applications with USB HID
- Sensor interfaces via USB serial

---

## **10. Additional Resources**

- **Main README:** [../README.md](../README.md) - Complete system documentation
- **GUI Setup:** [../GUI.md](../GUI.md) - Desktop environment setup
- **USB on Linux:** https://www.kernel.org/doc/html/latest/driver-api/usb/index.html
- **ChipIdea USB Driver:** https://www.kernel.org/doc/html/latest/usb/chipidea.html
- **ULPI Specification:** USB UTMI+ Low Pin Interface (ULPI) Specification
- **Zynq TRM:** UG585 - Zynq-7000 Technical Reference Manual, Chapter 36: USB Controller

---

**🎉 Congratulations!** Your PYNQ-Z2 now has full USB host support with keyboard, mouse, storage, and serial device capabilities. Combined with HDMI video output from previous steps, you now have a complete interactive computing platform!
```bash
# Create BOOT.BIN with FSBL, bitstream, and U-Boot
petalinux-package --boot \
    --fsbl images/linux/zynq_fsbl.elf \
    --fpga images/linux/system.bit \
    --u-boot images/linux/u-boot.elf \
    --force
```

### **Part C: Deploy to SD Card**

**Option 1: Update Boot Partition Only**

```bash
# Mount SD card boot partition
sudo mount /dev/sdX1 /mnt/boot

# Copy updated files
sudo cp images/linux/BOOT.BIN /mnt/boot/
sudo cp images/linux/image.ub /mnt/boot/
sudo cp images/linux/boot.scr /mnt/boot/

# Unmount
sudo umount /mnt/boot
sync
```

**Option 2: Update Kernel Modules Only**

If you only changed kernel configuration and device tree:

```bash
# Mount rootfs
sudo mount /dev/sdX2 /mnt/rootfs

# Update kernel modules
sudo tar -xzf images/linux/rootfs.tar.gz -C /mnt/rootfs ./lib/modules

# Unmount
sudo umount /mnt/rootfs
sync
```

**Option 3: Full SD Card Image**

```bash
# Create complete WIC image
petalinux-package --wic --images-dir images/linux/ \
    --bootfiles "BOOT.BIN boot.scr image.ub"

# Flash to SD card (CAUTION: erases entire card)
sudo dd if=images/linux/petalinux-sdimage.wic of=/dev/sdX bs=4M status=progress conv=fsync
sync
```
   - `reg = <0xe0002000 0x1000>`: USB0 ULPI viewport register address
   - `view-port = <0x170>`: ULPI viewport register offset
   - `reset-gpios = <&gpio0 46 1>`: MIO pin 46 for PHY reset (active-low)
   - `drv-vbus`: Enable VBUS power control

2. **USB Controller (`&usb0`):**
   - `status = "okay"`: Enable the controller
   - `dr_mode = "host"`: Configure as USB host (not device/OTG)
   - `usb-phy = <&usb_phy0>`: Link to the PHY node

**Important Notes:**

- **GPIO Reference:** 
  - `&gpio0` = PS GPIO controller (MIO pins)
  - `&axi_gpio_0` = PL GPIO controller (for LEDs)
- **Active-Low Reset:** The `1` flag indicates active-low (reset by pulling low)
- **ULPI Viewport:** 0xe0002000 is the USB0 controller base address in Zynq PS
- **VBUS Power:** `drv-vbus` enables 5V USB power output
- **SPI/I2C Names:** Zynq PS names I2C as `iic`, but Linux typically uses `i2c` in device nodes
- **LED Triggers:** Can be changed at runtime via `/sys/class/leds/*/trigger`

### **Part C: Verify Complete Device T
- SPI configuration
- I2C configuration
- LED GPIO configuration

Example structure:

```dts
/include/ "system-conf.dtsi"

/ {
    chosen {
        bootargs = "...";
    };

    reserved-memory { /* Video CMA from Step 8 */ };
    
    /* Video nodes from Step 8 */
    hdmi_out: hdmi-output { ... };
    drm_pl_disp: drm-pl-disp-drv { ... };
    
    /* USB PHY node */
    usb_phy0: phy0 { ... };
    
    /* LED configuration */
    leds { ... };
};

/* Video VDMA and VTC from Step 8 */
&axi_vdma_0 { ... };
&v_tc_0 { ... };

/* USB Controller */
&usb0 { ... };

/* SPI Controller */
&spi0 { ... };

/* I2C Controller */
&iic_vdma_0 { ... };
&v_tc_0 { ... };

/* USB Controller */
&usb0 { ... };
```NFIG_HID_MICROSOFT=y
CONFIG_HID_MONTEREY=y

# Input device support
CONFIG_INPUT=y
CONFIG_INPUT_KEYBOARD=y
CONFIG_INPUT_MOUSE=y
CONFIG_INPUT_MOUSEDEV=y
CONFIG_INPUT_MOUSEDEV_PSAUX=y
CONFIG_INPUT_MOUSEDEV_SCREEN_X=1024
CONFIG_INPUT_MOUSEDEV_SCREEN_Y=768
CONFIG_INPUT_EVDEV=y
CONFIG_INPUT_UINPUT=y

# USB Keyboard/Mouse (built-in)
CONFIG_USB_KBD=y
CONFIG_USB_MOUSE=y

# Additional useful USB support
CONFIG_USB_PRINTER=y
CONFIG_USB_ACM=y
CONFIG_USB_SERIAL=y
CONFIG_USB_SERIAL_CONSOLE=y
CONFIG_USB_SERIAL_GENERIC=y
CONFIG_USB_SERIAL_FTDI_SIO=y
CONFIG_USB_SERIAL_PL2303=y
CONFIG_USB_SERIAL_CP210X=y

# USB Common Platform
CONFIG_USB_COMMON=y
CONFIG_USB_ARCH_HAS_HCD=y
```

**Key Configuration Sections:**

1. **USB Core:** Basic USB subsystem (`CONFIG_USB=y`)
2. **PHY Support:** ULPI PHY and TUSB1210 driver
3. **ChipIdea Controller:** Zynq's USB controller (`CONFIG_USB_CHIPIDEA=y`)
4. **HID Support:** Keyboard and mouse drivers
5. **Storage Support:** Mass storage devices
6. **Input Subsystem:** Event device support (`CONFIG_INPUT_EVDEV=y`)
7. **Serial Adapters:** FTDI, CP210x, PL2303 support

### **Part B: Update Kernel Recipe**

Tell PetaLinux to apply the USB configuration.

**1. Edit or Create the Kernel Append Recipe:**

```bash
vi project-spec/meta-user/recipes-kernel/linux/linux-xlnx_%.bbappend
```

**2. Add USB Configuration Fragment:**

If the file exists, add the line. If creating new, use this content:

```bitbake
FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI += "file://usb_input.cfg"
```

If you already have `video_drm.cfg` from Step 8, the file should look like:

```bitbake
FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI += " \
    file://video_drm.cfg \
    file://usb_input.cfg \
"
```
   We need to locate the GPIO LED node. PetaLinux auto-generates this based on the AXI GPIO, but we can override it using the & reference.  
   * *Assumption:* Your AXI GPIO for LEDs is named axi\_gpio\_0. Check components/plnx\_workspace/.../pl.dtsi if unsure.

/include/ "system-conf.dtsi"

/\* Configure SPI to use the spidev driver (allows Python/C userspace access) \*/  
\&spi0 {  
    status \= "okay";  
    spidev@0 {  
        compatible \= "rohm,dh2228fv"; /\* Generic compatible string often used for spidev \*/  
        reg \= \<0\>;  
        spi-max-frequency \= \<50000000\>;  
    };  
};

/\* Configure I2C to be visible to userspace \*/  
\&i2c0 {  
    status \= "okay";  
    /\* The i2c-dev driver handles this automatically \*/  
};

/\* LED Heartbeat Trigger \*/  
/\* We need to append to the existing gpio-leds node.   
   Note: The exact node name depends on how PetaLinux generated pl.dtsi.  
   A safer way is to redefine the leds node if you know the gpio handle.  
   For now, let's try the common alias approach. \*/

\&axi\_gpio\_0 {  
    /\* Ensure the driver knows these are LEDs \*/  
    compatible \= "xlnx,xps-gpio-1.00.a";  
};  
*Better Approach for LEDs:* If you want a specific LED to blink, the best way in modern PetaLinux is often to verify the auto-generated pl.dtsi after build, or define gpio-leds manually.**Manual LED Node (Robust Method):**/ {  
    leds {  
        compatible \= "gpio-leds";  
        led0 {  
            label \= "pynq:green:ld0";  
            gpios \= \<\&axi\_gpio\_0 0 0\>; /\* Pin 0 of AXI GPIO \*/  
            linux,default-trigger \= "heartbeat"; /\* Blinks like a heartbeat \*/  
        };  
        led1 {  
            label \= "pynq:green:ld1";  
            gpios \= \<\&axi\_gpio\_0 1 0\>;  
            linux,default-trigger \= "mmc0"; /\* Blinks on SD Card Activity \*/  
        };  
    };  
};

### **Part H: Build & Deploy**

1. **Build:**  
   petalinux-build \-c kernel  
   petalinux-build \-c device-tree  
   petalinux-package \--boot \--fsbl ... \--fpga ... \--u-boot \--force

2. **Update SD Card:** Copy BOOT.BIN, image.ub, boot.scr.

## **5\. Validation**

1. **Visual Check:**  
   * **LD0:** Should start beating (thump-thump... thump-thump) as soon as the Kernel loads.  
   * **LD1:** Should flicker whenever the SD card is accessed.  
2. **USB Check:**  
   * Plug in a USB Flash Drive.  
   * Run lsusb and dmesg. You should see "Mass Storage Device detected".  
   * Mount it: mount /dev/sda1 /mnt.  
3. **I2C/SPI Check:**  
   * **I2C:** ls /dev/i2c\*. You should see /dev/i2c-0.  
   * **SPI:** ls /dev/spidev\*. You should see /dev/spidev0.0.

## **6\. Recap**

You have now integrated the standard "Board Support Package" features. Your custom FPGA design is no longer just a math accelerator; it is a fully capable I/O platform.

* **EMIO:** You routed Processor signals through the Fabric to reach external pins.  
* **Device Tree Overlays:** You learned how to map generic GPIOs to specific Linux subsystem functions (LED Triggers).