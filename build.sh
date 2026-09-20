#!/bin/bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${REPO_ROOT}/build"
PREFIX_WIN="${BUILD_DIR}/prefix_win64"
PREFIX_LINUX="${BUILD_DIR}/prefix_linux64"

clean_tree() {
    echo ">>> [Clean] Cleaning source tree and previous build files..."
    cd "${REPO_ROOT}"
    make distclean 2>/dev/null || true
    rm -f src/openocd src/openocd.exe
    rm -rf autom4te.cache config.log config.status .git/index.lock
    
    cd "${REPO_ROOT}/deps/libusb"
    make distclean 2>/dev/null || true
    
    cd "${REPO_ROOT}/deps/hidapi"
    make distclean 2>/dev/null || true
    
    cd "${REPO_ROOT}/jimtcl"
    make distclean 2>/dev/null || true
    rm -f Makefile jimautoconf.h jim-config.h build-jim-ext jimsh
    rm -rf conftest* autosetup/conftest*
    
    cd "${REPO_ROOT}"
}

build_windows() {
    echo "==================================================="
    echo " Building Single-Executable OpenOCD for Windows (x64)"
    echo " Target: ARM968E-S CMSIS-DAP (Standalone Binary)"
    echo " Prefix: ${PREFIX_WIN}"
    echo "==================================================="
    
    mkdir -p "${PREFIX_WIN}"
    clean_tree

    # 1. Build static libusb-1.0 (x64 Windows)
    echo ">>> [Win 1/3] Building static libusb-1.0 (win64)..."
    cd "${REPO_ROOT}/deps/libusb"
    if [ ! -f configure ]; then
        ./bootstrap.sh
    fi
    ./configure --host=x86_64-w64-mingw32 \
        --prefix="${PREFIX_WIN}" \
        --enable-static \
        --disable-shared \
        CFLAGS="-O2 -D_WIN32_WINNT=0x0601" \
        LDFLAGS="-static"
    make -j$(nproc)
    make install

    # 2. Build static hidapi (x64 Windows)
    echo ">>> [Win 2/3] Building static hidapi (win64)..."
    cd "${REPO_ROOT}/deps/hidapi"
    if [ ! -f configure ]; then
        ./bootstrap
    fi
    ./configure --host=x86_64-w64-mingw32 \
        --prefix="${PREFIX_WIN}" \
        --enable-static \
        --disable-shared \
        CFLAGS="-O2 -D_WIN32_WINNT=0x0601" \
        LDFLAGS="-static"
    make -j$(nproc)
    make install

    # 3. Build OpenOCD (x64 Windows)
    echo ">>> [Win 3/3] Building OpenOCD (win64)..."
    cd "${REPO_ROOT}"
    if [ ! -f configure ]; then
        ./bootstrap
    fi

    export PKG_CONFIG_PATH="${PREFIX_WIN}/lib/pkgconfig"

    ./configure --host=x86_64-w64-mingw32 \
        --enable-internal-jimtcl \
        --enable-cmsis-dap \
        --enable-cmsis-dap-v2 \
        --disable-werror \
        CFLAGS="-O2 -D_WIN32_WINNT=0x0601" \
        LDFLAGS="-static -static-libgcc" \
        LIBS="-lsetupapi"

    make -j$(nproc)

    # Strip binary
    x86_64-w64-mingw32-strip -s src/openocd.exe 2>/dev/null || true

    mkdir -p "${REPO_ROOT}/bin"
    cp -f src/openocd.exe "${REPO_ROOT}/openocd.exe"
    cp -f src/openocd.exe "${REPO_ROOT}/bin/openocd.exe"

    echo ">>> Windows build complete: openocd.exe created successfully!"
}

build_linux() {
    echo "==================================================="
    echo " Building Single-Executable OpenOCD for Linux (x64)"
    echo " Target: ARM968E-S CMSIS-DAP (Standalone Binary)"
    echo " Prefix: ${PREFIX_LINUX}"
    echo "==================================================="
    
    mkdir -p "${PREFIX_LINUX}"
    clean_tree

    # 1. Build static libusb-1.0 (x64 Linux with Netlink, zero udev dependency)
    echo ">>> [Linux 1/3] Building static libusb-1.0 (linux64)..."
    cd "${REPO_ROOT}/deps/libusb"
    if [ ! -f configure ]; then
        ./bootstrap.sh
    fi
    ./configure \
        --prefix="${PREFIX_LINUX}" \
        --enable-static \
        --disable-shared \
        --disable-udev \
        CFLAGS="-O2" \
        LDFLAGS="-static"
    make -j$(nproc)
    make install

    # 2. Build static hidapi (x64 Linux with hidapi-libusb backend)
    echo ">>> [Linux 2/3] Building static hidapi (linux64)..."
    cd "${REPO_ROOT}/deps/hidapi"
    if [ ! -f configure ]; then
        ./bootstrap
    fi
    PKG_CONFIG_PATH="${PREFIX_LINUX}/lib/pkgconfig" ./configure \
        --prefix="${PREFIX_LINUX}" \
        --enable-static \
        --disable-shared \
        CFLAGS="-O2" \
        LDFLAGS="-static"
    make -j$(nproc)
    make install

    # Direct hidapi pkg-config to hidapi-libusb to ensure zero runtime udev/shared library dependency
    cp -f "${PREFIX_LINUX}/lib/pkgconfig/hidapi-libusb.pc" "${PREFIX_LINUX}/lib/pkgconfig/hidapi.pc"
    rm -f "${PREFIX_LINUX}/lib/pkgconfig/hidapi-hidraw.pc"

    # 3. Build OpenOCD (x64 Linux - fully static standalone ELF)
    echo ">>> [Linux 3/3] Building OpenOCD (linux64)..."
    cd "${REPO_ROOT}"
    if [ ! -f configure ]; then
        ./bootstrap
    fi

    export PKG_CONFIG_PATH="${PREFIX_LINUX}/lib/pkgconfig"

    ./configure \
        --enable-internal-jimtcl \
        --enable-cmsis-dap \
        --enable-cmsis-dap-v2 \
        --disable-werror \
        CFLAGS="-O2" \
        LIBS="-lm -lpthread"

    make -j$(nproc) AM_LDFLAGS="-all-static"

    # Strip binary
    strip -s src/openocd 2>/dev/null || true

    mkdir -p "${REPO_ROOT}/bin"
    cp -f src/openocd "${REPO_ROOT}/openocd"
    cp -f src/openocd "${REPO_ROOT}/bin/openocd"
    chmod +x "${REPO_ROOT}/openocd" "${REPO_ROOT}/bin/openocd"

    echo ">>> Linux build complete: openocd created successfully!"
}

TARGET="${1:-all}"

case "${TARGET}" in
    windows|win|win64)
        build_windows
        ;;
    linux|linux64)
        build_linux
        ;;
    all|both)
        build_windows
        build_linux
        ;;
    clean)
        clean_tree
        rm -rf "${BUILD_DIR}"
        echo "Cleaned build directory and source tree."
        exit 0
        ;;
    *)
        echo "Usage: $0 [all | windows | linux | clean]"
        exit 1
        ;;
esac

# Update scripts directory
mkdir -p "${REPO_ROOT}/scripts"
cp -rf "${REPO_ROOT}/tcl"/* "${REPO_ROOT}/scripts/" 2>/dev/null || true

echo "==================================================="
echo " Build Summary"
echo "==================================================="
if [ -f "${REPO_ROOT}/openocd.exe" ]; then
    echo " Windows: ${REPO_ROOT}/openocd.exe ($(du -h "${REPO_ROOT}/openocd.exe" | cut -f1))"
    echo "          ${REPO_ROOT}/bin/openocd.exe"
fi
if [ -f "${REPO_ROOT}/openocd" ]; then
    echo " Linux:   ${REPO_ROOT}/openocd ($(du -h "${REPO_ROOT}/openocd" | cut -f1))"
    echo "          ${REPO_ROOT}/bin/openocd"
fi
echo "==================================================="
