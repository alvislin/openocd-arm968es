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

## 3. How Windows & Linux Builds Are Performed Using WSL

WSL (Windows Subsystem for Linux, Ubuntu 24.04 LTS) is used as the **unified build hub** to compile both the Windows 64-bit executable and the Linux x86_64 executable. This architecture guarantees reproducible, dependency-isolated builds while providing single-click convenience from Windows.

### A. Environment Architecture

```
+-----------------------------------------------------------------------------------------+
|                                    WINDOWS HOST                                         |
|                                                                                         |
|   Workspace: C:\antigravity\openocd-arm968es                                            |
|   One-Click Batch Scripts: build_windows.bat | build_linux.bat | build_all.bat              |
|                                     |                                                   |
|                        Calls wsl.exe -u root bash -c "..."                              |
|                                     v                                                   |
|   +---------------------------------------------------------------------------------+   |
|   |                         WSL2 (Ubuntu 24.04 LTS)                                 |   |
|   |   Mounted at: /mnt/c/antigravity/openocd-arm968es                               |   |
|   |   Build Script: ./build.sh [windows | linux | all | clean]                      |   |
|   |                                                                                 |   |
|   |   +---------------------------------+   +-----------------------------------+   |   |
|   |   |        WINDOWS TARGET           |   |           LINUX TARGET            |   |   |
|   |   | Toolchain: x86_64-w64-mingw32-  |   | Toolchain: native gcc (Ubuntu)    |   |   |
|   |   | Target: Windows 7+ x64          |   | Target: Linux x86_64 (glibc/musl) |   |   |
|   |   | Output: build/prefix_win64/     |   | Output: build/prefix_linux64/     |   |   |
|   |   |         openocd.exe (PE 64-bit) |   |         openocd (ELF 64-bit)      |   |   |
|   |   +---------------------------------+   +-----------------------------------+   |   |
|   +---------------------------------------------------------------------------------+   |
|                                     |                                                   |
|         Outputs written directly to Windows workspace (bin/ and root)                   |
|                                     v                                                   |
|   openocd.exe & bin/openocd.exe           openocd & bin/openocd                         |
|   (Ready for Windows CMD/PowerShell)      (Ready for Linux / WSL deployment)            |
+-----------------------------------------------------------------------------------------+
```

### B. Windows Build Flow via WSL (MinGW-w64 Cross-Compilation)

When `./build.sh windows` (or `build_windows.bat`) is executed:

1. **Clean & Isolate**:
   The build script ensures tree cleanliness (`make distclean 2>/dev/null || true`) and sets up an isolated prefix directory `build/prefix_win64`.
2. **Cross-Compiling LibUSB**:
   ```bash
   cd deps/libusb
   ./configure --host=x86_64-w64-mingw32 --prefix="${PREFIX_WIN}" \
               --enable-static --disable-shared
   make -j$(nproc) && make install
   ```
   This produces `build/prefix_win64/lib/libusb-1.0.a` without any Linux socket or udev code.
3. **Cross-Compiling HIDAPI**:
   ```bash
   cd deps/hidapi
   ./configure --host=x86_64-w64-mingw32 --prefix="${PREFIX_WIN}" \
               --enable-static --disable-shared
   make -j$(nproc) && make install
   ```
   On Windows/MinGW, HIDAPI compiles `windows/hid.c`, interfacing directly with Windows `hid.dll` and `setupapi.dll`.
4. **Configuring & Linking OpenOCD for Windows**:
   ```bash
   export PKG_CONFIG_PATH="${PREFIX_WIN}/lib/pkgconfig"
   ./configure --host=x86_64-w64-mingw32 \
               --prefix="${PREFIX_WIN}" \
               --enable-cmsis-dap \
               CFLAGS="-O2 -D_WIN32_WINNT=0x0601" \
               LDFLAGS="-static -static-libgcc -L${PREFIX_WIN}/lib" \
               LIBUSB1_CFLAGS="-I${PREFIX_WIN}/include/libusb-1.0" \
               LIBUSB1_LIBS="-L${PREFIX_WIN}/lib -lusb-1.0" \
               HIDAPI_CFLAGS="-I${PREFIX_WIN}/include/hidapi" \
               HIDAPI_LIBS="-L${PREFIX_WIN}/lib -lhidapi -lsetupapi"
   make -j$(nproc)
   ```
5. **Strip and Publish**:
   The binary is stripped using `x86_64-w64-mingw32-strip -s src/openocd.exe` and copied to both `openocd.exe` and `bin/openocd.exe`.

---

### C. Linux Build Flow via WSL (Native Static Compilation)

When `./build.sh linux` (or `build_linux.bat`) is executed:

1. **Clean & Isolate**:
   Cleans tree and sets up isolated prefix `build/prefix_linux64`.
2. **Compiling LibUSB (Netlink Mode)**:
   ```bash
   cd deps/libusb
   ./configure --prefix="${PREFIX_LINUX}" \
               --enable-static --disable-shared --disable-udev
   make -j$(nproc) && make install
   ```
   **Crucial detail**: `--disable-udev` directs LibUSB to use Linux Netlink sockets (`linux_netlink.c`), eliminating the dependency on `libudev.so.1`.
3. **Compiling HIDAPI (Libusb Backend)**:
   ```bash
   cd deps/hidapi
   ./configure --prefix="${PREFIX_LINUX}" \
               --enable-static --disable-shared
   make -j$(nproc) && make install
   cp -f "${PREFIX_LINUX}/lib/pkgconfig/hidapi-libusb.pc" "${PREFIX_LINUX}/lib/pkgconfig/hidapi.pc"
   rm -f "${PREFIX_LINUX}/lib/pkgconfig/hidapi-hidraw.pc"
   ```
   Forces OpenOCD to link against `libhidapi-libusb.a` rather than `libhidapi-hidraw.a`, further ensuring `libudev` is not introduced.
4. **Configuring & Linking OpenOCD for Linux**:
   ```bash
   export PKG_CONFIG_PATH="${PREFIX_LINUX}/lib/pkgconfig"
   ./configure --prefix="${PREFIX_LINUX}" \
               --enable-cmsis-dap \
               CFLAGS="-O2" \
               LDFLAGS="-L${PREFIX_LINUX}/lib" \
               LIBUSB1_CFLAGS="-I${PREFIX_LINUX}/include/libusb-1.0" \
               LIBUSB1_LIBS="-L${PREFIX_LINUX}/lib -lusb-1.0" \
               HIDAPI_CFLAGS="-I${PREFIX_LINUX}/include/hidapi" \
               HIDAPI_LIBS="-L${PREFIX_LINUX}/lib -lhidapi-libusb"
   make -j$(nproc) AM_LDFLAGS="-all-static"
   ```
   **Crucial detail**: Passing `AM_LDFLAGS="-all-static"` to `make` instructs Libtool to link the final executable with `-static` without breaking JimTCL's host tools (`jimsh`), yielding a 100% statically linked ELF binary.
5. **Strip and Publish**:
   The binary is stripped using `strip -s src/openocd` and copied to both `openocd` and `bin/openocd`.

---

### D. Windows-to-WSL Bridge Scripts

To provide a seamless experience on Windows, batch wrappers forward execution directly into WSL:

- [build_all.bat](file:///c:/antigravity/openocd-arm968es/build_all.bat):
  ```cmd
  @echo off
  wsl -u root bash -c "cd /mnt/c/antigravity/openocd-arm968es && chmod +x build.sh && ./build.sh all"
  pause
  ```
- [build_windows.bat](file:///c:/antigravity/openocd-arm968es/build_windows.bat):
  ```cmd
  @echo off
  wsl -u root bash -c "cd /mnt/c/antigravity/openocd-arm968es && chmod +x build.sh && ./build.sh windows"
  pause
  ```
- [build_linux.bat](file:///c:/antigravity/openocd-arm968es/build_linux.bat):
  ```cmd
  @echo off
  wsl -u root bash -c "cd /mnt/c/antigravity/openocd-arm968es && chmod +x build.sh && ./build.sh linux"
  pause
  ```

---

## 4. Verification & Test Results

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

## 5. Artifacts & Deliverables Summary

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
