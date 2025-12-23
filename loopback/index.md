[← Back to Main Index](../index.md)

# The Loopback Project
### From Logic Gates to User Space

## Overview
The **Loopback Project** is designed to demonstrate a "Vertical Slice" of Embedded Systems Engineering.

In professional FPGA SoC development, it is rare to work on only one layer. A hardware issue can look like a driver bug; a kernel misconfiguration can look like a broken circuit. To be effective, you must understand the full chain of trust.

**The Architecture:**
1.  **Hardware (PL):** A custom "Math Accelerator" IP block and a Video Pipeline.
2.  **Interconnect:** AXI buses linking the FPGA fabric to the Cortex-A9 processor.
3.  **Operating System:** A custom Linux build (PetaLinux/Debian) aware of this unique hardware.
4.  **Software:** User-space applications that "Loopback" data to the hardware to prove control.

---

## 📚 Phase 1: Construction
*Building the system from the ground up.*

*   **[Step 1: The PL Logic (Hardware)](Loopback%20Project%20Step%201.md)**
    *   **What you will do:** Write Verilog code to create a hardware adder IP core.
    *   **Goal:** Understand AXI4-Lite interfaces and custom IP creation.
*   **[Step 2: The System Integration](Loopback%20Project%20Step%202.md)**
    *   **What you will do:** Use Vivado IP Integrator to wire your IP to the Zynq Processing System.
    *   **Goal:** Create the physical address map and generate the bitstream.
*   **[Step 3: The Embedded Linux Build](Loopback%20Project%20Step%203.md)**
    *   **What you will do:** Use PetaLinux to generate a bootloader (FSBL) and Kernel.
    *   **Goal:** Create a bootable OS that knows your custom hardware exists.
*   **[Step 4: The Software Driver](Loopback%20Project%20Step%204.md)**
    *   **What you will do:** Write a C program using `/dev/mem` for Direct Memory Access.
    *   **Goal:** Successfully read and write to your hardware registers from Linux user space.

## 🚀 Phase 2: Optimization
*Turning a prototype into a professional environment.*

*   **[Step 5: Advanced Workflows](Loopback%20Project%20Step%205.md)**
    *   **What you will do:** Learn FPGA Hot-Swapping and create Yocto BitBake recipes.
    *   **Goal:** Drastically reduce development iteration timestamps.
*   **[Step 6: The Debian Hybrid](Loopback%20Project%20Step%206.md)**
    *   **What you will do:** Replace the minimal RootFS with a full Debian 12 Bookworm system.
    *   **Goal:** Gain access to `apt install`, Python, GCC, and a familiar desktop-like experience on-board.

## 🖥️ Phase 3: Peripherals
*Building a real computer.*

*   **[Step 7: HDMI Video Output](Loopback%20Project%20Step%207.md)**
    *   **What you will do:** Implement a hardware video pipeline (VDMA + VTC) in the FPGA.
    *   **Goal:** Drive a 720p60 HDMI monitor directly from the Programmable Logic.
*   **[Step 8: Linux DRM Driver](Loopback%20Project%20Step%208.md)**
    *   **What you will do:** Configure the Linux DRM/KMS subsystem and write a device tree.
    *   **Goal:** Expose your FPGA video pipeline as a standard generic graphics card (`/dev/dri/card0`).
*   **[Step 9: Peripheral Integration](Loopback%20Project%20Step%209.md)**
    *   **What you will do:** Enable USB Host support, SPI, I2C, and Activity LEDs.
    *   **Goal:** Create a fully usable computer that supports keyboards, mice, and flash drives.
