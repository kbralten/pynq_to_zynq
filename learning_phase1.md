# **Phase 1: Board Bring-up & "Hello World"**

## **1\. The Goal**

To establish a functional PYNQ environment on your PYNQ-Z2 board.  
By the end of this phase, you will have a running Embedded Linux system that you can program using Python via a web browser (Jupyter Notebooks), proving the hardware is alive and the network is configured correctly.

## **2\. Sanity Check (Pre-Flight)**

Ensure you have the physical assets required to power and connect the board.

* \[ \] **Hardware:**  
  * PYNQ-Z2 Board.  
  * MicroSD Card (Minimum 8GB, Class 10 recommended).  
  * Micro-USB Cable (capable of data transfer, not just charging).  
  * Ethernet Cable.  
* \[ \] **Software:**  
  * Image Flashing Tool (BalenaEtcher, Rufus, or Win32DiskImager).  
  * Serial Terminal (PuTTY, TeraTerm, or screen on Linux/Mac).  
* \[ \] **Internet Access:** To download the initial disk image (\~2.5GB).

## **3\. Step-by-Step Instructions**

### **Part A: Prepare the Boot Medium**

1. **Download Image:**  
   * Go to [PYNQ.io Boards Page](https://www.google.com/search?q=http://www.pynq.io/board.html).  
   * Locate the **PYNQ-Z2** section.  
   * Download the latest SD Card Image (e.g., v3.0.1 or v2.7). *Note: This is a large zip file.*  
2. **Flash the SD Card:**  
   * Insert your MicroSD card into your computer.  
   * Open **BalenaEtcher**.  
   * Select the downloaded image file (you typically don't need to unzip it; Etcher handles zip files).  
   * Select your SD card target.  
   * Click **Flash\!**.  
   * *Validation:* Wait for the "Validation" step to complete successfully to ensure no write errors occurred.

### **Part B: Hardware Configuration (The Jumpers)**

The Zynq chip checks physical pins on startup to decide where to boot from. We must set these correctly.

1. **Boot Jumper (JP1):**  
   * Locate **JP1** (Top right, near the HDMI Out).  
   * Move the jumper shunts to the **SD** position. (This tells the BootROM to look at the SD card first).  
2. **Power Jumper (JP6):**  
   * Locate **JP6** (Bottom right, near the Power Switch).  
   * **If powering via USB:** Set to **USB**.  
   * **If powering via Wall Adapter:** Set to **REG**.

### **Part C: Physical Connections**

1. **Insert SD Card:** Slot is on the underside of the board.  
2. **Ethernet:** Connect the board to your Router/Switch. (Direct PC connection is possible but requires static IP configuration; Router is easiest for beginners).  
3. **USB Serial:** Connect the Micro-USB cable to the **PROG/UART** port on the board and your PC.

### **Part D: Power On & Boot Sequence**

1. **Power On:** Slide the **Power Switch (SW1)** to **ON**.  
2. **Observe LEDs:**  
   * **Red (LD13):** Powers on immediately.  
   * **Yellow/Green (LD12 \- DONE):** Turns on after a few seconds. *Meaning: The FPGA bitstream was successfully loaded.*  
   * **Blue/Green Flashing:** After 30-60 seconds, the 4 User LEDs (LD0-LD3) and 2 RGB LEDs will flash. *Meaning: Linux has booted and the PYNQ system is ready.*

## **4\. Testing & Validation**

### **Test 1: The Network Check**

1. Open your web browser on the same network.  
2. Navigate to: http://pynq:9090  
   * *Note:* If that doesn't resolve, try the default static IP fallback: http://192.168.2.99:9090 (Requires your PC Ethernet to be in the same subnet).  
3. **Login:**  
   * **Password:** xilinx

### **Test 2: The "Hello World" Notebook**

1. In the Jupyter interface, navigate to the folder base/board.  
2. Open the notebook board\_btns\_leds.ipynb.  
3. Click the **Run** button (Play icon) on the first few cells.  
4. **Action:** When you execute the code block that reads buttons, press a physical button (BTN0-BTN3) on the board.  
5. **Success:** The Python output should update to reflect which button you pressed. This proves the Python layer is successfully talking to the FPGA hardware.

## **5\. Recap: Knowledge Gained**

* **Boot Configuration:** You learned how hardware jumpers (JP1) dictate the boot sequence of the Zynq SoC.  
* **Headless Setup:** You successfully brought up an embedded Linux system without a monitor or keyboard attached to the device.  
* **The PYNQ Abstraction:** You verified that you can control physical hardware signals (LEDs/Buttons) using high-level Python code, bypassing the need for C drivers or Verilog for basic tasks.

**Next Steps:** With the board confirmed working, we will now look at how the PYNQ framework itself works.

## **6. Next Phase**

We will peel back the layers of the Python libraries to see how they talk to memory.

**[Go to Phase 2: The PYNQ Flow (Rapid Prototyping)](learning_phase2.md)**