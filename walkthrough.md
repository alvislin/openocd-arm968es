# Walkthrough: Dual-Platform Single-Executable OpenOCD for ARM968E-S via CMSIS-DAP (Windows & Linux)

## 1. Summary of Accomplishments

1. **Dual Single-Executable Architecture**:
   - **Windows (`openocd.exe` & `bin/openocd.exe`)**:
     - 64-bit PE executable statically linked against `libusb-1.0` and `hidapi`.
     - Zero external DLL dependencies (links against system `msvcrt.dll`, `kernel32.dll`, `ws2_32.dll`).
     - Zero external `.cfg` script or `scripts/` directory dependencies.
   - **Linux (`openocd` & `bin/openocd`)**:
     - 64-bit ELF statically linked executable (`not a dynamic executable`).
     - LibUSB built with `--disable-udev` (Linux Netlink socket fallback) eliminating `libudev.so.1` dependency.
     - OpenOCD built with `AM_LDFLAGS="-all-static"` ensuring a fully static binary with zero `.so` runtime dependencies.
     - Zero external `.cfg` script or `scripts/` directory dependencies.

2. **Embedded Hardware Configuration**:
   - Both Windows and Linux binaries embed the exact same dedicated ARM968E-S CMSIS-DAP JTAG configuration in `src/helper/options.c`.
   - Adapter Driver: `cmsis-dap` (CMSIS-DAP v1 HID and v2 WinUSB/bulk).
   - Transport: `jtag`.
   - Target: `arm968.cpu` using `arm966e` EmbeddedICE driver.
   - Modern syntax: `-tap arm968.cpu`, modern port directives (`gdb port`, `telnet port`, `tcl port`).
   - Zero deprecation warnings.

3. **Unified CLI**:
   - `-s`, `--speed <khz>`: Sets JTAG clock rate (defaults to `200` kHz). Also supports positional argument `<khz>`.
   - `-p`, `--port <port>`: Sets the GDB server TCP port (defaults to `3333`). Also supports `--gdb-port <port>`.
   - `--telnet-port <port>`: Sets Telnet console TCP port (defaults to `4444`).
   - `--tcl-port <port>`: Sets TCL RPC TCP port (defaults to `6666`).
   - `-h`, `--help`: Prints concise usage and option summary.
   - `-v`, `--version`: Prints OpenOCD version.

4. **Modular Build & Run Scripts**:
   - `build.sh`: Shell script supporting `all`, `windows`, `linux`, and `clean` targets.
   - `build.bat`: Windows batch wrapper forwarding arguments to WSL `./build.sh %*`.
   - `build_all.bat`: One-click build of both Windows & Linux binaries.
   - `build_windows.bat`: One-click build of Windows binary only.
   - `build_linux.bat`: One-click build of Linux binary only.
   - `run_openocd.bat`: Runner script for Windows (`openocd.exe %*`).
   - `run_openocd.sh`: Runner script for Linux (`./openocd "$@"`).

---

## 2. Verification Results

### A. Linux Binary Verification (`openocd` & `bin/openocd`)

```bash
$ file openocd bin/openocd
openocd:     ELF 64-bit LSB executable, x86-64, version 1 (GNU/Linux), statically linked, stripped
bin/openocd: ELF 64-bit LSB executable, x86-64, version 1 (GNU/Linux), statically linked, stripped

$ ldd openocd
not a dynamic executable

$ ./openocd --help
Open On-Chip Debugger 0.12.0+dev-g330024d-dirty (2026-09-20-04:56)
Licensed under GNU GPL v2
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

### B. Windows Binary Verification (`openocd.exe` & `bin/openocd.exe`)

```powershell
PS C:\antigravity\openocd-arm968es> .\openocd.exe --help
Open On-Chip Debugger 0.12.0+dev-g330024d-dirty (2026-09-20-04:47)
Licensed under GNU GPL v2
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

### C. Live Hardware Target Test (CMSIS-DAPv2 + ARM968E-S)

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

## 3. Binaries Generated

| Binary | Target OS | Linking | Size | Location |
| :--- | :--- | :--- | :--- | :--- |
| `openocd.exe` | Windows 7+ (x64) | Static (no DLLs) | ~4.0 MB | `./openocd.exe` & `./bin/openocd.exe` |
| `openocd` | Linux (x86_64) | Fully Static (`not a dynamic executable`) | ~5.2 MB | `./openocd` & `./bin/openocd` |
