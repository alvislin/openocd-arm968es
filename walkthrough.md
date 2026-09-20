# Walkthrough: Dual-Platform Single-Executable OpenOCD for ARM968E-S via CMSIS-DAP (Windows & Linux)

## 1. Overview & Objectives

The goal was to build dedicated, standalone, single-executable binaries of **OpenOCD** (`0.12.0+dev`) for both **Windows (64-bit)** and **Linux (x86_64)**, pre-configured specifically for debugging **ARM968E-S** processor cores using **CMSIS-DAP** adapters over **JTAG**.

### Key Requirements Met:
- **No External Dependencies at Runtime**:
  - Zero `.cfg` configuration files or `scripts/` directory needed.
  - Windows: Single `openocd.exe` statically linked against `libusb-1.0` and `hidapi`; requires only core Windows system DLLs (`msvcrt.dll`, `kernel32.dll`, `ws2_32.dll`).
  - Linux: Single `openocd` ELF binary completely statically linked (`not a dynamic executable`); zero `.so` runtime dependencies and zero `libudev.so.1` dependency.
- **Embedded Hardware Configuration**:
  - Driver: `cmsis-dap` (CMSIS-DAP v1 HID and v2 WinUSB/bulk)
  - Transport: `jtag`
  - Target: `arm968.cpu` (`arm966e` EmbeddedICE driver)
  - TAP: `arm968.cpu` (`-irlen 4 -ircapture 0x1 -irmask 0x0f`)
  - Reset Config: `none`
  - Zero deprecation warnings on startup (modern `-tap` syntax and modern port directives).
- **Custom Fast CLI Options**:
  - `-s, --speed <khz>`: JTAG clock speed in kHz (default: `200`).
  - `-p, --port <port>`: GDB TCP port (default: `3333`).
  - Custom options for Telnet (`--telnet-port 4444`) and TCL (`--tcl-port 6666`).
- **Complete Dual-Platform Build Automation**:
  - Linux/WSL: Modular `build.sh` supporting `all`, `windows`, `linux`, `clean`.
  - Windows: `build.bat`, `build_all.bat`, `build_windows.bat`, `build_linux.bat`.
  - Launchers: `run_openocd.bat` (Windows) and `run_openocd.sh` (Linux).

---

## 2. Technical Implementation Details

### A. Embedded C Configuration & CLI Parser
In [src/helper/options.c](file:///c:/antigravity/openocd-arm968es/src/helper/options.c), custom argument parsing interceptor handles `-s/--speed` and `-p/--port`:
```c
/* Inject embedded configuration for ARM968E-S CMSIS-DAP JTAG */
add_default_dirs();

/* 1. Interface & Transport */
command_run_line(CMD_CTX, "adapter driver cmsis-dap");
command_run_line(CMD_CTX, "transport select jtag");

/* 2. Clock speed & Ports */
char cmd[64];
snprintf(cmd, sizeof(cmd), "adapter speed %u", jtag_speed_khz);
command_run_line(CMD_CTX, cmd);
snprintf(cmd, sizeof(cmd), "gdb port %u", gdb_port);
command_run_line(CMD_CTX, cmd);
snprintf(cmd, sizeof(cmd), "telnet port %u", telnet_port);
command_run_line(CMD_CTX, cmd);
snprintf(cmd, sizeof(cmd), "tcl port %u", tcl_port);
command_run_line(CMD_CTX, cmd);

/* 3. Reset Configuration */
command_run_line(CMD_CTX, "reset_config none");

/* 4. TAP & Target definition */
command_run_line(CMD_CTX, "jtag newtap arm968 cpu -irlen 4 -ircapture 0x1 -irmask 0x0f");
command_run_line(CMD_CTX, "target create arm968.cpu arm966e -endian little -tap arm968.cpu");
```

### B. Linux Static Linking Architecture
To produce an ELF binary that runs on any x86_64 Linux machine without missing library errors:
1. **Eliminating `libudev.so.1`**:
   - `deps/libusb` is configured with `--disable-udev`. LibUSB compiles `linux_netlink.c`, allowing USB hotplug and device enumeration directly through Linux Netlink sockets, removing any link or runtime dependency on `libudev`.
   - `deps/hidapi` builds `libhidapi-libusb.a` (which uses pure libusb) rather than `libhidapi-hidraw.a` (which links `libudev`).
2. **Eliminating Dynamic `.so` Dependencies**:
   - OpenOCD is linked with `make AM_LDFLAGS="-all-static"`.
   - Passing `AM_LDFLAGS` to `make` instructs Libtool to link the final `openocd` binary with `-static`, while avoiding compiler errors in JimTCL host tools (`jimsh`).
   - Result: `not a dynamic executable`.

### C. Windows MinGW-w64 Cross-Compilation
- Uses `x86_64-w64-mingw32-gcc` with `-D_WIN32_WINNT=0x0601` (Windows 7+ compatibility).
- Links statically against `libusb-1.0.a` and `libhidapi.a` with `-static -static-libgcc`.
- Requires only built-in Windows system DLLs (`msvcrt.dll`, `kernel32.dll`, `ws2_32.dll`, `setupapi.dll`).

---

## 3. Verification & Test Results

### A. Linux Standalone Binary Verification

```bash
$ file openocd bin/openocd
openocd:     ELF 64-bit LSB executable, x86-64, version 1 (GNU/Linux), statically linked, stripped
bin/openocd: ELF 64-bit LSB executable, x86-64, version 1 (GNU/Linux), statically linked, stripped

$ ldd openocd
not a dynamic executable

$ ./openocd --help
Open On-Chip Debugger 0.12.0+dev-g330024d-dirty (2026-09-20-04:56)
Licensed under GNU GPL v2
For bug reports, read
	http://openocd.org/doc/doxygen/bugs.html
Open On-Chip Debugger (ARM968E-S CMSIS-DAP Dedicated Build)
Usage: ./openocd [options]

Options:
  -s, --speed <khz>        JTAG clock rate in kHz (default: 200)
  -p, --port <port>        GDB server TCP port (default: 3333)
      --gdb-port <port>    GDB server TCP port (default: 3333)
      --telnet-port <port> Telnet console TCP port (default: 4444)
      --tcl-port <port>    TCL RPC TCP port (default: 6666)
  -h, --help               Display this help message
  -v, --version            Display OpenOCD version
```

### B. Windows Standalone Binary Verification

```powershell
PS C:\antigravity\openocd-arm968es> .\openocd.exe --help
Open On-Chip Debugger 0.12.0+dev-g330024d-dirty (2026-09-20-04:47)
Licensed under GNU GPL v2
For bug reports, read
	http://openocd.org/doc/doxygen/bugs.html
Open On-Chip Debugger (ARM968E-S CMSIS-DAP Dedicated Build)
Usage: C:\antigravity\openocd-arm968es\openocd.exe [options]

Options:
  -s, --speed <khz>        JTAG clock rate in kHz (default: 200)
  -p, --port <port>        GDB server TCP port (default: 3333)
      --gdb-port <port>    GDB server TCP port (default: 3333)
      --telnet-port <port> Telnet console TCP port (default: 4444)
      --tcl-port <port>    TCL RPC TCP port (default: 6666)
  -h, --help               Display this help message
  -v, --version            Display OpenOCD version
```

### C. Live Hardware Test (CMSIS-DAPv2 + ARM968E-S Target)

```text
PS C:\antigravity\openocd-arm968es> .\openocd.exe -s 500 -p 3333
Open On-Chip Debugger 0.12.0+dev-snapshot (2026-09-20-04:06)
Licensed under GNU GPL v2
Info : ARM968E-S CMSIS-DAP debugger: JTAG clock 500 kHz, GDB TCP port 3333
adapter speed: 500 kHz
none separate
Info : Listening on port 6666 for tcl connections
Info : Listening on port 4444 for telnet connections
Info : Using CMSIS-DAPv2 interface with VID:PID=0x1366:0x1080, serial=000601000179
Info : CMSIS-DAP: SWD supported
Info : CMSIS-DAP: JTAG supported
Info : CMSIS-DAP: SWO-UART supported
Info : CMSIS-DAP: FW Version = 2.0
Info : CMSIS-DAP: Interface Initialised (JTAG)
Info : SWCLK/TCK = 1 SWDIO/TMS = 0 TDI = 0 TDO = 0 nTRST = 1 nRESET = 0
Info : CMSIS-DAP: Interface ready
Info : clock speed 500 kHz
Info : JTAG tap: arm968.cpu tap/device found: 0x15968001 (mfg: 0x000 (<invalid>), part: 0x5968, ver: 0x1)
Info : Embedded ICE version 6
Info : arm968.cpu: hardware has 2 breakpoint/watchpoint units
Info : [arm968.cpu] Examination succeed
Info : [arm968.cpu] starting gdb server on 3333
Info : Listening on port 3333 for gdb connections
```

---

## 4. Artifacts & Deliverables Summary

| Artifact | Description | Size | Location |
| :--- | :--- | :--- | :--- |
| **`openocd.exe`** | Windows 64-bit standalone executable | ~4.0 MB | [openocd.exe](file:///c:/antigravity/openocd-arm968es/openocd.exe), [bin/openocd.exe](file:///c:/antigravity/openocd-arm968es/bin/openocd.exe) |
| **`openocd`** | Linux x86_64 fully static standalone executable | ~5.2 MB | [openocd](file:///c:/antigravity/openocd-arm968es/openocd), [bin/openocd](file:///c:/antigravity/openocd-arm968es/bin/openocd) |
| **`build.sh`** | Bash build script (`all`, `windows`, `linux`, `clean`) | - | [build.sh](file:///c:/antigravity/openocd-arm968es/build.sh) |
| **`build.bat`** | Windows batch wrapper forwarding to WSL | - | [build.bat](file:///c:/antigravity/openocd-arm968es/build.bat) |
| **`build_all.bat`** | Windows 1-click batch build for all targets | - | [build_all.bat](file:///c:/antigravity/openocd-arm968es/build_all.bat) |
| **`build_windows.bat`** | Windows 1-click batch build for Windows only | - | [build_windows.bat](file:///c:/antigravity/openocd-arm968es/build_windows.bat) |
| **`build_linux.bat`** | Windows 1-click batch build for Linux only | - | [build_linux.bat](file:///c:/antigravity/openocd-arm968es/build_linux.bat) |
| **`run_openocd.bat`** | Windows runner script | - | [run_openocd.bat](file:///c:/antigravity/openocd-arm968es/run_openocd.bat) |
| **`run_openocd.sh`** | Linux runner script | - | [run_openocd.sh](file:///c:/antigravity/openocd-arm968es/run_openocd.sh) |
| **`README.md`** | User & developer documentation | - | [README.md](file:///c:/antigravity/openocd-arm968es/README.md) |
| **`walkthrough.md`** | Complete verification & architecture walkthrough | - | [walkthrough.md](file:///c:/antigravity/openocd-arm968es/walkthrough.md) |
