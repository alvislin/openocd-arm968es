# OpenOCD for ARM968E-S (Windows 7+ x64)

This repository contains the full source code and build system for **OpenOCD** (`0.12.0+dev`) targeting **Windows 7 and up (64-bit)**, configured for debugging **ARM968E-S** cores using **CMSIS-DAP** adapters in JTAG/SWD mode.

---

## 1. Project Structure

- `src/`: OpenOCD source code (C core, targets, JTAG/SWD drivers).
- `tcl/`: OpenOCD official TCL scripts (board, target, interface).
- `scripts/`: Deployed runtime script directory used by `openocd.exe`.
- `jimtcl/`: JimTCL embedded interpreter source.
- `deps/libusb/`: Full source of `libusb-1.0` (compiled statically for CMSIS-DAP v2 WinUSB).
- `deps/hidapi/`: Full source of `hidapi` (compiled statically for CMSIS-DAP v1 HID).
- `arm968es_cmsisdap.cfg`: Target configuration for ARM968E-S over CMSIS-DAP in JTAG mode.
- `openocd.exe` (and `bin/openocd.exe`): 64-bit standalone Windows executable.
- `build.sh`: Bash build script (via MinGW-w64).
- `build.bat`: One-click Windows batch runner to rebuild OpenOCD.
- `run_openocd.bat`: Launch script to run OpenOCD with `arm968es_cmsisdap.cfg`.

---

## 2. Windows 7 Compatibility

- **Target NT Version**: `_WIN32_WINNT=0x0601` (Windows 7).
- **C Runtime**: Linked against standard system `msvcrt.dll` (no UCRT update required on clean Windows 7).
- **Static Dependencies**: `libusb-1.0`, `hidapi`, and `libgcc` are statically linked with no external DLL requirements.
- **Imported DLLs**: Only standard system libraries (`KERNEL32.dll`, `msvcrt.dll`, `USER32.dll`, `WS2_32.dll`).

---

## 3. How to Build

From Windows CMD or PowerShell:
```cmd
build.bat
```

Or from WSL bash:
```bash
./build.sh
```

---

## 4. Configuration (`arm968es_cmsisdap.cfg`)

```tcl
adapter driver cmsis-dap
transport select jtag
adapter speed 200
jtag newtap arm968 cpu -irlen 4 -ircapture 0x1 -irmask 0x0f
target create arm968.cpu arm966e -endian little -chain-position arm968.cpu
reset_config none
```

---

## 5. How to Run

Double-click `run_openocd.bat` or run:
```powershell
.\openocd.exe -s ./scripts -f arm968es_cmsisdap.cfg
```
