# **Phase 2: The PYNQ Flow (Rapid Prototyping)**

## **1\. The Goal**

To master the control of FPGA hardware directly from Python without writing a single line of Verilog/VHDL.

In this phase, we will peel back the layers of the PYNQ framework. You will move from using high-level "Drivers" (like led.on()) to low-level **Direct Memory Access** (MMIO), which is the fundamental mechanism used by all embedded Linux drivers to talk to hardware.

## **2\. Sanity Check (Pre-Flight)**

Ensure Phase 1 was successful and your board is ready.

* \[ \] **Board Booted:** PYNQ-Z2 is powered on; Blue/Green LEDs are flashing.  
* \[ \] **Network:** You can access the Jupyter Notebook interface at http://pynq:9090.  
* \[ \] **Filesystem:** You know where to create a new Notebook file (New \> Python 3).

## **3\. Step-by-Step Instructions**

### **Part A: Loading the "Base" Overlay**

The PYNQ image comes with a pre-compiled hardware design called base.bit. It connects the HDMI, Audio, and GPIO pins to the processor.

1. **Create a New Notebook:**  
   * Go to http://pynq:9090.  
   * Click **New** \> **Python 3**.  
   * Rename it to Phase2\_Learning.  
2. Load the Bitstream:  
   Run the following code block:  
   ```python
   from pynq import Overlay

   # This command programs the FPGA fabric instantly
   base = Overlay("base.bit")

   # Check what IP blocks are available in this design
   # This prints a dictionary of all hardware accelerators currently active
   print("Overlay Loaded. Hardware Blocks available:")
   for ip_name in base.ip_dict:
      print(f" - {ip_name}")

   ```

3. **Check:**  
   * **Visual:** The "DONE" LED (Yellow/Green) on the board might flicker briefly as the FPGA is reprogrammed.  
   * **Output:** You should see a list of IP blocks like btns\_gpio, leds\_gpio, hdmi\_in, etc.

### **Part B: The "Easy" Way (High-Level Drivers)**

PYNQ provides Python classes that wrap the complex AXI protocol into simple object methods.

1. Control LEDs:  
   The base overlay object automatically creates drivers for known peripherals.  
```python
from pynq.lib import LED, Button

# Address the 4 User LEDs (LD0 - LD3)
led0 = base.leds[0]
led1 = base.leds[1]

# Turn them on/off
led0.on()
led1.off()
```

   * *Action:* Look at your board. LD0 should be ON.  
2. **Read Buttons:**  
```python
# Read Button 0 (BTN0)
btn0 = base.buttons[0]

print(f"Button 0 State: {btn0.read()}")
```

   * *Action:* Hold down BTN0 on the board and re-run the cell. The state should change from 0 to 1\.

### **Part C: The "Hard" Way (MMIO \- The Real Skill)**

Now we strip away the magic. How does led.on() actually work? It writes a 1 to a specific physical memory address.

We will bypass the Python driver and talk to the silicon directly using **Memory Mapped I/O (MMIO)**.

1. Find the Physical Address:  
   The AXI GPIO controller for the LEDs has a specific address on the internal system bus.  
   ```python
   # Get the dictionary entry for the LED controller
   led_ip = base.ip_dict['leds_gpio']

   physical_addr = led_ip['phys_addr']
   addr_range = led_ip['addr_range']

   print(f"LED Controller is at: 0x{physical_addr:x}")
   ```

   * *Note:* This is usually 0x41210000 for the PYNQ-Z2 base overlay.  
2. Create an MMIO Instance:  
   We map that physical address into Python's memory space.  
   ```python
   from pynq import MMIO

   # Create a window into the hardware
   led_mmio = MMIO(physical_addr, addr_range)
   ```

3. Poke the Hardware:  
   The AXI GPIO documentation states that Offset 0x0 is the Data Register. Writing bits here turns pins High/Low.  
   ```python
   # Write 0xF (Binary 1111) to offset 0x0
   # This should turn ALL 4 LEDs ON
   led_mmio.write(0x0, 0xF)
   ```

   * *Check:* Did all 4 LEDs light up?

   ```python
   # Write 0x5 (Binary 0101) to offset 0x0
   # This should turn LD0 and LD2 ON, LD1 and LD3 OFF
   led_mmio.write(0x0, 0x5)
   ```

   * *Check:* Did LD0 and LD2 light up, while LD1 and LD3 are off?

## **4\. Final Validation: The Hybrid Test**

We will create a loop that uses the **High-Level** driver to read buttons, but uses **Low-Level MMIO** to write the LEDs. This proves you understand both layers.

Run this loop in a new cell:

   ```python
   import time

   print("Press BTN0 to light up LEDs (MMIO Mode). Press BTN3 to exit.")

   while True:  
      # High-Level Read  
      if base.buttons[3].read() == 1:  
         print("Exit command received.")  
         break  
            
      # Logic: Copy Button 0 state to all 4 LEDs  
      if base.buttons[0].read() == 1:  
         # Low-Level Write: Turn all ON (0xF)  
         led_mmio.write(0x0, 0xF)  
      else:  
         # Low-Level Write: Turn all OFF (0x0)  
         led_mmio.write(0x0, 0x0)  
            
      time.sleep(0.1)
   ```

**Action:** Press BTN0 repeatedly. The LEDs should flash in sync with your press.

## **5\. Recap: Knowledge Gained**

* **Bitstream Loading:** You learned that the FPGA logic is not permanent; it can be swapped instantly using Overlay("file.bit").  
* **The Hardware Dictionary:** You learned that base.ip\_dict contains the map of the current hardware design, including the vital **Physical Addresses**.  
* **MMIO (Memory Mapped I/O):** You demystified the driver layer. You learned that controlling hardware is fundamentally just writing integers to specific memory addresses (offsets) managed by the Linux kernel.

**Why this matters:** When you build your custom "Loopback Project" later, there won't be a pre-made pynq.lib.LED driver for your custom IP. You will **have** to use MMIO to talk to it. You just learned how.

## **6. Next Phase**

Now that we know how to control the hardware, let's learn how to create it.

**[Go to Phase 3: The Vivado Flow (Hardware Definition)](learning_phase3.md)**