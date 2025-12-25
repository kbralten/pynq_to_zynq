# **Phase 4: Beyond the Basics ( Graduation )**

## **1. You Are Now a Hybrid Developer**

Congratulations. You have crossed the chasm that separates 99% of developers.

*   **Software Developers** see the FPGA as a black box.
*   **Hardware Engineers** see Python as a scripting toy.
*   **You** now see them as a single, unified system.

You have learned that **Hardware is just an accelerated function call**. You can move logic from Python to Verilog and back again, choosing the right tool for the job.

## **2. Skills You Have Unlocked**

| Skill | What you can build now |
| :--- | :--- |
| **MMIO (Phase 2)** | Custom drivers for sensors, motors, and legacy chips. |
| **Overlay Creation (Phase 3)** | Hardware accelerators for crypto, signal processing, or proprietary logic. |
| **IP Integration** | Combining Xilinx IPs (Video, DMA, DSP) into complex SoCs. |
| **Python Glue** | Rapid prototyping of hardware-controlled applications. |

## **3. Where to Go Next?**

Now that you understand the "Flow", you can choose your specialization.

### **Path A: High Performance Computing (HLS)**
Writing Verilog is hard. **High Level Synthesis (HLS)** allows you to write C/C++ code and compile it into Hardware IP.
*   *Explore:* Vitis HLS.
*   *Goal:* Take a heavy Python function (like an Image Filter), rewrite it in C++, compile to IP, and speed it up by 100x.

### **Path B: Video & Vision**
The Zynq is a beast at video processing.
*   *Explore:* AXI Video Direct Memory Access (VDMA).
*   *Goal:* Create a pipeline that takes HDMI in, applies an edge-detection filter in hardware, and outputs HDMI.

### **Path C: The Operating System (The Deep Dive)**
Throughout this journey, we used the "Standard" PYNQ SD card image. But what if you need to build your own?
*   What if you need a Real-Time Kernel?
*   What if you need a minimal OS that boots in 2 seconds?
*   What if you need to modify the Device Tree?

This requires stepping off the "Easy Path" and learning to build Embedded Linux from scratch.

## **4. The Loopback Project**

Your learning journey doesn't end here; it just gets deeper.

The **Loopback Project** in this repository is the advanced course. It documents the painful, messy, real-world process of building a custom programmable logic IP and the software and OS to support it.

It covers:
1.  **Pure Hardware:** Building a Video Test Pattern Generator.
2.  **OS Construction:** Building PetaLinux from source (Bare Metal style).
3.  **Kernel Hacking:** Writing a kernel module for interrupts.
4.  **The Full Stack:** A complete end-to-end video application.

If you are ready to enter the factory and see how the OS is actually made:

**[Enter The Loopback Project](../loopback/index.md)**
