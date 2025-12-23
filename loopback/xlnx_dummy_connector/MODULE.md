# Kernel Module Management Guide

## xlnx_dummy_connector Module

The `xlnx_dummy_connector.ko` module provides a simple DRM encoder/connector for the Xilinx DRM subsystem, enabling fixed display modes (720p60) for custom video outputs.

### Module Location

After building the project, the compiled module can be found at:

```
build/tmp/work/zynq_generic_7z020-amd-linux-gnueabi/xlnx-dummy-connector/1.0/image/lib/modules/<kernel-version>/updates/xlnx_dummy_connector.ko
```

**Current kernel version**: `6.12.10-xilinx-g0a0f70e531c7`

**Example path**:
```
build/tmp/work/zynq_generic_7z020-amd-linux-gnueabi/xlnx-dummy-connector/1.0/image/lib/modules/6.12.10-xilinx-g0a0f70e531c7/updates/xlnx_dummy_connector.ko
```

### Finding the Module

```bash
# Find the module in the build directory
find build/tmp/work -name "xlnx_dummy_connector.ko" -type f

# Check if module is installed on target
ssh root@192.168.2.188 "find /lib/modules -name xlnx_dummy_connector.ko"
```

### Copying Module to Target

The module is automatically installed during the root filesystem build. However, if you rebuild just the module, you can manually copy it:

```bash
# Find the module
MODULE=$(find build/tmp/work -name "xlnx_dummy_connector.ko" -type f | head -1)

# Copy to target
scp "$MODULE" root@192.168.2.188:/tmp/

# SSH to target and install
ssh root@192.168.2.188 "
    KVER=\$(uname -r)
    mkdir -p /lib/modules/\$KVER/updates/
    cp /tmp/xlnx_dummy_connector.ko /lib/modules/\$KVER/updates/
    depmod -a
    rm /tmp/xlnx_dummy_connector.ko
"
```

### Manual Loading

```bash
# Load module manually
ssh root@192.168.2.188 "modprobe xlnx_dummy_connector"

# Verify module is loaded
ssh root@192.168.2.188 "lsmod | grep xlnx_dummy_connector"

# Check kernel messages
ssh root@192.168.2.188 "dmesg | tail -20 | grep dummy"
```

Expected output:
```
xlnx_dummy_connector: Dummy connector initialized (720p60)
```

### Automatic Loading (Already Configured)

The module is configured to load automatically on boot via:

**File**: `/etc/modules-load.d/xlnx_dummy_connector.conf`
```
xlnx_dummy_connector
```

This file is installed by the module recipe and ensures the module loads before the display subsystem initializes.

### Verifying Automatic Load

```bash
# Check if config file exists
ssh root@192.168.2.188 "cat /etc/modules-load.d/xlnx_dummy_connector.conf"

# Check if module loaded on boot
ssh root@192.168.2.188 "lsmod | grep xlnx_dummy"

# Verify DRM connector is registered
ssh root@192.168.2.188 "modetest -M xlnx -c" | grep HDMI-A-1
```

### Rebuilding Just the Module

If you modify the module source code, rebuild only the module (faster than full kernel rebuild):

```bash
# Source PetaLinux environment
source /tools/Xilinx/PetaLinux/2025.1/settings.sh

# Clean previous module build
petalinux-build -c xlnx-dummy-connector -x cleansstate

# Rebuild module
petalinux-build -c xlnx-dummy-connector

# Rebuild root filesystem to include updated module
petalinux-build -c rootfs

# Package boot image
petalinux-package --boot --fsbl images/linux/zynq_fsbl.elf \
    --fpga project-spec/hw-description/system_wrapper.bit \
    --u-boot images/linux/u-boot.elf --force
```

### Module Source Location

**Recipe**: `project-spec/meta-user/recipes-modules/xlnx-dummy-connector/xlnx-dummy-connector_1.0.bb`

**Source**: `project-spec/meta-user/recipes-modules/xlnx-dummy-connector/files/xlnx_dummy_connector.c`

**Makefile**: `project-spec/meta-user/recipes-modules/xlnx-dummy-connector/files/Makefile`

**Autoload Config**: `project-spec/meta-user/recipes-modules/xlnx-dummy-connector/files/xlnx_dummy_connector.conf`

### Unloading the Module

```bash
# Remove module
ssh root@192.168.2.188 "modprobe -r xlnx_dummy_connector"

# Note: This will fail if DRM is using it
# You'll need to stop any DRM applications first
ssh root@192.168.2.188 "killall weston X drm-shell 2>/dev/null; modprobe -r xlnx_dummy_connector"
```

### Troubleshooting

**Module not loading automatically:**
```bash
# Check systemd-modules-load service
ssh root@192.168.2.188 "systemctl status systemd-modules-load"

# Manually trigger module load
ssh root@192.168.2.188 "systemctl restart systemd-modules-load"
```

**Module load errors:**
```bash
# Check for dependency issues
ssh root@192.168.2.188 "modinfo xlnx_dummy_connector"

# Check kernel ring buffer for errors
ssh root@192.168.2.188 "dmesg | grep -i 'xlnx\|dummy\|drm'"
```

**Module version mismatch:**
```bash
# Verify module matches kernel version
ssh root@192.168.2.188 "
    KVER=\$(uname -r)
    echo \"Kernel version: \$KVER\"
    modinfo /lib/modules/\$KVER/updates/xlnx_dummy_connector.ko | grep vermagic
"
```

### Quick Reference Commands

```bash
# Check if loaded
ssh root@192.168.2.188 "lsmod | grep xlnx_dummy"

# Load manually
ssh root@192.168.2.188 "modprobe xlnx_dummy_connector"

# Unload
ssh root@192.168.2.188 "modprobe -r xlnx_dummy_connector"

# View module info
ssh root@192.168.2.188 "modinfo xlnx_dummy_connector"

# Check DRM registration
ssh root@192.168.2.188 "ls -l /dev/dri/card0 && modetest -M xlnx -c"
```

## Other Kernel Modules

The same principles apply to any custom kernel modules you create:

1. **Create recipe** in `project-spec/meta-user/recipes-modules/<module-name>/`
2. **Add source files** to `files/` subdirectory
3. **Create Makefile** with `obj-m := <module-name>.o`
4. **Optional**: Create `.conf` file for autoload
5. **Build**: `petalinux-build -c <module-name>`
6. **Install**: Included in rootfs or manually copy to `/lib/modules/$(uname -r)/updates/`
7. **Autoload**: Place config in `/etc/modules-load.d/`
