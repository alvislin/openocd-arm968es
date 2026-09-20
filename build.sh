#!/bin/bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${REPO_ROOT}/build"
PREFIX="${BUILD_DIR}/prefix_x64"

mkdir -p "${BUILD_DIR}" "${PREFIX}"

echo "==================================================="
echo " Building OpenOCD (x64) for Windows 7+"
echo " Target: ARM968E-S with CMSIS-DAP (JTAG/SWD)"
echo " Root:   ${REPO_ROOT}"
echo " Prefix: ${PREFIX}"
echo "==================================================="

# 1. Build static libusb-1.0 (x64)
echo ">>> [1/3] Building static libusb-1.0 (x64)..."
cd "${REPO_ROOT}/deps/libusb"
if [ ! -f configure ]; then
    ./bootstrap.sh
fi
make distclean 2>/dev/null || true
./configure --host=x86_64-w64-mingw32 \
    --prefix="${PREFIX}" \
    --enable-static \
    --disable-shared \
    CFLAGS="-O2 -D_WIN32_WINNT=0x0601" \
    LDFLAGS="-static"
make -j$(nproc)
make install

# 2. Build static hidapi (x64)
echo ">>> [2/3] Building static hidapi (x64)..."
cd "${REPO_ROOT}/deps/hidapi"
if [ ! -f configure ]; then
    ./bootstrap
fi
make distclean 2>/dev/null || true
./configure --host=x86_64-w64-mingw32 \
    --prefix="${PREFIX}" \
    --enable-static \
    --disable-shared \
    CFLAGS="-O2 -D_WIN32_WINNT=0x0601" \
    LDFLAGS="-static"
make -j$(nproc)
make install

# 3. Build OpenOCD (x64)
echo ">>> [3/3] Building OpenOCD (x64)..."
cd "${REPO_ROOT}"
if [ ! -f configure ]; then
    ./bootstrap
fi
make distclean 2>/dev/null || true

export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig"

./configure --host=x86_64-w64-mingw32 \
    --enable-internal-jimtcl \
    --enable-cmsis-dap \
    --enable-cmsis-dap-v2 \
    --disable-werror \
    CFLAGS="-O2 -D_WIN32_WINNT=0x0601" \
    LDFLAGS="-static -static-libgcc" \
    LIBS="-lsetupapi"

make -j$(nproc)

mkdir -p "${REPO_ROOT}/bin"
cp -f src/openocd.exe "${REPO_ROOT}/openocd.exe"
cp -f src/openocd.exe "${REPO_ROOT}/bin/openocd.exe"

# Copy updated scripts to scripts/ directory
mkdir -p "${REPO_ROOT}/scripts"
cp -rf tcl/* "${REPO_ROOT}/scripts/"

echo "==================================================="
echo " Build successful!"
echo " Updated: openocd.exe and bin/openocd.exe"
echo "==================================================="
