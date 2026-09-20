# OpenOCD for ARM968E-S (Standalone Single Executable)

A dedicated, standalone single-executable build of **OpenOCD** (`0.12.0+dev`) targeting **Windows 7 and up (64-bit)**, pre-configured specifically for debugging **ARM968E-S** cores using **CMSIS-DAP** adapters over JTAG.

---

## 1. Features

- **Single Self-Contained Executable**: `openocd.exe` does not require any external configuration files or script directories (`scripts/` folder is not required).
- **Embedded Hardware Configuration**:
  - Adapter Driver: `cmsis-dap` (supports both CMSIS-DAP v1 HID and v2 WinUSB/bulk)
  - Transport: `jtag`
  - Target: `arm968.cpu` using `arm966e` EmbeddedICE driver
  - TAP: `arm968.cpu` (`-irlen 4 -ircapture 0x1 -irmask 0x0f`)
  - Reset Config: `none`
- **Zero Warnings**: Uses modern `-tap` parameter syntax and modern port directives (`gdb port`, `telnet port`, `tcl port`).
- **Windows 7+ Compatible**: Statically linked against standard `msvcrt.dll`, `libusb-1.0`, and `hidapi`. No external DLLs needed.

---

## 2. Command-Line Options

```
Usage: openocd.exe [options]

Options:
  -s, --speed <khz>        JTAG clock rate in kHz (default: 200)
  -p, --port <port>        GDB server TCP port (default: 3333)
      --gdb-port <port>    GDB server TCP port (default: 3333)
      --telnet-port <port> Telnet console TCP port (default: 4444)
      --tcl-port <port>    TCL RPC TCP port (default: 6666)
  -h, --help               Display this help message
  -v, --version            Display OpenOCD version
```

### Examples:
```powershell
# 1. Run with default 200 kHz and default port 3333:
.\openocd.exe

# 2. Run with 500 kHz JTAG clock:
.\openocd.exe -s 500

# 3. Run with custom GDB port (e.g., 2331):
.\openocd.exe -p 2331

# 4. Run with both custom speed and port:
.\openocd.exe -s 1000 -p 3333
```

---

## 3. How to Build From Source

To rebuild the single executable from the in-tree sources:

### From Windows:
Double-click `build.bat` or run:
```cmd
build.bat
```

### From WSL Bash:
```bash
./build.sh
```

---

## 4. Connecting GDB / Telnet

- **GDB Port**: `localhost:<port>` (default: `localhost:3333`)
  ```bash
  arm-none-eabi-gdb -ex "target remote localhost:3333"
  ```
- **Telnet Console**: `localhost:4444`
  ```bash
  telnet localhost 4444
  ```
