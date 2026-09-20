# OpenOCD for ARM968E-S (Windows 7+ Compatible)

This package contains statically linked, standalone Windows builds of OpenOCD (`0.12.0+dev`) targeted for **Windows 7 and up** (Windows 7 / 8 / 10 / 11), specifically tailored for debugging **ARM968E-S** cores using **CMSIS-DAP** adapters over JTAG.

---

## 1. Directory Structure

- `openocd.exe` (and `bin/openocd.exe`): 64-bit native Windows executable.
- `openocd-x86.exe` (and `bin/openocd-x86.exe`): 32-bit native Windows executable (compatible with 32-bit and 64-bit Windows 7+).
- `scripts/`: Official OpenOCD TCL scripts (interfaces, targets, boards).
- `arm968es_cmsisdap.cfg`: OpenOCD configuration tailored for ARM968E-S over CMSIS-DAP in JTAG mode.
- `run_openocd.bat`: Launch script for 64-bit OpenOCD.
- `run_openocd_x86.bat`: Launch script for 32-bit OpenOCD.

---

## 2. Windows 7 Compatibility Details

- **Target NT Version**: Compiled with `_WIN32_WINNT=0x0601` (Windows 7).
- **C Runtime**: Linked against standard system `msvcrt.dll` (no UCRT runtime update required on clean Windows 7).
- **Static Dependencies**: `libusb-1.0`, `hidapi`, and `libgcc` are statically linked into the binary.
- **Imported DLLs**: Only standard core Windows libraries (`KERNEL32.dll`, `msvcrt.dll`, `USER32.dll`, `WS2_32.dll`).

---

## 3. Configuration File (`arm968es_cmsisdap.cfg`)

```tcl
# 1. 介面驅動設定
adapter driver cmsis-dap
transport select jtag

# 2. JTAG 時脈設定
# ARM968E-S 開機時脈如果較慢，建議先給 200kHz
adapter speed 200

# 3. 定義 JTAG TAP 節點
# 預設 ARM968E-S TAP ID 範例：0x05968093 或 0x15968093
jtag newtap arm968 cpu -irlen 4 -ircapture 0x1 -irmask 0x0f

# 4. 建立 Target (ARM968E-S 使用 arm966e 驅動處理 EmbeddedICE)
target create arm968.cpu arm966e -endian little -chain-position arm968.cpu

# 5. Reset 組態設定
# 若有接硬體 Reset 腳位，可改用：reset_config trst_and_srst
reset_config none
```

### CMSIS-DAP Backend Notes:
- **CMSIS-DAP v1 (HID)**: Supported via built-in HIDAPI. Works on Windows 7 **without installing any third-party drivers** (native Windows HID driver).
  To force HID mode:
  ```tcl
  cmsis-dap backend hid
  ```
- **CMSIS-DAP v2 (WinUSB / bulk)**: Supported via built-in libusb-1.0. On Windows 7, if using CMSIS-DAP v2, ensure the WinUSB driver is assigned to the device (e.g., via Zadig).
  To force WinUSB bulk mode:
  ```tcl
  cmsis-dap backend usb_bulk
  ```

---

## 4. How to Run

### Via Batch File
Double-click `run_openocd.bat` (or `run_openocd_x86.bat`).

### Via Command Line
```powershell
.\openocd.exe -s ./scripts -f arm968es_cmsisdap.cfg
```

---

## 5. Connecting GDB / Telnet

Once OpenOCD connects to your target board:
- **GDB Port**: `localhost:3333`
  ```bash
  arm-none-eabi-gdb -ex "target remote localhost:3333"
  ```
- **Telnet Console**: `localhost:4444`
  ```bash
  telnet localhost 4444
  ```
- **TCL RPC**: `localhost:6666`
