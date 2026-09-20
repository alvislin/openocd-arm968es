#!/bin/bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${REPO_ROOT}/build"
PREFIX_X64="${BUILD_DIR}/prefix_x64"
PREFIX_X86="${BUILD_DIR}/prefix_x86"

ARCH="${1:-all}" # "x64", "x86", or "all"

echo "==================================================="
echo " Building OpenOCD for Windows 7+ (CMSIS-DAP / JTAG)"
echo " Root: ${REPO_ROOT}"
echo " Arch: ${ARCH}"
echo "==================================================="

build_x64() {
    echo ">>> [1/3] Building static libusb-1.0 (x64)..."
    mkdir -p "${PREFIX_X64}"
    cd "${REPO_ROOT}/deps/libusb"
    [ ! -f configure ] && ./bootstrap.sh
    make distclean 2>/dev/null || true
    ./configure --host=x86_64-w64-mingw32 --prefix="${PREFIX_X64}" --enable-static --disable-shared CFLAGS="-O2 -D_WIN32_WINNT=0x0601" LDFLAGS="-static"
    make -j$(nproc) && make install

    echo ">>> [2/3] Building static hidapi (x64)..."
    cd "${REPO_ROOT}/deps/hidapi"
    [ ! -f configure ] && ./bootstrap
    make distclean 2>/dev/null || true
    ./configure --host=x86_64-w64-mingw32 --prefix="${PREFIX_X64}" --enable-static --disable-shared CFLAGS="-O2 -D_WIN32_WINNT=0x0601" LDFLAGS="-static"
    make -j$(nproc) && make install

    echo ">>> [3/3] Building OpenOCD (x64)..."
    cd "${REPO_ROOT}"
    [ ! -f configure ] && ./bootstrap
    make distclean 2>/dev/null || true
    export PKG_CONFIG_PATH="${PREFIX_X64}/lib/pkgconfig"
    ./configure --host=x86_64-w64-mingw32 \
        --enable-internal-jimtcl \
        --enable-cmsis-dap \
        --enable-cmsis-dap-v2 \
        --disable-werror \
        CFLAGS="-O2 -D_WIN32_WINNT=0x0601" \
        LDFLAGS="-static -static-libgcc" \
        LIBS="-lsetupapi"
    make -j$(nproc)
    cp src/openocd.exe "${REPO_ROOT}/openocd.exe"
    mkdir -p "${REPO_ROOT}/bin"
    cp src/openocd.exe "${REPO_ROOT}/bin/openocd.exe"
    echo ">>> Successfully built openocd.exe (x64)"
}

build_x86() {
    echo ">>> [1/3] Building static libusb-1.0 (x86)..."
    mkdir -p "${PREFIX_X86}"
    cd "${REPO_ROOT}/deps/libusb"
    [ ! -f configure ] && ./bootstrap.sh
    make distclean 2>/dev/null || true
    ./configure --host=i686-w64-mingw32 --prefix="${PREFIX_X86}" --enable-static --disable-shared CFLAGS="-O2 -D_WIN32_WINNT=0x0601" LDFLAGS="-static"
    make -j$(nproc) && make install

    echo ">>> [2/3] Building static hidapi (x86)..."
    cd "${REPO_ROOT}/deps/hidapi"
    [ ! -f configure ] && ./bootstrap
    make distclean 2>/dev/null || true
    ./configure --host=i686-w64-mingw32 --prefix="${PREFIX_X86}" --enable-static --disable-shared CFLAGS="-O2 -D_WIN32_WINNT=0x0601" LDFLAGS="-static"
    make -j$(nproc) && make install

    echo ">>> [3/3] Building OpenOCD (x86)..."
    cd "${REPO_ROOT}"
    [ ! -f configure ] && ./bootstrap
    make distclean 2>/dev/null || true
    export PKG_CONFIG_PATH="${PREFIX_X86}/lib/pkgconfig"
    ./configure --host=i686-w64-mingw32 \
        --enable-internal-jimtcl \
        --enable-cmsis-dap \
        --enable-cmsis-dap-v2 \
        --disable-werror \
        CFLAGS="-O2 -D_WIN32_WINNT=0x0601" \
        LDFLAGS="-static -static-libgcc" \
        LIBS="-lsetupapi"
    make -j$(nproc)
    cp src/openocd.exe "${REPO_ROOT}/openocd-x86.exe"
    mkdir -p "${REPO_ROOT}/bin"
    cp src/openocd.exe "${REPO_ROOT}/bin/openocd-x86.exe"
    echo ">>> Successfully built openocd-x86.exe (x86)"
}

case "${ARCH}" in
    x64)
        build_x64
        ;;
    x86)
        build_x86
        ;;
    all)
        build_x64
        build_x86
        ;;
    *)
        echo "Unknown architecture: ${ARCH}. Use x64, x86, or all."
        exit 1
        ;;
esac

echo "==================================================="
echo " Build complete!"
echo " Binaries updated: openocd.exe, openocd-x86.exe"
echo "==================================================="
