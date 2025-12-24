# **Phase 3: The Vivado Flow (Hardware Definition)**

## **1\. The Goal**

To create a custom hardware overlay (.bit and .hwh) that can be loaded onto a running PYNQ system without rebuilding the Linux OS.

We will design a system containing:

1. **Standard IP:** An AXI GPIO block to control the board's LEDs.  
2. **Custom IP:** A "Hardware Counter" that counts clock cycles. We will control its start/stop state and read its value from Python.

## **2\. Sanity Check (Pre-Flight)**

* \[ \] **Vivado Installed:** You have a working installation (2024.1 or similar).  
* \[ \] **Board Files:** PYNQ-Z2 board files are installed in Vivado.  
* \[ \] **PYNQ Board:** Your board is running the standard PYNQ image (Phase 1 setup), connected to the network.

## **3\. Step-by-Step Instructions**

### **Part A: The Custom IP (Hardware Counter)**

We will create a logic block that counts ticks. This demonstrates internal state retention, which simple combinational logic (like an adder) does not have.

1. **Create IP Project:**  
   * Open Vivado. Click **Create Project**.  
   * Name: ip\_counter\_temp.  
   * Part: **PYNQ-Z2**.  
   * Go to **Tools** \> **Create and Package New IP**.  
   * Select **Create a new AXI4 peripheral**.  
   * Name: axi\_dyn\_counter.  
   * Click **Finish** \> **Edit IP**.  
2. **Modify Verilog (axi\_dyn\_counter\_v1\_0\_S00\_AXI.v):**  
   * Open the source file.  
   * **Add Internal Signals:** Add these lines before the main logic:  
     ```verilog
     reg [31:0] internal_count;
     wire enable_signal;
     wire reset_signal;
     ```

   * **Map Registers:**  
     ```verilog
     slv_reg0: Control Register (Bit 0 \= Enable, Bit 1 \= Reset).  
     slv_reg1: Output Register (The Count).  
     ```
   * **Implement Logic:** Add this block at the end of the file (before endmodule):  
      ```verilog
      // Mapping Control Bits  
      assign enable_signal = slv_reg0[0];
      assign reset_signal  = slv_reg0[1];

      // Counter Logic
      always @( posedge S_AXI_ACLK ) begin
      if ( S_AXI_ARESETN == 1'b0 || reset_signal == 1'b1 ) begin
         internal_count <= 0;
      end else if ( enable_signal == 1'b1 ) begin
         internal_count <= internal_count + 1;
      end
      end
      ```

   * **Hijack Read Logic:** Find the assign S\_AXI\_RDATA (or case statement) logic we touched in the Loopback project. Modify address h1 to read internal\_count instead of slv\_reg1.  
      ```verilog
      // Example for Ternary Syntax (Newer Vivado):
      // ... (axi_araddr[...] == 2'h1) ? internal_count : ...
      ```

3. **Package:**  
   * **Review and Package** \> **Re-Package IP**.  
   * Close the temporary IP project.

### **Part B: The Overlay Project**

Now we build the system that PYNQ will load.

1. **Create Project:**  
   * Create a new RTL Project: pynq\_overlay\_demo.  
   * Board: **PYNQ-Z2**.  
2. **Setup Block Design:**  
   * **Create Block Design** named design\_1.  
   * **Add Zynq PS:** Add ZYNQ7 Processing System and run **Block Automation** (Apply Board Preset).  
   * **Add GPIO:** Add AXI GPIO. Run **Connection Automation**.  
     * *Select:* GPIO interface \-\> leds\_4bits (Board Interface).  
     * *Note:* This maps the software "GPIO" directly to the physical LED pins.  
   * **Add Custom IP:** Add axi\_dyn\_counter. Run **Connection Automation**.  
     * Connects S00\_AXI to the Zynq GP Port.  
3. **Validate & Build:**  
   * **Validate Design** (F6).  
   * **Create HDL Wrapper** (Right-click design\_1 in Sources).  
   * **Generate Bitstream**.

### **Part C: The Hardware Handoff (.hwh)**

This is the secret sauce. PYNQ needs two files:

1. **.bit**: The binary configuration for the FPGA.  
2. **.hwh**: A metadata file describing *what* is in the bitstream (addresses, interrupts, GPIO names). PYNQ uses this to auto-generate the Python drivers.  
3. Locate Bitstream:  
   \<project\_dir\>/pynq\_overlay\_demo.runs/impl\_1/design\_1\_wrapper.bit  
4. Locate Handoff:  
   \<project\_dir\>/pynq\_overlay\_demo.gen/sources\_1/bd/design\_1/hw\_handoff/design\_1.hwh  
   (Note: In older Vivado versions, this might be .tcl, but .hwh is preferred for PYNQ v2.6+).  
5. Rename & Gather:  
   Copy both files to a single folder and rename them to match exactly:  
   * my\_counter.bit  
   * my\_counter.hwh

## **4\. Testing & Validation (On Board)**

Now we switch to the Jupyter Notebook interface.

1. **Upload:**  
   * Open Jupyter (http://pynq:9090).  
   * Upload my\_counter.bit and my\_counter.hwh to the pynq home folder.  
2. Create Notebook:  
   Create a new Python 3 notebook and run:  
      ```python
      from pynq import Overlay
      import time

      # 1. Load the Overlay
      # PYNQ automatically parses the .hwh file to find our IP
      ol = Overlay("my_counter.bit")

      # 2. Check available IPs
      # We should see 'axi_gpio_0' and 'axi_dyn_counter_0'
      print(ol.ip_dict.keys())

      # 3. Create Drivers
      # Standard PYNQ driver for LEDs
      leds = ol.axi_gpio_0.channel1 
      # Custom IP access via MMIO
      counter = ol.axi_dyn_counter_0 

      # 4. Test LEDs
      print("Blinking LEDs...")
      for i in range(4):
         leds.write(0xF, 0xF) # All ON
         time.sleep(0.2)
         leds.write(0xF, 0x0) # All OFF
         time.sleep(0.2)

      # 5. Test Counter
      print("Testing Custom Counter...")

      # Reset (Write 2 to Reg0)
      counter.write(0x0, 2)
      # Enable (Write 1 to Reg0)
      counter.write(0x0, 1)

      print("Counting for 1 second...")
      time.sleep(1.0)

      # Stop (Write 0 to Reg0)
      counter.write(0x0, 0)

      # Read Result (Read Reg1 @ Offset 0x4)
      count_val = counter.read(0x4)

      # Math check: Clock is 100MHz (standard Zynq FCLK). 
      # 1 second should be ~100,000,000 ticks.
      print(f"Counter Value: {count_val}")
      print(f"Frequency: {count_val / 1_000_000:.2f} MHz")
      ```

3. **Expected Result:**  
   * LEDs on the board blink.  
   * Output shows a count value close to 100,000,000 (roughly 100MHz), confirming your custom logic ran at hardware speeds.

## **5\. Recap: Knowledge Gained**

* **Overlay Philosophy:** You created hardware that acts like a software library. You loaded it dynamically without touching the bootloader.  
* **Handoff Files:** You learned that the .hwh file is the bridge that allows Python to understand your Vivado Block Design structure automatically.  
* **Hybrid Driver Model:** You used a high-level PYNQ driver for the standard GPIO IP, but fell back to MMIO for your custom Counter IP within the *same* design.

**Next Steps:** You now have the skills to build the hardware for any custom accelerator.

## **6. Next Phase**

The hardware is done. Now we need to build the software brain that runs on top of it.

**[Go to Phase 4: The Embedded Linux Flow (OS Construction)](learning_phase4.md)**