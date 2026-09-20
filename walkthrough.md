# Walkthrough: OpenOCD x64 Source Integration and Build for Windows 7+

## 1. Summary of Completed Work

1. **Windows 7+ x64 Compatibility**:
   - Built with `-D_WIN32_WINNT=0x0601` (Windows 7 target).
   - Core C runtime links against standard `msvcrt.dll` (pre-installed on all Windows 7 systems; no Universal CRT update required).
   - `libusb-1.0` (for CMSIS-DAP v2 WinUSB/bulk) and `hidapi` (for CMSIS-DAP v1 HID) are statically embedded with no third-party DLL dependencies.
   - Verified that the binary imports only standard core Windows libraries:
     - `KERNEL32.dll`
     - `msvcrt.dll`
     - `USER32.dll`
     - `WS2_32.dll`

2. **Full Source Tree Integration at Repository Root**:
   - OpenOCD source files placed directly at the repository root (`src/`, `tcl/`, `jimtcl/`, `configure.ac`, `Makefile.am`, etc.) so future enhancements (e.g. for ARM968E-S target, flash, or custom commands) can be edited and committed directly.
   - Embedded dependencies placed under `deps/`:
     - `deps/libusb/`: Full source of `libusb-1.0`.
     - `deps/hidapi/`: Full source of `hidapi`.

3. **Automated In-Tree Build System**:
   - `build.sh`: Self-contained Bash script that compiles static `libusb` and `hidapi`, configures OpenOCD with internal JimTCL, and compiles `openocd.exe`.
   - `build.bat`: One-click Windows runner to trigger the build from Windows CMD/PowerShell via WSL.

4. **ARM968E-S Target Configuration**:
   - `arm968es_cmsisdap.cfg`: OpenOCD configuration tailored for ARM968E-S debugging using CMSIS-DAP in JTAG mode:
     ```tcl
     adapter driver cmsis-dap
     transport select jtag
     adapter speed 200
     jtag newtap arm968 cpu -irlen 4 -ircapture 0x1 -irmask 0x0f
     target create arm968.cpu arm966e -endian little -chain-position arm968.cpu
     reset_config none
     ```
   - `run_openocd.bat`: Launch script to start OpenOCD with the configuration.

---

## 2. Verification

### Native Windows Execution Test
```powershell
PS C:\antigravity\openocd-arm968es> .\openocd.exe -v
Open On-Chip Debugger 0.12.0+dev-snapshot (2026-09-20-04:06)
Licensed under GNU GPL v2
For bug reports, read
	http://openocd.org/doc/doxygen/bugs.html
```

### Config & Driver Test
```powershell
PS C:\antigravity\openocd-arm968es> .\openocd.exe -s ./scripts -f arm968es_cmsisdap.cfg -c "cmsis-dap backend hid"
Open On-Chip Debugger 0.12.0+dev-snapshot (2026-09-20-04:06)
Licensed under GNU GPL v2
Info : Listening on port 6666 for tcl connections
Info : Listening on port 4444 for telnet connections
Error: unable to find a matching CMSIS-DAP device
```

### Git Repository Status
```powershell
PS C:\antigravity\openocd-arm968es> git status
On branch master
nothing to commit, working tree clean
```
