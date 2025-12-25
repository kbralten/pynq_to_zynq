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
   * Name: `ip_counter_temp`. Click **Next**.
   * **Project Type:** Select **RTL Project** (Do not specify sources). Click **Next**.
   * **Project Part:** Switch to the **Boards** tab.
     * Search for: `pynq`.
     * Select: **pynq-z2**.
   * Click **Next**, then **Finish**.  
   * **Start IP Wizard:** Go to **Tools** > **Create and Package New IP**. Click **Next**.
   * **Task:** Select **Create a new AXI4 peripheral**. Click **Next**.
   * **Details:**
     * Name: `axi_dyn_counter`.
     * Description: `My new AXI IP` (optional).
     * Click **Next**.
   * **Interfaces:** Keep defaults (Lite, Slave, 32-bit, 4 Registers). Click **Next**.
   * **Summary:**
     * Select **Edit IP** (Important!).
     * Click **Finish**.
     * *Observation:* A new Vivado window will open specifically for editing this IP.  
2. **Modify Verilog Source:**  
   In the *Sources* panel, you will see two files:
   * `axi_dyn_counter_v1_0.v`: The top-level wrapper (instantiates the AXI logic).
   * `axi_dyn_counter_v1_0_S00_AXI.v`: The actual AXI Lite implementation. **Edit this one.**
   
   * **Why not the wrapper?**
     * **The Wrapper (`_v1_0.v`):** This file is just the shell. Its job is to group multiple interfaces together. For example, if your IP had an AXI-Lite port *plus* an AXI-Stream video port *plus* an Interrupt line, the wrapper connects them all into one black box.
     * **The Logic (`_S00_AXI.v`):** This file contains the **AXI Protocol Engine**. Vivado has pre-written the complex code that handles the valid/ready handshakes and address decoding. It gives you simple variables (`slv_reg0`) to work with. If you wrote code in the wrapper, you would have to write the AXI state machine yourself!

   * **Open `axi_dyn_counter_v1_0_S00_AXI.v`.**  
   
   * **1. Add Logic (The Counter):**  
     Scroll to the very bottom of the file (around line 400). You will see a placeholder:
     ```verilog
     // Add user logic here

     // User logic ends
     ```
     Paste the following code *between* those lines:
     ```verilog
      // -- Custom Signals --
      reg [31:0] internal_count;
      wire enable_signal;
      wire reset_signal;

      // -- Mappings --
      // slv_reg0[0] = Enable
      // slv_reg0[1] = Reset
      assign enable_signal = slv_reg0[0];
      assign reset_signal  = slv_reg0[1];

      // -- Counter Logic --
      always @( posedge S_AXI_ACLK ) begin
        if ( S_AXI_ARESETN == 1'b0 || reset_signal == 1'b1 ) begin
           internal_count <= 0;
        end else if ( enable_signal == 1'b1 ) begin
           internal_count <= internal_count + 1;
        end
      end
     ```

   * **2. Map Output (The Read):**  
     Scroll up slightly (around line 303). Find the long line that handles reading data (`assign S_AXI_RDATA = ...`).
     
     **Change:** `... ? slv_reg1 : ...`
     **To:** `... ? internal_count : ...`
     
     *Old Line (Simplified):*
     `assign S_AXI_RDATA = (... == 2'h0) ? slv_reg0 : (... == 2'h1) ? slv_reg1 : ...`
     
     *New Line:*
     `assign S_AXI_RDATA = (... == 2'h0) ? slv_reg0 : (... == 2'h1) ? internal_count : ...`

     *Effect:* When the processor reads Register 1 (Offset 0x4), it now sees our live `internal_count` instead of the static `slv_reg1` value.


3. **Package:**  
   * Go to the **Package IP...** tab. 
   * Click **Review and Package** \> **Re-Package IP**.  
   * Close the temporary IP project.

### **Part B: The Overlay Project**

Now we build the system that PYNQ will load.

> **Why a new project?**
> *   **Separation of Concerns:** `ip_counter_temp` is like a "Library Project" (specifically for creating the component). `pynq_overlay_demo` is the "Application Project" (where we wire components together).
> *   **Reusability:** By packaging the IP separately, you can now use `axi_dyn_counter` in *any* future Vivado project, just like you use the standard GPIO block.

1. **Create Project:**  
   * Create a new RTL Project: `pynq_overlay_demo`.  
   * Board: **PYNQ-Z2**.  
2. **Add IP Repository:**  
   (Crucial for finding your custom IP)
   * In the **Flow Navigator** (left), click **Settings**.
   * Go to **IP** > **Repository**.
   * Click **+** (Add Repository).
   * Navigate to your `ip_repo` folder (usually inside `ip_counter_temp/ip_repo`).
   * Select it and click **Select**. Click **OK**.
3. **Setup Block Design:**  
   * **Create Block Design** named design\_1.  
   * **Add Zynq PS:** Add ZYNQ7 Processing System and run **Block Automation** (Apply Board Preset).  
   * **Add GPIO:** Add AXI GPIO. Run **Connection Automation**.  
     * *Select:* GPIO interface \-\> leds\_4bits (Board Interface).  
     * *Note:* This maps the software "GPIO" directly to the physical LED pins.  
   * **Add Custom IP:** Add axi\_dyn\_counter. Run **Connection Automation**.  
     * Connects S00\_AXI to the Zynq GP Port.  
      * Connects S00\_AXI to the Zynq GP Port.  
4. **Validate & Build:**  
   * **Validate Design** (F6).  
   * **Create HDL Wrapper** (Right-click design\_1 in Sources-\>Design Sources).  
   * **Generate Bitstream**.
     * Wait for it to finish with the message "Bitstream generated successfully". You can click **Cancel** in the dialog box.

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
   Create a new Python 3 notebook and create then run the following cells:  
**Cell 1: Load Overlay & Create Drivers**
   ```python
   from pynq import Overlay
   import time

   # 1. Load the Overlay
   ol = Overlay("my_counter.bit")

   # 2. Check IP Dictionary
   print("Available IPs:", ol.ip_dict.keys())

   # 3. Create Drivers
   # Standard PYNQ driver for LEDs (High-Level)
   leds = ol.axi_gpio_0.channel1 
   # Custom IP access via MMIO (Low-Level)
   counter = ol.axi_dyn_counter_0 
   ```

   **Cell 2: Test LEDs (Standard GPIO)**
   ```python
   # Configure Direction (TRI Register)
   # The High-Level driver defaults to Input. We must force Output.
   # Offset 0x4 = Channel 1 Tri-State Control (0 = Output, 1 = Input)
   ol.axi_gpio_0.mmio.write(0x4, 0x0)
   print("Direction set to Output via MMIO.")

   print("Blinking LEDs...")
   for i in range(4):
       leds.write(0xF, 0xF) # All ON
       time.sleep(0.2)
       leds.write(0x0, 0xF) # All OFF
       time.sleep(0.2)
   print("Done.")
   ```

   **Cell 3: Test Custom Counter (MMIO)**
   ```python
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

   # Math check: Clock is 100MHz. 1 second ~ 100M ticks.
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

The hardware is done. Now, let's look at where you go from here.

**[Go to Phase 4: Beyond the Basics (Graduation)](learning_phase4.md)**