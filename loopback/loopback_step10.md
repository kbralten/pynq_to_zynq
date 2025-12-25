# Loopback Step 10: System Optimization & Quality of Life

Now that we have a fully functional "computer" with Video, USB, and IO, we need to make it pleasant to use.
The current boot process has massive delays, and there are some rough edges in the user experience.

---

## **1. The Problem: 40-Second Boot Delay**

You observed this in `dmesg`:
```
[   39.153729] probe of e000b000.ethernet returned 0 after 38082454 usecs
```
That is **38 seconds** spent doing nothing.

### **Why?**
The Zynq Ethernet driver (`macb`) is trying to find the PHY (Physical Layer Transceiver) chip.
By default, if the Device Tree doesn't specify *exactly* where the PHY is (which address 0-31), the driver **scans every single address**.
It tries address 0... waits for response... timeout.
Address 1... waits... timeout.
...
Until it hits the PYNQ-Z2's PHY (which is usually at address 0 or 1, but the scan logic is slow).

## **2. The Fix: Explicit PHY Definition**

We need to tell the Linux Kernel exactly where the Ethernet PHY lives so it doesn't have to guess.

### **Part A: Update Device Tree**

Edit your `system-user.dtsi`:

```bash
cd ~/projects/loopback_os
vi project-spec/meta-user/recipes-bsp/device-tree/files/system-user.dtsi
```

Add the Ethernet configuration node. On the PYNQ-Z2, the Ethernet PHY is a **Realtek RTL8211** at MDIO address **1** (or sometimes 0, let's target it specifically).

```dts
/* Optimized Ethernet Configuration */
&gem0 {
    status = "okay";
    phy-mode = "rgmii-id";
    phy-handle = <&ethernet_phy>;

    /* Define the MDIO bus manually to prevent scanning */
    mdio {
        #address-cells = <1>;
        #size-cells = <0>;

        ethernet_phy: ethernet-phy@1 {
            reg = <1>;  /* PHY Address 1 */
            device_type = "ethernet-phy";
            /* Optional: Compatible string if specific workaround needed */
            /* compatible = "ethernet-phy-id001c.c816"; */ 
        };
    };
};
```

**Note:** If `reg = <1>` doesn't work (No network), try `reg = <0>`.

### **Part B: Rebuild Device Tree**

```bash
petalinux-build -c kernel
petalinux-build -c device-tree
petalinux-package --boot --fsbl images/linux/zynq_fsbl.elf --fpga project-spec/hw-description/system_design_wrapper.bit --u-boot --force
```

### **Part C: Update `image.ub`**

If using the SD card image method:
1.  Mount your SD card.
2.  Copy `images/linux/image.ub` to the boot partition.
3.  Reboot.

## **3. Verification**

Reboot and observe the difference.

*   **Before:** ~38 seconds pause.
*   **After:** <1 second pause.

The log should look like:
```
macb e000b000.ethernet eth0: Cadence GEM rev 0x00020118 at 0xe000b000 irq 40
macb e000b000.ethernet eth0: attached PHY driver [RTL8211E Gigabit Ethernet] (mii_bus:phy_addr=e000b000.ethernet-ffffffff:01, irq=POLL)
```

---

## **4. Another Nuance: Quiet Boot**

If you want to hide the wall of text during boot (creating a cleaner, faster-feeling startup), you can tweak the bootargs.

**Edit system-user.dtsi:**

Change:
`bootargs = "console=ttyPS0,115200 ... loglevel=8";`
To:
`bootargs = "console=ttyPS0,115200 ... quiet";`

*   **quiet:** Suppresses most kernel log messages.
*   **loglevel=8:** Shows EVERYTHING (what usage currently have).

---

## **6. Fix System Time (NTP)**

The PYNQ-Z2 has no battery-backed RTC (Real Time Clock). Every time you turn it on, it thinks it is Jan 1st, 1970 (or 2020). Since you are running a full Debian/Ubuntu rootfs, we use standard packages.

### **Part A: Install NTP**

On the board (via serial or SSH):

1.  **Set Plausible Date:**
    `apt` (and SSL certificates) will fail if the date is in 1970. Set a rough date first (YYYY-MM-DD):
    ```bash
    date -s "2025-01-01"
    ```

2.  **Install Packages:**
    ```bash
    # Update package list
    apt update

    # Install NTP and ntpdate
    apt install -y ntp ntpdate
    ```

The `ntp` daemon will now keep your time in sync automatically.

### **Part B: Set Timezone**

Set your local timezone so logs match your wall clock.

```bash
dpkg-reconfigure tzdata
```
Follow the interactive menu to select your region and city.

### **Part C: Force Immediate Sync**

If the time is wildly off, you can force a sync:

```bash
# Stop the service temporarily
systemctl stop ntp

# Force sync
ntpdate pool.ntp.org

# Restart service
systemctl start ntp
```

### **Part D: Verify**

```bash
date
```
It should now show the correct current date and time.

---

## **7. Next Steps**

This concludes the core "Loopback" series. You have:
1.  **Hardware:** Custom FPGA Video & IO structure.
2.  **Drivers:** Custom Kernel Modules & Device Architecture.
3.  **OS:** Full Linux desktop & peripheral support.
4.  **Polish:** Optimized boot usage.

Go forth and build cool things!
