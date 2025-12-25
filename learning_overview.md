# **The Zynq Learning Journey: From PYNQ-Z2 to Custom**

## **1\. The Mission**

Objective: To master the design and implementation of embedded systems that integrate a Linux System-on-Chip (SoC) with FPGA Programmable Logic (PL).  
Ultimate Goal: To possess the full-stack engineering skills required to bring up a custom PCB, creating the Board Support Package (BSP), configuring the hardware interfaces, and writing the software drivers that bridge the OS and the FPGA.

## **2\. The Hardware Platform**

* **Development Board:** TUL PYNQ-Z2  
* **SoC Architecture:** Xilinx Zynq-7000 (Z-7020)  
  * **PS (Processing System):** Dual-core ARM Cortex-A9 (The "Hard" Silicon). Runs Linux, handles USB, Ethernet, SDIO.  
  * **PL (Programmable Logic):** Artix-7 based FPGA fabric (The "Soft" Hardware). Handles high-speed signals, custom sensors, and acceleration.

## **3\. Core Knowledge Domains**

### **A. Architecture Fundamentals**

* **PS vs. PL:** Understanding the physical boundary between the fixed processor silicon and the configurable logic fabric.  
* **The Boot Process:** BootROM $\\rightarrow$ FSBL (First Stage Boot Loader) $\\rightarrow$ Bitstream Load $\\rightarrow$ U-Boot $\\rightarrow$ Linux Kernel.  
* **AXI Interconnects:**  
  * **AXI GP (General Purpose):** Low-bandwidth. Master (PS) controls Slave (PL). Used for register configuration.  
  * **AXI HP (High Performance):** High-bandwidth. Master (PL) writes to Slave (DDR). Used for DMA and video streams.

### **B. The Skill Hierarchy**

1. **The "Soft" Integration (Level 1):** Using Python/PYNQ libraries to control pre-made hardware overlays via Memory Mapped IO (MMIO).  
2. **The Hardware Design (Level 2):** Using Vivado IP Integrator to create custom hardware blocks and signal routing.  
3. **The Acceleration (Level 3):** Using HLS (High-Level Synthesis) and DMA to offload computational tasks from the CPU to the FPGA.  
4. **The OS Architecture (Level 4):** Building custom Linux images using PYNQ SDBuild, Yocto, or PetaLinux.  
5. **The Custom BSP (Level 5):** Configuring clocks, DDR timings, and device trees for a completely new hardware environment.

## **4\. The Roadmap**

### **Phase 1: Board Bring-up & "Hello World"**

* **Goal:** Establish a working PYNQ environment.  
* **Tasks:**  
  * Flash PYNQ-Z2 image to SD card.  
  * Configure Jumpers (Boot: SD, Power: USB/REG).  
  * Establish Ethernet/Serial connection.  
  * Successful login to Jupyter (http://pynq:9090).

### **Phase 2: The PYNQ Flow (Rapid Prototyping)**

* **Goal:** Control hardware without HDL.  
* **Tasks:**  
  * Run standard overlays (Buttons/LEDs).  
  * Understand the Python Overlay class and MMIO register access.

### **Phase 3: The Vivado Flow (Hardware Definition)**

* **Goal:** Create the "Genetic Code" of the hardware (.xsa).  
* **Tasks:**  
  * Create a "Block Design" in Vivado from scratch.  
  * Instantiate the **Zynq Processing System** IP.  
  * Add **AXI GPIO** or custom IP blocks.  
  * Generate Bitstream and Hardware Handoff files (.hwh).

### **Phase 4: Beyond the Basics (Graduation)**

* **Goal:** Consolidation and specialization.  
* **Tasks:**  
  *   Explore High-Level Synthesis (HLS).
  *   Understand Video Pipelines.
  *   **The Fork:** Choose to stay in Python or dive into the OS (Loopback Project).

## **5\. The "Loopback" Proof Project**

This capstone project serves as the metric for your progress. It touches every layer of the stack required for a custom PCB design.

**Toolchain Version Clarification**

This guide's procedures and examples are verified with the following development environment and toolchain versions:

* **FPGA Design Suite:** Vivado 2025.1 (running on Windows 11\)  
* **Embedded Linux Build System:** PetaLinux 2025.1 (running on a Debian 13 WSL2 image)

Please note that minor differences in tool versions may require adjustments to the build process.

### **Concept**

A system where the Linux CPU writes a value to a custom hardware register in the FPGA, the FPGA modifies it, and the CPU reads it back. This proves you can bridge the PS/PL divide without relying on pre-made drivers.

### **Steps to Success:**

1. **The PL Logic (Hardware):**  
   * Create a simple custom IP (Verilog or HLS) that accepts a 32-bit integer, adds 1 to it, and stores it in an output register.  
   * Expose this IP as an **AXI4-Lite Slave**.  
2. **The Integration (Vivado):**  
   * Create a Block Design connecting the Zynq PS **AXI GP Master** port to your custom IP's Slave port.  
   * Assign a specific address in the memory map (e.g., 0x43C00000).  
   * Export the Hardware Platform (.xsa).  
3. **The System Build (PetaLinux/Yocto):**  
   * Do **not** use the standard PYNQ image.  
   * Initialize a fresh PetaLinux project using your .xsa.  
   * Customize the **Device Tree** (system-user.dtsi) to ensure the kernel recognizes your address space (optional but recommended best practice).  
   * Build a minimal Linux image (Kernel \+ RootFS) and boot via SD card to a command-line prompt.  
4. **The Software Driver (PS/C Code):**  
   * Write a standalone C program on the Zynq.  
   * Use the /dev/mem interface to map the physical address 0x43C00000 into the user-space virtual memory.  
   * Write an integer to the mapped pointer.  
   * Read the result.  
   * **Success Condition:** The program prints: Sent: 10, Received: 11\.

### **Success Criteria**

When you can boot a minimal Linux OS that you built yourself, on hardware you configured yourself, and talk to a logic block you designed yourself, you are ready to design a custom board.

## **6. Next Phase**

Ready to start? Let's check your hardware.

**[Go to Phase 1: Board Bring-up & "Hello World"](learning_phase1.md)**