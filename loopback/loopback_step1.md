# **Loopback Project Step 1: The PL Logic (Hardware)**

## **1\. The Goal**

To create a custom hardware Intellectual Property (IP) block using Verilog that acts as a coprocessor.

* **Input:** It will accept a 32-bit integer from the processor via an AXI4-Lite interface.  
* **Processing:** It will increment that integer by 1 using dedicated FPGA logic gates.  
* **Output:** It will make the result available for the processor to read back.

This "Loopback" mechanism proves that we have successfully bridged the gap between the software (PS) and the hardware (PL).

## **2\. Sanity Check (Pre-Flight)**

Before starting, ensure your environment is ready.

* **Vivado Installed:** Open Vivado 2024.1 (or your installed version).  
* **Board Files:** Create a dummy project and ensure "PYNQ-Z2" is selectable in the "Default Part" list.  
  * *If missing:* Download board files from PYNQ.io or TUL website and install them to Xilinx/Vivado/2024.1/data/boards/board\_files.

## **3\. Step-by-Step Instructions**

### **Part A: The "Create and Package New IP" Wizard**

We will not write the AXI interface from scratch (which is error-prone). We will use Xilinx's wizard to generate a robust template.

1. **Create Temporary Project:**  
   * Open Vivado.  
   * Click **Create Project**.  
   * Name: ip\_generation\_temp.  
   * Part: Select **PYNQ-Z2** (or xc7z020clg400-1).  
   * *Note: This project is just a wrapper to launch the wizard; we will delete it later.*  
2. **Launch the Wizard:**  
   * Go to **Tools** \> **Create and Package New IP**.  
   * Click **Next**.  
   * Select **Create a new AXI4 peripheral**. Click **Next**.  
3. **Configure the IP:**  
   * **Name:** math\_accelerator  
   * **Description:** A simple loopback adder  
   * **IP Location:** Choose a folder you can easily access (e.g., C:/pynq\_work/ip\_repo).  
   * Click **Next**.  
4. **Configure Interface:**  
   * **Name:** S00\_AXI (Default)  
   * **Interface Type:** Lite  
   * **Interface Mode:** Slave  
   * **Data Width:** 32  
   * **Number of Registers:** 4 (We only need 2, but 4 is the minimum for the wizard).  
   * Click **Next**.  
5. **Edit the IP:**  
   * Select **Edit IP** (Last option).  
   * Click **Finish**.  
   * *Result:* A **new** Vivado window will open. This is your IP editing environment.

### **Part B: Implementing the "Add 1" Logic**

Now we modify the Verilog code to make it do something.

1. **Open the Source:**  
   * In the **Sources** panel (left side), expand math\_accelerator\_v1\_0.  
   * Double-click math\_accelerator\_v1\_0\_S00\_AXI.v.  
   * *Concept:* This file handles the AXI handshake. It contains 4 registers: slv\_reg0, slv\_reg1, slv\_reg2, slv\_reg3.  
2. **Locate the Read Logic:**  
   * Scroll down (around line 390\) to the comment: // Implement memory mapped register select and read logic generation.  
   * Depending on your Vivado version, this will either be a case statement or an assign statement.  
3. **The Modification:**  
   * We will keep the standard write logic (CPU writes to slv\_reg0).  
   * We will hijack the read logic for slv\_reg1. Instead of reading back a stored value, we will return slv\_reg0 \+ 1\.

**Scenario A: If you see a case statement (Older Templates):**
```Verilog
  // ... existing code ...  
case ( axi\_araddr\[ADDR\_LSB+OPT\_MEM\_ADDR\_BITS:ADDR\_LSB\] )  
    2'h0   : reg\_data\_out \<= slv\_reg0;  
    2'h1   : reg\_data\_out \<= slv\_reg1;  
    2'h2   : reg\_data\_out \<= slv\_reg2;  
    2'h3   : reg\_data\_out \<= slv\_reg3;  
    default : reg\_data\_out \<= 0;  
endcase  
```
**Modified Code (Do This):**
```Verilog
// ... existing code ...  
case ( axi\_araddr\[ADDR\_LSB+OPT\_MEM\_ADDR\_BITS:ADDR\_LSB\] )  
   2'h0   : reg\_data\_out \<= slv\_reg0;      // Read back input  
   2'h1   : reg\_data\_out \<= slv\_reg0 \+ 32'd1; // HARDWARE ADDER LOGIC HERE  
   2'h2   : reg\_data\_out \<= slv\_reg2;  
   2'h3   : reg\_data\_out \<= slv\_reg3;  
   default : reg\_data\_out \<= 0;  
endcase  
```
**Scenario B: If you see an assign statement (Newer Templates)**: Find the line starting with `assign S\_AXI\_RDATA \= ...` and modify the section for address 2'h1.

**Original Code (Ternary Style):**
```Verilog
assign S\_AXI\_RDATA \= (axi\_araddr\[ADDR\_LSB+OPT\_MEM\_ADDR\_BITS:ADDR\_LSB\] \== 2'h0) ? slv\_reg0 :   
                     (axi\_araddr\[ADDR\_LSB+OPT\_MEM\_ADDR\_BITS:ADDR\_LSB\] \== 2'h1) ? slv\_reg1 :   
                     (axi\_araddr\[ADDR\_LSB+OPT\_MEM\_ADDR\_BITS:ADDR\_LSB\] \== 2'h2) ? slv\_reg2 :   
                     (axi\_araddr\[ADDR\_LSB+OPT\_MEM\_ADDR\_BITS:ADDR\_LSB\] \== 2'h3) ? slv\_reg3 : 0;  
```
**Modified Code (Do This):**
```Verilog
assign S\_AXI\_RDATA \= (axi\_araddr\[ADDR\_LSB+OPT\_MEM\_ADDR\_BITS:ADDR\_LSB\] \== 2'h0) ? slv\_reg0 :   
                     (axi\_araddr\[ADDR\_LSB+OPT\_MEM\_ADDR\_BITS:ADDR\_LSB\] \== 2'h1) ? slv\_reg0 \+ 32'd1 : // MODIFIED HERE  
                     (axi\_araddr\[ADDR\_LSB+OPT\_MEM\_ADDR\_BITS:ADDR\_LSB\] \== 2'h2) ? slv\_reg2 :   
                     (axi\_araddr\[ADDR\_LSB+OPT\_MEM\_ADDR\_BITS:ADDR\_LSB\] \== 2'h3) ? slv\_reg3 : 0;
```

4. **Save and Close** the file.

### **Part C: Packaging the IP**

Now that the logic is changed, we must "seal" the package.

1. **Check for Errors:**  
   * Look at the **Design Runs** tab (bottom).  
   * Right-click **Synthesis** and choose **Run Synthesis**.  
   * *Checkpoint:* If this fails, you have a syntax error in your Verilog. Fix it before proceeding.  
2. **Package IP:**  
   * Open the **Package IP \- math\_accelerator** tab (usually visible, or open via **Flow Navigator** \> **Package IP**).  
   * Click on **Review and Package**.  
   * Click the **Re-Package IP** button.  
   * Vivado will close the editing window and return to your original dummy project.

### **Part D: The Critical Makefile Fix (Mandatory)**

Vivado 2024.x has a known bug where it generates invalid Makefiles for custom drivers. This **will** cause the Linux build to fail in Step 3 with a syntax error (ildcard). You **must** fix it now in the source so the fix is propagated to PetaLinux.

1. Locate the File:  
   Navigate to your IP repository on your hard drive (Windows Explorer):  
   C:/pynq\_work/ip\_repo/math\_accelerator\_1.0/drivers/math\_accelerator\_v1\_0/src/Makefile  
2. Edit the Makefile:  
   Open it in a text editor (Notepad, VS Code).  
   Find these lines (around line 11-12):  
   LIBSOURCES=($wildcard \*.c)  
   OUTS \= ($wildcard \*.o)

3. Apply the Fix:  
   Move the $ symbol outside the parentheses and simplify the OUTS line:  
   LIBSOURCES=$(wildcard \*.c)  
   OUTS \= \*.o

4. Save and Close.  
   Note: You do not need to do anything else in Vivado. The file is now fixed on disk and will be correctly included when you add this IP to a block design.

## **4\. Final Validation**

Did it work? Let's check the artifact.

1. Open the folder you specified in Part A, Step 3 (e.g., C:/pynq\_work/ip\_repo).  
2. Navigate to math\_accelerator\_1.0.  
3. Ensure you see a component.xml file. This is the descriptor Vivado needs.

## **5\. Recap: What did we just do?**

* **AXI4-Lite Slave:** We created a hardware block that listens to commands from a Master (the CPU).  
* **Register Map:** We defined that Base Address \+ 0 is our input, and Base Address \+ 4 is our output.  
* **Hardware Acceleration:** We implemented an adder (+) in silicon. While adding 1 is trivial, this exact same structure could perform AES encryption, an FFT, or a Neural Network layer just by changing that one line of Verilog code.  
* **Driver Fix:** We patched a known Vivado bug in the driver Makefile to ensure smooth Linux integration later.

**Next Step:** In Step 2, we will pull this new IP into a Vivado Block Design and wire it up to the Zynq Processor.

## **6. Next Step**

We have the brick. Now let's build the house.

**[Go to Step 2: The System Integration](loopback_step2.md)**