# Walkthrough: Dedicated Single-Executable OpenOCD for ARM968E-S via CMSIS-DAP

## 1. Summary of Enhancements

1. **Dedicated Single Executable**:
   - `openocd.exe` is now fully self-contained. It embeds the fixed hardware configuration for **ARM968E-S** debugging with **CMSIS-DAP** over **JTAG** in C code, eliminating any reliance on external script files or the `scripts/` directory.
   - Verified that `openocd.exe` can run in an isolated, empty directory with zero dependencies.

2. **Command-Line Options**:
   - `-s`, `--speed <khz>`: Sets JTAG clock rate (defaults to `200` kHz). Also supports positional argument `openocd.exe <khz>`.
   - `-p`, `--port <port>`: Sets the GDB server TCP port (defaults to `3333`). Also supports `--gdb-port <port>`.
   - `--telnet-port <port>`: Sets Telnet console TCP port (defaults to `4444`).
   - `--tcl-port <port>`: Sets TCL RPC TCP port (defaults to `6666`).
   - `-h`, `--help`: Prints a concise, user-friendly help message.
   - `-v`, `--version`: Prints version information.

3. **Deprecation Warnings Fixed**:
   - Replaced deprecated `-chain-position arm968.cpu` with `-tap arm968.cpu`.
   - Replaced deprecated port commands `gdb_port`, `telnet_port`, `tcl_port` with `gdb port`, `telnet port`, `tcl port`.
   - Result: **Zero deprecation warnings** on startup.

---

## 2. Hardware Test Results

The executable was tested against live hardware (CMSIS-DAPv2 debugger and ARM968E-S target board):

```text
PS C:\antigravity\openocd-arm968es> .\openocd.exe -s 500 -p 3333
Open On-Chip Debugger 0.12.0+dev-snapshot (2026-09-20-04:06)
Licensed under GNU GPL v2
For bug reports, read
	http://openocd.org/doc/doxygen/bugs.html
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

## 3. Git Commits

All changes, including the updated code, binary, and documentation, are committed cleanly in the repository:
- `src/helper/options.c` (Dedicated single-executable option parser & embedded ARM968E-S config)
- `arm968es_cmsisdap.cfg` (Updated to `-tap arm968.cpu`)
- `openocd.exe` & `bin/openocd.exe` (Recompiled single-executable binaries)
- `run_openocd.bat`, `README.md`, and `walkthrough.md`
