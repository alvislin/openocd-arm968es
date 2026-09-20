# OpenOCD for ARM968E-S (Standalone Single Executables)

Dedicated, standalone single-executable builds of **OpenOCD** (`0.12.0+dev`) for both **Windows (64-bit)** and **Linux (x86_64)**, pre-configured specifically for debugging **ARM968E-S** cores using **CMSIS-DAP** adapters over JTAG.

---

## 1. Features

- **Single Self-Contained Executables**:
  - Windows: `openocd.exe` and `bin/openocd.exe` (statically linked PE x64 executable, no external DLLs or runtime files required).
  - Linux: `openocd` and `bin/openocd` (statically linked ELF x86_64 executable, `not a dynamic executable`, zero `.so` or `libudev` dependencies).
  - Zero runtime dependencies: No external `.cfg` scripts or `scripts/` directory needed.
- **Embedded Hardware Configuration**:
  - Adapter Driver: `cmsis-dap` (supports both CMSIS-DAP v1 HID and v2 WinUSB/bulk)
  - Transport: `jtag`
  - Target: `arm968.cpu` using `arm966e` EmbeddedICE driver
  - TAP: `arm968.cpu` (`-irlen 4 -ircapture 0x1 -irmask 0x0f`)
  - Reset Config: `none`
- **Zero Warnings**: Uses modern `-tap` parameter syntax and modern port directives (`gdb port`, `telnet port`, `tcl port`).
- **Custom Fast CLI**: Direct `-s/--speed` and `-p/--port` flags without having to deal with TCL expressions or long OpenOCD options.

---

## 2. Command-Line Options

```
Usage: openocd [options] (or openocd.exe [options])

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

#### On Windows:
```cmd
:: 1. Run with default 200 kHz and default port 3333
openocd.exe
:: or using the runner script:
run_openocd.bat

:: 2. Run with 500 kHz JTAG clock
openocd.exe -s 500

:: 3. Run with custom GDB port (e.g., 2331)
openocd.exe -p 2331

:: 4. Run with both custom speed and port
openocd.exe -s 1000 -p 3333
```

#### On Linux:
```bash
# 1. Run with default 200 kHz and default port 3333
./openocd
# or using the runner script:
./run_openocd.sh

# 2. Run with 500 kHz JTAG clock
./openocd -s 500

# 3. Run with custom GDB port (e.g., 2331)
./openocd -p 2331

# 4. Run with both custom speed and port
./openocd -s 1000 -p 3333
```

---

## 3. How to Build From Source

### Building on Windows (via WSL2):
Convenience scripts are provided in the root directory:
- **Build Both (Windows & Linux)**:
  - Double-click `build_all.bat` or run: `build.bat all`
- **Build Windows Only**:
  - Double-click `build_windows.bat` or run: `build.bat windows`
- **Build Linux Only**:
  - Double-click `build_linux.bat` or run: `build.bat linux`
- **Clean Build Artifacts**:
  - Run: `build.bat clean`

### Building in Linux / WSL Bash:
```bash
# Build both Windows and Linux single binaries:
./build.sh all

# Build Windows only:
./build.sh windows

# Build Linux only:
./build.sh linux

# Clean:
./build.sh clean
```

All built binaries are automatically copied to both the project root and `bin/` directory:
- `openocd.exe` & `bin/openocd.exe` (Windows 64-bit standalone)
- `openocd` & `bin/openocd` (Linux x86_64 standalone)

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
