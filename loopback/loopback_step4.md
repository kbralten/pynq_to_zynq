# **Loopback Project Step 4: The Software Driver**

## **1\. The Goal**

To write a C application running in Linux user-space that communicates with your custom hardware IP.

We will bypass standard drivers and use **Direct Memory Access** (via /dev/mem) to "poke" the specific physical address where your hardware lives. This effectively proves you can control the FPGA fabric from software.

## **2\. Sanity Check (Pre-Flight)**

Before starting, ensure Step 3 was successful.

* **Board Online:** Your PYNQ-Z2 is powered on and booting the custom Linux image you built.  
* **Network/Console:** You have a way to talk to the board (Serial UART or SSH).  
* **Address Known:** You have the Base Address of your IP from Vivado Step 2 (e.g., 0x43C00000).  
* **Build Environment:** You are on your Linux Host machine with PetaLinux settings sourced.

## **3\. Step-by-Step Instructions**

### **Part A: The Source Code**

We need a C program that maps physical memory into the program's virtual memory space.

1. Create File:  
   On your Linux Host PC (not the board), create a file named loopback\_test.c.  
2. Copy Code:  
   Paste the following code. Note: Change PHY\_ADDR if your address in Vivado was different.  
```C
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>

// The Physical Address from Vivado Address Editor
#define PHY_ADDR 0x43C00000 
// Size of the address range (we only need a few bytes, but 4KB page is standard)
#define MEM_SIZE 4096

int main() {
    int dh;
    void *mapped_base;
    volatile unsigned int *reg_ptr; // Volatile is crucial for hardware registers!

    // 1. Open /dev/mem (Requires Root)
    dh = open("/dev/mem", O_RDWR | O_SYNC);
    if (dh == -1) {
        perror("Error opening /dev/mem. Are you root?");
        return -1;
    }

    // 2. Map Physical Memory to Virtual Memory
    mapped_base = mmap(0, MEM_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, dh, PHY_ADDR);
    if (mapped_base == (void *)-1) {
        perror("Error mapping memory");
        close(dh);
        return -1;
    }

    // 3. Create a pointer to our registers
    reg_ptr = (volatile unsigned int *)mapped_base;

    printf("--- FPGA Loopback Test ---\n");
    printf("Hardware Address: 0x%08x\n", PHY_ADDR);

    // 4. Write to Register 0 (Offset 0)
    unsigned int input_val = 42;
    printf("Writing %d to Register 0...\n", input_val);
    reg_ptr[0] = input_val;

    // 5. Read from Register 1 (Offset 4 bytes = index 1)
    // Recall: Our Verilog logic says Reg1 = Reg0 + 1
    unsigned int output_val = reg_ptr[1];
    printf("Read %d from Register 1.\n", output_val);

    // 6. Validation
    if (output_val == input_val + 1) {
        printf("\n[SUCCESS] Hardware added 1 correctly!\n");
    } else {
        printf("\n[FAIL] Expected %d, got %d. Is the bitstream loaded?\n", input_val + 1, output_val);
    }

    // Cleanup
    munmap(mapped_base, MEM_SIZE);
    close(dh);
    return 0;
}
```

### **Part B: Building the Linux SDK**

To compile code for the Zynq's Linux OS, we need the **Platform SDK**.

**Why do we need this?**
The SDK is a standalone, distributable package containing the cross-compiler (`arm-linux-gnueabi-gcc`) and the system roots (`sysroot`).
*   **Portability:** You can zip this SDK, send it to a software developer on a different team, and they can compile apps for your custom board *without* installing Vivado or PetaLinux.
*   **Consistency:** It ensures everyone compiles against the exact same libraries (glibc, kernel headers) running on the hardware.

1. Build the SDK:  
   Inside your PetaLinux project folder (`loopback_os`), run:  
   ```bash
   petalinux-build --sdk
   ```

   * *Time:* This takes 10-20 minutes. It compiles the entire toolchain and libraries tailored for your board.  
2. Package the Sysroot:  
   This extracts the generated SDK into a usable folder structure.  
   ```bash
   petalinux-package --sysroot
   ```

3. Source the Environment:  
   This is the critical step. It exports the $CC variable and configures the path to the Linux headers (sys/mman.h).  
   ```bash
   source images/linux/sdk/environment-setup-cortexa9t2hf-neon-xilinx-linux-gnueabi
   ```

   * *Verification:* Run `echo $CC`. It should now print a long string starting with `arm-xilinx-linux-gnueabi-gcc ... \--sysroot=....`  
4. Compile:  
   Now we can compile using the standard variable.  
   ```bash
   $CC -o loopback_test loopback_test.c
   ```

5. Verify:  
   Run `file loopback_test`.  
   * *Expected Output:* ELF 32-bit LSB executable, ARM, ...

### **Part C: Deployment**

Transfer the binary to the board.

* **Option 1: SCP (Network)**
  If your board has an IP address (e.g., 192.168.2.99):  
  ```bash
  scp loopback_test petalinux@192.168.2.99:/home/petalinux/
  ```

* **Option 2: SD Card (Windows/WSL Users)**  
  Since Windows cannot read the storage partition (ext4), we use the boot partition (FAT32) as a bridge.
  1. Power off board.  
  2. Put SD card in PC.  
  3. Copy `loopback_test` to the **BOOT** drive (the one Windows opens).  
  4. Boot board and log in.  
  5. Copy the file from the auto-mounted boot partition:  
     ```bash
     # Copy from /boot (PetaLinux automatically mounts the FAT32 partition here)
     cp /boot/loopback_test ~/loopback_test
     
     # Make it executable
     chmod +x ~/loopback_test
     ```

### **Part D: Execution**

1. **Log in** to the board (Serial or SSH).  
2. **Run the App:**  
   ```bash
   # You generally need root privileges to access /dev/mem  
   sudo ./loopback_test
   ```

## **4\. Troubleshooting**

**Error: "Segmentation Fault"**

* **Cause:** You likely accessed a memory address that doesn't exist or isn't clocked.  
* **Check:** Is the Bitstream loaded? If you skipped the \--fpga flag in Step 3, the FPGA fabric is "dead." Accessing dead hardware on AXI usually hangs the CPU or segfaults.  
* **Fix:** Reboot and ensure BOOT.BIN included the bitstream.

**Error: "Read 0 from Register 1"**

* **Cause:** The read worked, but the logic didn't.  
* **Check:** Did you fix the Verilog in Step 1? If you left the default case statement without the \+1 logic, it will just read back 0 (default).

## **5\. Recap: The Full Circle**

Congratulations\! You have completed the full embedded stack.

1. **Hardware:** You designed a custom adder in Verilog.  
2. **Integration:** You wired it to a processor in Vivado.  
3. **System:** You built a custom Linux kernel to host it.  
4. **Software:** You wrote a C application to control it.

This loopback_test program is the foundation of every driver you will ever write. Whether you are controlling a $100,000 radar system or a simple LED, the mechanism (Base Address + Offset) is exactly the same.

## **6. Next Step**

You've built the system, but the development cycle is slow. Let's speed it up.

**[Go to Step 5: Advanced Workflows](loopback_step5.md)**