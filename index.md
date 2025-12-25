# Pynq to Zynq: A Learning Repository

## Welcome to the Bridge
The PYNQ-Z2 is a fantastic board, often introduced with the "PYNQ" ecosystem—a Python-based environment that abstracts away the complexity of the underlying hardware (FPGA). While excellent for beginners, this abstraction can become a ceiling.

**This repository is the ladder to break through that ceiling.**

Here, we transition from using provided overlays to building custom hardware architectures from scratch. We move from Jupyter Notebooks to writing Linux kernel drivers. We go from "Python User" to "Zynq Systems Engineer".

---

## 🏗️ 1. The Zynq Learning Journey
*Conceptual Mastery of the Ecosystem*

Before building complex systems, we must understand the tools. These documents serve as the theoretical and practical foundation for working with Xilinx Zynq-7000 SoC devices.

*   **[Phase 1: Board Bring-up & "Hello World"](learning_phase1.md)**
    *   **Goal:** Establish a baseline. Ensure your hardware is functional and your environment is set up.
    *   **Content:** Booting, connectivity, and the first verification steps.
*   **[Phase 2: The PYNQ Flow (Rapid Prototyping)](learning_phase2.md)**
    *   **Goal:** Understand what we are leaving behind (and when to still use it).
    *   **Content:** Using Python overlays for quick "proof of concepts" before committing to hard engineering.
*   **[Phase 3: The Vivado Flow (Hardware Definition)](learning_phase3.md)**
    *   **Goal:** Learn the Language of Hardware.
    *   **Content:** Introduction to Xilinx Vivado, block designs, synthesis, and bitstream generation.
*   **[Phase 4: Beyond the Basics (Graduation)](learning_phase4.md)**
    *   **Goal:** Graduation.
    *   **Content:** Hybrid development, HLS, Video, and the handoff to the advanced Loopback Project.

---

## 🛠️ 2. The Loopback Project
*Practical Mastery via "The Vertical Slice"*

Theory is useful, but engineering is learned by doing. **The Loopback Project** is a multi-step tutorial where we build a single, cohesive system that touches every layer of the embedded stack.

We start by designing a custom math accelerator chip (PL), wiring it to the processor (PS), building an OS to run it (Linux), writing a driver to control it (C), and finally integrating it into a full desktop environment.

**[👉 Enter The Loopback Project](loopback/index.md)**
*(Click here to start the step-by-step tutorial)*
