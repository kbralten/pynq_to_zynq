# **Loopback Project Step 3: The Embedded Linux Build**

## **1\. The Goal**

To build a custom Linux Operating System (OS) tailored specifically for the hardware system we designed in Vivado.

In Step 2, we created the "body" (Hardware). Now we must create the "soul" (Software). We will generate the bootloader (FSBL/U-Boot), the Linux Kernel, and the Root Filesystem, all configured to recognize our custom math\_accelerator IP.

## **2\. Sanity Check (Pre-Flight)**

This step **requires** a Linux environment. You cannot do this directly on Windows.

* **Build Machine:** A machine running Ubuntu 20.04 or 22.04 (Native Linux, VirtualBox, or WSL2).  
* **PetaLinux Tools:** PetaLinux 2024.1 (or matching your Vivado version) is installed.  
* **Input File:** You have the system\_wrapper.xsa file from Step 2 transferred to your Linux machine (e.g., in \~/Downloads).

## **2.1 Installing PetaLinux 2025.1 on WSL2 (Debian/Ubuntu)**

If you have not installed PetaLinux yet, follow these instructions. PetaLinux is notoriously strict about dependencies.

### **Step A: Prepare WSL2**

1. **Update System:**  
   sudo apt update && sudo apt upgrade \-y

2. Install Dependencies:  
   Copy and run this command to install the required libraries. This covers the requirements for PetaLinux 2024.x/2025.x.  
   sudo apt install \-y iproute2 gawk python3 python3-pip gcc git tar gzip unzip make net-tools \\  
   libncurses-dev tftpd-hpa zlib1g-dev libssl-dev flex bison libselinux1 gnupg wget diffstat \\  
   chrpath socat xterm autoconf libtool texinfo gcc-multilib build-essential libsdl1.2-dev \\  
   libglib2.0-dev screen pax gzip locales libtool-bin cpio lib32z1 lz4 zstd rsync bc

   *Note for Debian Users:* If you encounter locale errors later, run sudo dpkg-reconfigure locales and ensure en\_US.UTF-8 is selected and generated.  
3. Install Legacy libtinfo5 (Manual Fix):  
   Newer Debian versions (12+) have removed libtinfo5, but Xilinx tools still depend on it. You must manually install it from the legacy archives:  
   \# Download the package from the Debian archives  
   wget \[http://ftp.us.debian.org/debian/pool/main/n/ncurses/libtinfo5\_6.4-4\_amd64.deb\](http://ftp.us.debian.org/debian/pool/main/n/ncurses/libtinfo5\_6.4-4\_amd64.deb)

   \# Install it using dpkg  
   sudo dpkg \-i libtinfo5\_6.4-4\_amd64.deb

4. Fix Default Shell:  
   PetaLinux requires /bin/sh to be bash, but on Debian/Ubuntu it defaults to dash. If dpkg-reconfigure does not work, force the link manually:  
   \# Force /bin/sh to point to bash  
   sudo ln \-sf /bin/bash /bin/sh

   \# Verify the change (should say /bin/sh \-\> /bin/bash)  
   ls \-l /bin/sh

### **Step B: Run the Installer**

1. **Download:** Download the **PetaLinux 2025.1 Installer** (.run file) from the AMD/Xilinx website to your WSL2 filesystem (e.g., \~/Downloads).  
2. **Create Directory:**  
   sudo mkdir \-p /tools/Xilinx/PetaLinux/2025.1  
   sudo chown \-R $USER:$USER /tools/Xilinx

3. **Execute Installer:**  
   chmod \+x ./petalinux-v2025.1-final-installer.run  
   ./petalinux-v2025.1-final-installer.run \--dir /tools/Xilinx/PetaLinux/2025.1 \--log plnx\_install.log

   * *Note:* You will be prompted to accept license agreements. Press q to quit the reader and y to accept.

## **3\. Step-by-Step Instructions**

### **Part A: Project Initialization**

1. Setup Environment:  
   Open your terminal and source the PetaLinux settings script.  
   source /tools/Xilinx/PetaLinux/2025.1/settings.sh

   *(Note: Adjust version number in path if you are using 2024.1)*  
   *Check:* Run echo $PETALINUX. It should print the installation path.  
2. Create Project:  
   We create a new project using the Zynq template.  
   cd \~/projects  
   petalinux-create \--type project \--template zynq \--name loopback\_os  
   cd loopback\_os

### **Part B: Import Hardware Configuration**

This is the magic step where PetaLinux reads your XSA file and automatically writes the Device Tree (.dts) files for you.

1. Import XSA:  
   (Replace \~/Downloads with wherever you saved your XSA file)  
   petalinux-config \--get-hw-description \~/Downloads/system\_wrapper.xsa

2. The Blue Configuration Menu:  
   A blue ASCII menu will appear. This is the System Configuration.  
   * **Goal:** We need to tell PetaLinux to boot from the SD card, not the QSPI flash (default).  
3. **Configure for SD Boot:**  
   * Navigate to **Image Packaging Configuration** \> **Root filesystem type**.  
   * Select **EXT4 (SD/eMMC/SATA/USB)**.  
   * *Why?* The default INITRAMFS is good for testing but gets wiped on reboot. EXT4 allows persistent storage on the SD card partition.  
4. **Exit and Save:**  
   * Exit the menus. Select **\< Yes \>** when asked to save configuration.  
   * *Wait:* PetaLinux will now parse the hardware and download necessary Yocto recipes. This can take 5-10 minutes.

### **Part C: The Device Tree (Optional but Recommended)**

By default, PetaLinux attempts to auto-detect your custom IP. Let's verify it or manually add it to ensure our C code can find it later.

1. Generate Device Tree Source:  
   The components/plnx\_workspace directory is often empty until the build process starts. Run this specific command to generate the device tree files without waiting for the full OS build:  
   petalinux-build \-c device-tree

2. **Check Auto-Generated Device Tree:**  
   * Open components/plnx\_workspace/device-tree/device-tree/pl.dtsi.  
   * *Action:* Search for math\_accelerator.  
   * *Success:* You should see a node with reg \= \<0x43c00000 ...\>. This confirms PetaLinux knows your IP exists and where it lives.

### **Part D: The Big Build**

Now we compile the world.

1. **Run Build:**  
   petalinux-build

   * *Warning:* The first build takes a long time (30-60 minutes) as it downloads and compiles the Linux Kernel, U-Boot, and the entire root filesystem from scratch.  
   * *Coffee Break Time.*

   Troubleshooting: The "ildcard" Makefile ErrorIf the build fails with syntax error near unexpected token '(' pointing to ($wildcard \*.c) or (ildcard \*.c), you have a typo in your custom IP's Makefile. The term ildcard appears because Make expands $w (which is empty) leaving ildcard.**The Fix:**

   1. Go to your **Vivado IP Repository** (on your Windows/host machine).  
   2. Navigate to ip\_repo/math\_accelerator\_1.0/drivers/math\_accelerator\_v1\_0/src/Makefile.  
   3. Open it in a text editor.  
   4. Locate the LIBSOURCES and OUTS lines (often lines 11-12).  
   5. Change them to:  
      LIBSOURCES=$(wildcard \*.c)  
      OUTS \= \*.o

      *Critical check:* Ensure the $ is **outside** the parenthesis $(...), not inside ($...).  
   6. Save the file.  
   7. **In Vivado:** Re-export the Hardware (XSA) (Step 2 Part F).  
      * **Refresh:** If you see a yellow banner "IP Catalog is out-of-date", click **Refresh IP Catalog** first.  
      * **Reset:** Right-click your block and select **Upgrade IP** (if locked) or **Reset Output Products**.  
      * **Regenerate:** Right-click and select **Generate Output Products** (ensure Synthesis is checked).  
      * **Bitstream:** You **must** run **Generate Bitstream** again because resetting the products wiped the previous implementation.  
   8. **In Linux:** Copy the new verified XSA over.  
   9. **Re-Import:** Run petalinux-config \--get-hw-description ... again. This extracts the new Makefile into the build system.  
   10. **Build:** Run petalinux-build.

   Troubleshooting: QEMU "struct sched\_attr" ErrorIf the build fails with redefinition of ‘struct sched\_attr’, your Debian host headers are conflicting with QEMU's internal code. This happens on newer Linux distributions.**The Fix:**

   1. Open the failing file in your text editor (replace \<PROJECT\_DIR\> with your path):  
      nano \<PROJECT\_DIR\>/build/tmp/work/x86\_64-linux/qemu-xilinx-native/8.2.7+git/git/linux-user/syscall.c

   2. Use Ctrl+W to search for struct sched\_attr.  
   3. Comment out the entire struct definition (approximately 8-10 lines) by surrounding it with /\* and \*/.  
      * *Reason:* The system header /usr/include/linux/sched/types.h already defines this, so QEMU doesn't need to redefine it.  
   4. Save (Ctrl+O) and Exit (Ctrl+X).  
   5. Immediately run petalinux-build again. (Do not run clean, or it will revert your changes).

### **Part E: Packaging the Boot Image**

The Zynq needs a single file (BOOT.BIN) to start up. This file packages three things:

1. **FSBL:** Initializes the chip.  
2. **Bitstream:** Configures the FPGA (your math\_accelerator).  
3. **U-Boot:** Loads Linux.  
4. **Package Command:**  
   petalinux-package \--boot \--fsbl images/linux/zynq\_fsbl.elf \--fpga images/linux/system.bit \--u-boot \--force

   * *Note:* The \--fpga flag is critical. Without it, your custom logic won't be loaded on boot.

## **4\. Final Validation & Deployment (WSL2 Friendly)**

Since you are running WSL2, you cannot easily format an SD card directly from Linux. We will generate a complete disk image file instead.

1. Generate WIC Image:  
   This command packages the Boot Partition (FAT32) and RootFS (EXT4) into a single .wic disk image.  
   petalinux-package \--wic \--bootfiles "BOOT.BIN image.ub boot.scr" \--rootfs-file images/linux/rootfs.tar.gz

2. Verify Output:  
   Check that the file exists:  
   ls \-lh images/linux/petalinux-sdimage.wic

3. Copy to Windows:  
   Transfer the image to your Windows C: drive (e.g., Downloads folder).  
   cp images/linux/petalinux-sdimage.wic /mnt/c/Users/YOUR\_USER\_NAME/Downloads/

4. **Flash in Windows:**  
   * Download **BalenaEtcher** or **Rufus** on Windows.  
   * Select the petalinux-sdimage.wic file.  
   * Select your SD Card.  
   * Flash.  
5. **Boot Test:**  
   * Insert SD card into PYNQ-Z2.  
   * Set jumper **JP1** to **SD**.  
   * Connect USB Serial cable (baud 115200).  
   * Power on.  
   * *Success:* You should see U-Boot messages, then Linux booting, and finally a login prompt (loopback-os login:). Log in with user petalinux and password petalinux (usually prompts to set a new one).

## **5\. Recap: What did we just do?**

* **BSP Creation:** We translated our hardware design (.xsa) into a software configuration (petalinux-config).  
* **Kernel Compilation:** We built a custom Linux kernel that knows about our specific memory map.  
* **Boot Packaging:** We bundled the FPGA Bitstream into the bootloader. This means when we turn the board on, our "Add 1" logic is physically programmed into the chip before Linux even starts.

**Next Step:** The final step\! We will write a C program on the Zynq to poke address 0x43C00000 and see if our hardware adds 1 to our input.