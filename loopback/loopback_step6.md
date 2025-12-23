# **Loopback Project Step 6: The Debian Hybrid**

## **1\. The Goal**

To create a standard Debian 12 (Bookworm) system that runs on the PYNQ-Z2, replacing the minimal PetaLinux RootFS.

**Why do this?**

* **Package Management:** You get apt install.  
* **Ease of Use:** It behaves like a Raspberry Pi or Desktop Linux.  
* **Development:** You can install full GCC, Python, VS Code Server, and other tools directly on the board without cross-compilation headaches.

## **2\. Sanity Check**

* **PetaLinux Project:** You have the loopback\_os project from Step 3\.  
* **Dependencies:** You are running in WSL2/Linux and have sudo access.  
* **Internet:** The build machine needs internet access to download Debian packages.

## **3\. Step-by-Step Instructions**

### **Part A: Install Prerequisites**

We need tools to bootstrap a foreign architecture (ARM) filesystem on your x86 PC.

1. **Install Debootstrap & QEMU:**  
   sudo apt update  
   sudo apt install debootstrap qemu-user-static

### **Part B: Build the Debian RootFS**

We will create a folder and fill it with a minimal Debian system.

1. **Create Workspace:**  
   mkdir \-p \~/debian\_work  
   cd \~/debian\_work

2. Bootstrap (Stage 1):  
   Download the base packages.  
   * **Arch:** armhf (This is critical\! Zynq-7000 is 32-bit ARM hard-float).  
   * **Distro:** bookworm (Debian 12).

sudo debootstrap \--arch=armhf \--foreign bookworm ./debian-rootfs

3. Prepare for Chroot:  
   We need to enter this folder as if it were a running ARM machine. We use QEMU to emulate the ARM CPU instructions transparently.  
   \# Copy the QEMU emulator into the new filesystem  
   sudo cp /usr/bin/qemu-arm-static ./debian-rootfs/usr/bin/

4. Bootstrap (Stage 2 \- Inside the Matrix):  
   Now we enter the filesystem to finish the configuration.  
   \# Enter the ARM environment  
   sudo chroot ./debian-rootfs /bin/bash

   \# \--- YOU ARE NOW "INSIDE" THE ARM FILESYSTEM \---

   \# Complete the installation  
   /debootstrap/debootstrap \--second-stage

   * *Wait:* This takes about 5-10 minutes.

### **Part C: Configure the OS (Inside Chroot)**

While still inside the chroot (your prompt might look different), run these commands to make the system usable.

1. **Set Root Password:**  
   passwd  
   \# Enter a password (e.g., 'root')

2. **Set Hostname:**  
   echo "pynq-debian" \> /etc/hostname  
   echo "127.0.0.1 localhost" \> /etc/hosts  
   echo "127.0.1.1 pynq-debian" \>\> /etc/hosts

3. Configure Fstab (The Read-Write Fix):  
   This is the critical step to ensure the filesystem is writable. We explicitly map the root partition (/) to the SD card (/dev/mmcblk0p2). Systemd will use this to remount the drive as RW after boot checks pass.  
   cat \<\<EOF \> /etc/fstab  
   \# \<file system\> \<mount point\>   \<type\>  \<options\>       \<dump\>  \<pass\>  
   /dev/mmcblk0p2  /               ext4    defaults,noatime,errors=remount-ro 0 1  
   proc            /proc           proc    defaults        0       0  
   EOF

4. Configure Network (DHCP):  
   We want Ethernet to work automatically. Fix applied: Debian 12 uses "Predictable Network Names" (end0) instead of eth0. We configure both to guarantee connectivity.  
   apt install \-y net-tools iputils-ping nano

   \# Create interface config  
   cat \<\<EOF \> /etc/network/interfaces  
   auto lo  
   iface lo inet loopback

   \# Legacy naming (just in case)  
   allow-hotplug eth0  
   iface eth0 inet dhcp

   \# Predictable naming (Debian 12 default)  
   allow-hotplug end0  
   iface end0 inet dhcp  
   EOF

5. Configure Serial Console (Crucial):  
   The Zynq communicates via ttyPS0. We must ensure systemd spawns a login prompt there.  
   ln \-s /lib/systemd/system/getty@.service /etc/systemd/system/getty.target.wants/getty@ttyPS0.service

6. Install Development Tools:  
   Let's add the tools we missed in the minimal PetaLinux image.  
   apt update  
   apt install \-y build-essential python3 python3-pip git sudo

7. **Clean Up:**  
   apt clean  
   exit  
   \# \--- YOU ARE NOW BACK ON YOUR HOST PC \---

### **Part D: The Optimized PetaLinux Build (The Slim Way)**

We will build *only* the hardware-specific components (Bootloader, Kernel, Drivers) and skip building the PetaLinux RootFS entirely.

1. Build Components:  
   Run these commands inside your loopback\_os project folder.  
   cd \~/loopback\_system/loopback\_os/

   \# 1\. Build the Bootloader (FSBL)  
   petalinux-build \-c bootloader

   \# 2\. Build U-Boot  
   petalinux-build \-c u-boot

   \# 3\. Build the Kernel (and Modules)  
   petalinux-build \-c kernel

   \# 4\. Build Device Tree  
   petalinux-build \-c device-tree

2. Locate the Modules Archive:  
   The kernel build automatically creates a tarball containing only the drivers/modules.  
   * Path: images/linux/modules-\*.tgz (The name varies slightly by version).  
   * *Check:* ls images/linux/modules-\*.tgz  
3. Inject Modules into Debian:  
   Extract this archive directly into your Debian folder.  
   \# Extract modules directly to the Debian /lib/modules folder  
   \# Note: The tarball usually contains the path "lib/modules/..." inside it.  
   sudo tar \-xzf images/linux/modules-\*.tgz \-C \~/debian\_work/debian-rootfs/

   * *Verify:* Check that \~/debian\_work/debian-rootfs/lib/modules/ now contains a folder named something like 6.1.x-xilinx....  
4. Cross-Compile & Inject Custom Application:  
   We will compile the application on the host machine using the SDK, then copy the binary executable into the Debian filesystem.  
   \# 1\. Source the SDK environment (from Step 4\)  
   \# Adjust path if your SDK is located elsewhere  
   source images/linux/sdk/environment-setup-cortexa9t2hf-neon-xilinx-linux-gnueabi

   \# 2\. Compile the binary  
   \# Assuming loopback\_test.c is in your home directory  
   $CC \~/loopback\_test.c \-o loopback-test

   \# 3\. Verify it is an ARM binary  
   file loopback-test  
   \# Output should say: ELF 32-bit LSB executable, ARM...

   \# 4\. Copy binary to /usr/local/bin (standard place for user apps)  
   sudo cp loopback-test \~/debian\_work/debian-rootfs/usr/local/bin/

   \# 5\. Set executable permissions  
   sudo chmod \+x \~/debian\_work/debian-rootfs/usr/local/bin/loopback-test

### **Part E: Packaging for Deployment**

We will use PetaLinux's package tool to bundle our new Debian filesystem into a .wic SD card image.

1. Compress Debian FS:  
   PetaLinux expects a tarball.  
   cd \~/debian\_work/debian-rootfs  
   sudo tar \-czpf \~/debian\_work/debian-rootfs.tar.gz .

2. Generate WIC Image:  
   Go back to your PetaLinux project and tell it to use your rootfs file instead of its own.  
   cd \~/loopback\_system/loopback\_os/

   petalinux-package \--wic \\  
   \--bootfiles "BOOT.BIN image.ub boot.scr" \\  
   \--rootfs-file \~/debian\_work/debian-rootfs.tar.gz \\  
   \--outdir ./images/linux/debian\_output

3. Result:  
   You now have a file: images/linux/debian\_output/petalinux-sdimage.wic.

### **Part F: Boot & Verify**

1. **Flash:** Copy the .wic file to Windows and flash it with BalenaEtcher.  
2. **Boot:** Insert into PYNQ-Z2 and power on.  
3. **Login:** User root, Password root (or whatever you set).  
4. **Check OS:**  
   cat /etc/debian\_version  
   \# Output: 12.x

5. Check Hardware:  
   Run the loopback test\! The binary is already installed in /usr/local/bin, which is in the system PATH.  
   loopback-test  
   \# Output:  
   \# \--- FPGA Loopback Test \---  
   \# Writing 42...  
   \# Read 43 from Register 1\.  
   \# \[SUCCESS\] Hardware added 1 correctly\!

### **Part G: Optimization (Partition Sizes & Compression)**

The default .wic file is a byte-for-byte Raw Disk Image. If PetaLinux decides the Root partition should be 4GB, the file will be 4GB, even if 3.5GB is empty space.

1\. Controlling Partition Sizes  
You can define exactly how the disk is sliced by creating a Kickstart (.wks) file.

* Create a file named custom\_sd\_layout.wks:  
  \# Boot partition (FAT32) \- 100MB is plenty for Kernel \+ Bootloader  
  part /boot \--source bootimg-partition \--ondisk mmcblk0 \--fstype=vfat \--label boot \--active \--align 4 \--fixed-size 100M

  \# Root Partition (EXT4) \- Auto-expand to fit content \+ 500MB extra space  
  part / \--source rootfs \--ondisk mmcblk0 \--fstype=ext4 \--label root \--align 4 \--extra-space 500M

* Run packaging with the \--wks flag:  
  petalinux-package \--wic \\  
  \--wks custom\_sd\_layout.wks \\  
  \--bootfiles "BOOT.BIN image.ub boot.scr" \\  
  \--rootfs-file \~/debian\_work/debian-rootfs.tar.gz \\  
  \--outdir ./images/linux/optimized\_output

2\. Compressing the Image (The Sparse Trick)  
Since the "empty" space in the image is just zeros, it compresses extremely well.

* **Compress:**  
  gzip \-9 ./images/linux/optimized\_output/petalinux-sdimage.wic

  * *Result:* You will get petalinux-sdimage.wic.gz. This file will likely be \<500MB.  
* Flash:  
  You do not need to unzip this.  
  * **BalenaEtcher** and **Rufus** can flash .gz files directly. Just select the compressed file in Windows.

## **4\. Recap**

You have achieved the "Holy Grail" of embedded development:

* **Hardware:** Custom FPGA Logic (Via PetaLinux Bootloader/Bitstream).  
* **Kernel:** Xilinx-optimized Linux Kernel (Via PetaLinux Kernel).  
* **User Space:** Standard Debian 12 (Via DeBootstrap).

You can now use apt install to add libraries, compilers, and tools, while still retaining full low-level access to your custom FPGA hardware via /dev/mem.

## **5. Next Step**

We have a powerful Linux computer. Now let's enable the High-Definition in HDMI.

**[Go to Step 7: HDMI Video Output](loopback_step7.md)**