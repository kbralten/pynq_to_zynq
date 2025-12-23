# Pynq to Zynq: A Learning Journey

Welcome to the **Pynq to Zynq** repository. This project documents the complete path from using the PYNQ-Z2 board within the friendly, Python-based PYNQ ecosystem, to "breaking out" and mastering it as a generic Zynq-7000 development board using professional industry tools (Vivado, PetaLinux, and custom Embedded Linux).

The repository is divided into two major sections:
1.  **The Zynq Learning Journey**: A high-level conceptual roadmap.
2.  **The Loopback Project**: A hands-on, 9-step tutorial building a complete embedded system from scratch.

---

## 1. The Zynq Learning Journey

This series creates the foundational knowledge required to leave the "Python safety net" and understand how the Zynq chip actually works.

*   **Phase 1: Board Bring-up & "Hello World"**
    *   Getting started with the PYNQ-Z2 hardware.
    *   Initial connectivity and verification.
*   **Phase 2: The PYNQ Flow (Rapid Prototyping)**
    *   Using the standard Pynq image.
    *   Leveraging Python overlays for quick hardware interaction without compilation.
*   **Phase 3: The Vivado Flow (Hardware Definition)**
    *   Introduction to Xilinx Vivado.
    *   Creating custom hardware definitions (Bitstreams/XSA) tailored to specific needs.
*   **Phase 4: The Embedded Linux Flow (OS Construction)**
    *   Moving beyond the pre-supplied OS.
    *   Constructing a custom Linux operating system specifically for your hardware design.

---

## 2. The Loopback Project

The **Loopback Project** is the core practical component of this repository. It is a comprehensive "vertical slice" of embedded engineering that proves mastery of the entire stack—from logic gates to user-space applications.

The project starts by building a custom hardware coprocessor and "loops back" to control it via software, then expands into a full-featured custom computer.

### The Phases of the Loopback Project

#### **Foundation: Building the Stack**
*   **[Step 1: The PL Logic (Hardware)](loopback/Loopback%20Project%20Step%201.md)**
    *   **Goal:** Create a custom AXI4-Lite IP block in Verilog.
    *   **Outcome:** A hardware "math accelerator" that adds numbers in silicon.
*   **[Step 2: The System Integration](loopback/Loopback%20Project%20Step%202.md)**
    *   **Goal:** Connect the custom IP to the Zynq ARM Processor using Vivado Block Design.
    *   **Outcome:** A complete system hardware definition (`.xsa` and `.bit`).
*   **[Step 3: The Embedded Linux Build](loopback/Loopback%20Project%20Step%203.md)**
    *   **Goal:** Build a custom PetaLinux OS tailored to our specific hardware.
    *   **Outcome:** A bootable `BOOT.BIN` and Linux kernel image.
*   **[Step 4: The Software Driver](loopback/Loopback%20Project%20Step%204.md)**
    *   **Goal:** Write a C application to control the hardware from Linux user-space.
    *   **Outcome:** A working program that uses Direct Memory Access (DMA) to "talk" to the FPGA.

#### **Expansion: Professional Workflows**
*   **[Step 5: Advanced Workflows](loopback/Loopback%20Project%20Step%205.md)**
    *   **Goal:** Optimize the development loop.
    *   **Techniques:** FPGA Hot-Swapping, Yocto BitBake recipes, and On-Board Self-Hosting (GCC).
*   **[Step 6: The Debian Hybrid](loopback/Loopback%20Project%20Step%206.md)**
    *   **Goal:** Replace the minimal PetaLinux RootFS with a full desktop-class OS.
    *   **Outcome:** A PYNQ-Z2 running standard **Debian 12 (Bookworm)** with `apt` package management.

#### **Advanced Features: Video & Peripherals**
*   **[Step 7: HDMI Video Output (Hardware)](loopback/Loopback%20Project%20Step%207.md)**
    *   **Goal:** Create a custom 720p60 Video Pipeline in the FPGA.
    *   **Tech:** AXI VDMA, Custom Video Timing Controller (VTC), and RGB2HDMI logic.
*   **[Step 8: Linux DRM Driver Configuration](loopback/Loopback%20Project%20Step%208.md)**
    *   **Goal:** Integrate the video hardware into the Linux Kernel.
    *   **Outcome:** A standard `/dev/dri/card0` device usable by modern display frameworks.
*   **[Step 9: Peripheral Integration](loopback/Loopback%20Project%20Step%209.md)**
    *   **Goal:** Enable standard connectivity.
    *   **features:** USB Host (Keyboard/Mouse/Storage), SPI, I2C, and Activity LEDs.

---

### How to Use This Repository

1.  **Start at the Root**: Read the "Zynq Learning Journey" docs to understand the *why*.
2.  **Go to `/loopback`**: Follow the steps sequentially. Each step builds strictly upon the previous one.
3.  **Check the Code**: The repository contains the source code, constraints files, and configuration snippets referenced in the tutorials.

*Happy Hacking!*
