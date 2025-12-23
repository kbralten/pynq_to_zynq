# **Phase 4: The Embedded Linux Flow (OS Construction)**

## **1\. The Goal**

To gain the ability to build the operating system from source code, rather than relying on pre-compiled disk images.

You will master two methods:

1. **Method A (PYNQ SDBuild):** The automated flow used by Xilinx to generate the official PYNQ images (Ubuntu \+ Python \+ Jupyter).  
2. **Method B (PetaLinux/Yocto):** The industry-standard flow to build a custom, minimal Linux distribution tailored exactly to your hardware.

## **2\. Sanity Check (Pre-Flight)**

Building an OS is the most resource-intensive task in embedded development.

* \[ \] **Disk Space:** You need at least **100GB** of free space. (Yocto builds are massive).  
* \[ \] **RAM:** 16GB is recommended. (Linking the kernel takes \~4GB+).  
* \[ \] **OS:** Linux (Ubuntu 20.04/22.04 or Debian 12 via WSL2).  
* \[ \] **Dependencies:** You have installed PetaLinux (from the Loopback Project) or Docker.

## **3\. Method A: The PYNQ SDBuild Flow (The "Easy" Way)**

This set of scripts automates the complex process of fetching Ubuntu, cross-compiling the Kernel, and installing the PYNQ Python libraries.

### **Step 1: Clone the Repository**

Get the build scripts from the official source.

git clone \[https://github.com/Xilinx/PYNQ.git\](https://github.com/Xilinx/PYNQ.git)  
cd PYNQ/sdbuild

### **Step 2: Setup Environment**

You can run this directly on your host (if it matches the supported OS exactly) or use the provided script to install QEMU and crosstool-ng.

\# This installs generic dependencies (qemu, crosstool-ng)  
./scripts/setup\_host.sh

* *Note:* If you are on a non-standard OS (like Debian/WSL), this script might fail. PYNQ now encourages using **Docker** for reproducible builds.

### **Step 3: The Build Command**

To build a custom image for the PYNQ-Z2:

\# You must provide the "boards" directory containing Pynq-Z2.spec  
make BOARDS=Pynq-Z2

* *What happens:*  
  1. Downloads the Ubuntu Base RootFS (ARM).  
  2. Compiles the Linux Kernel (using PetaLinux under the hood).  
  3. Injects the PYNQ Python package and Jupyter notebooks.  
  4. Outputs a flashable .img file.

### **Step 4: Output**

* Location: sdbuild/output/Pynq-Z2-\<version\>.img.  
* Action: Flash this to an SD card using BalenaEtcher.

## **4\. Method B: The PetaLinux Flow (The Industry Standard)**

This is what we did in the Loopback Project, but formalized. This builds a "pure" Xilinx Linux system without the Ubuntu/Jupyter overhead.

### **Step 1: Create Project**

Instead of using a generic template, we will create a project specifically for the Zynq 7000\.

source /tools/Xilinx/PetaLinux/2025.1/settings.sh  
petalinux-create \--type project \--template zynq \--name custom\_os\_phase4  
cd custom\_os\_phase4

### **Step 2: Import Hardware (The Handshake)**

You need the .xsa file from **Phase 3** (The Counter Project).

petalinux-config \--get-hw-description \<path\_to\_phase3\_xsa\_folder\>

* **Configuration:**  
  * **Image Packaging \> Root filesystem type:** Set to **EXT4**.  
  * **Subsystem \> Serial Settings:** Ensure ttyPS0 is primary (for console access).

### **Step 3: Customize the RootFS**

PetaLinux assumes a minimal system. Let's add standard tools.

petalinux-config \-c rootfs

* Navigate to **Filesystem Packages**.  
* Enable: console \> network \> openssh. (This enables SSH access).  
* Enable: base \> util-linux. (For fdisk/mount tools).

### **Step 4: Build & Package (WIC)**

Since we are on WSL2/Modern Linux, we use the WIC format for easy flashing.

\# 1\. compile everything  
petalinux-build

\# 2\. Package into a single disk image file  
petalinux-package \--wic \--bootfiles "BOOT.BIN image.ub boot.scr" \--rootfs-file images/linux/rootfs.tar.gz

### **Step 5: Output**

* Location: images/linux/petalinux-sdimage.wic.  
* Action: Copy to Windows and flash with BalenaEtcher.

## **5\. Testing & Validation**

### **Test 1: PYNQ SDBuild Image**

1. Boot the image from Method A.  
2. Go to http://pynq:9090.  
3. **Success:** You see the Jupyter interface. This proves you successfully built the entire Ubuntu-based stack from source.

### **Test 2: PetaLinux Image**

1. Boot the image from Method B.  
2. Connect via Serial Console (115200 baud).  
3. **Success:** You see a login prompt (custom\_os\_phase4 login:).  
4. Run uname \-a. It should show the specific kernel version you built.

## **6\. Recap: Knowledge Gained**

* **Build Systems:** You learned the difference between **SDBuild** (a heavy, Ubuntu-based layering script) and **PetaLinux** (a Yocto-based build system for creating minimal, efficient firmware).  
* **Dependency Management:** You realized that building an OS requires a massive amount of dependencies (compilers, emulators like QEMU, library headers).  
* **Artifact Generation:** You mastered creating .wic images, which simplifies deployment significantly compared to manually partitioning SD cards with fdisk.

**Next Steps:** You now have the skills to modify the OS itself. If you need a realtime kernel patch or a specific WiFi driver, you now know exactly where to insert it in the build chain.

## **Final Graduation**

You now understand the Board, the PYNQ abstraction, the Hardware Design, and the OS Build. It is time to put it all together.

**[Enter The Loopback Project](loopback/index.md)**