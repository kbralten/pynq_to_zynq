# **Loopback Project Step 2: The System Integration**

## **1\. The Goal**

To create a complete hardware system that connects the Zynq Processing System (PS) to your custom math\_accelerator IP block via the AXI interconnect.

By the end of this step, we will generate the **Bitstream** (which configures the FPGA) and the **XSA File** (Xilinx Support Archive), which tells the software layer exactly how the hardware is wired.

## **2\. Sanity Check (Pre-Flight)**

Before proceeding, ensure you have the output from Step 1\.

* **IP Repository:** You have a folder (e.g., C:/pynq\_work/ip\_repo) containing the math\_accelerator\_1.0 folder.  
* **XML Descriptor:** Inside that folder, component.xml exists.  
* **Vivado:** You are ready to create a fresh project (close the temporary IP generation project if it's still open).

## **3\. Step-by-Step Instructions**

### **Part A: Project Setup & IP Import**

1. **Create New Project:**  
   * Open Vivado \> **Create Project**.  
   * **Name:** loopback\_system.  
   * **Location:** C:/pynq\_work/projects (Keep path lengths short\!).  
   * **Type:** RTL Project (Do not specify sources yet).  
   * **Part/Board:** Select **PYNQ-Z2** (search "pynq" in the boards tab).  
   * Click **Finish**.  
2. **Add IP Repository:**  
   * In the **Flow Navigator** (left), click **Settings**.  
   * Navigate to **IP** \> **Repository**.  
   * Click the **\+** (Plus) button.  
   * Select your C:/pynq\_work/ip\_repo folder.  
   * *Check:* Vivado should popup a message saying "1 Repository, 1 IP" found. If it says 0, you selected the wrong folder level.  
   * Click **Apply** \> **OK**.

### **Part B: The Block Design**

This is where we wire the chip.

1. **Create Block Design:**  
   * In Flow Navigator, click **Create Block Design**.  
   * Name: system\_design.  
   * Click **OK**.  
2. **Add the Processor:**  
   * Right-click the white canvas \> **Add IP**.  
   * Search for ZYNQ7 Processing System. Double-click to add.  
   * *Check:* You should see the Zynq block. It might look "generic" initially.  
3. **Run Block Automation (Crucial):**  
   * A green banner will appear at the top: *"Designer Assistance available. Run Block Automation"*.  
   * Click **Run Block Automation**.  
   * Ensure "Apply Board Preset" is checked. This configures the DDR memory timings and Clocks specifically for the PYNQ-Z2.  
   * Click **OK**.  
   * *Check:* The Zynq block input pins (DDR, FIXED\_IO) should now have names, representing external pin connections.  
4. **Add Your Custom IP:**  
   * Right-click canvas \> **Add IP**.  
   * Search for math\_accelerator.  
   * Double-click to add.  
   * *Check:* You now have a "math\_accelerator\_0" block floating on the canvas.

### **Part C: Wiring (The "Magic" Button)**

We need to connect the high-speed AXI bus, the resets, and the clocks.

1. **Run Connection Automation:**  
   * The green banner appears again: *"Designer Assistance available. Run Connection Automation"*.  
   * Click **Run Connection Automation**.  
   * Check the box for /math\_accelerator\_0/S00\_AXI.  
   * **Options:** verify that "Master" is set to /processing\_system7\_0/M\_AXI\_GP0.  
   * Click **OK**.  
2. **Inspect the Result:**  
   * Vivado has automatically added two new critical blocks:  
     * **Processor System Reset:** Handles synchronizing the reset signal.  
     * **AXI Interconnect:** A "switch" that routes traffic from the CPU to your IP.  
   * Click the **Regenerate Layout** button (blue circular arrow in the toolbar) to clean up the messy wires.

### **Part D: Addressing**

We need to know *where* our IP lives in the memory map.

1. **Open Address Editor:**  
   * Click the **Address Editor** tab (usually next to the "Diagram" tab above the canvas).  
   * Find math\_accelerator\_0.  
   * **Offset Address:** Note this value\! It usually defaults to 0x43C00000.  
   * *Action:* If it says "Unmapped", right-click and select "Assign Address".  
   * **Record this number.** You will need it for your C code in Step 4\.

### **Part E: Output Generation**

Now we compile the design.

1. **Validate Design:**  
   * Press F6 or click **Tools** \> **Validate Design**.  
   * *Check:* Ensure you get "Validation Successful". Warnings are okay; Errors are not.  
2. **Create HDL Wrapper:**  
   * In the **Sources** tab (left), find system\_design (the block design file).  
   * Right-click it \> **Create HDL Wrapper**.  
   * Select **Let Vivado manage wrapper and auto-update**.  
   * Click **OK**.  
   * *Reason:* The block design is a schematic; Vivado needs a top-level Verilog file to start synthesis.  
3. **Generate Bitstream:**  
   * In Flow Navigator, click **Generate Bitstream**.  
   * Click **Yes** to launch Synthesis and Implementation.  
   * *Wait:* This takes 10-20 minutes depending on your PC.  
   * *Success:* A dialog box will appear saying "Bitstream Generation Completed". Click **Cancel** (we don't need to open the Hardware Manager).

### **Part F: Export Hardware (The Handoff)**

We need to bundle everything for PetaLinux.

1. **Export XSA:**  
   * Go to **File** \> **Export** \> **Export Hardware**.  
   * Click **Next**.  
   * **Output:** Select **Include bitstream**. (Critical\! If you miss this, the FPGA won't get programmed).  
   * **Files Name:** system\_wrapper (default is fine).  
   * **Export Location:** Choose a path (e.g., C:/pynq\_work/output).  
   * Click **Finish**.

## **4\. Final Validation**

Did Step 2 work?

1. Navigate to your export folder (C:/pynq\_work/output).  
2. Look for system\_wrapper.xsa.  
3. **Check file size:** It should be roughly **5 MB to 10 MB**.  
   * *Failure Mode:* If it is \~500 KB, you likely forgot to select "Include Bitstream" during export.

## **5\. Recap: What did we just do?**

* **System Assembly:** We didn't just write code; we built a computer. We connected a dual-core ARM CPU to a custom Arithmetic Logic Unit (ALU) we designed.  
* **AXI Interconnect:** We used the AXI GP (General Purpose) port. We learned that Vivado handles the complex bus arbitration logic for us via "Connection Automation".  
* **Memory Mapping:** We established that physical address 0x43C00000 is now hard-wired to our custom Adder logic.

**Next Step:** In Step 3, we leave the comfortable GUI of Vivado and enter the Linux terminal to build the OS that runs on this hardware.