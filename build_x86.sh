#!/bin/bash
set -e

PREFIX=/tmp/openocd_build_x86/prefix
DIST=/tmp/openocd_build_x86/dist
mkdir -p "$PREFIX" "$DIST"

echo "=== Building libusb for i686 ==="
cd /tmp/openocd_build/libusb
make distclean || true
./configure --host=i686-w64-mingw32 --prefix="$PREFIX" --enable-static --disable-shared CFLAGS="-O2 -D_WIN32_WINNT=0x0601" LDFLAGS="-static"
make -j4 && make install

echo "=== Building hidapi for i686 ==="
cd /tmp/openocd_build/hidapi
make distclean || true
./configure --host=i686-w64-mingw32 --prefix="$PREFIX" --enable-static --disable-shared CFLAGS="-O2 -D_WIN32_WINNT=0x0601" LDFLAGS="-static"
make -j4 && make install

echo "=== Building openocd for i686 ==="
cd /tmp/openocd_build/openocd
make distclean || true
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"
./configure --host=i686-w64-mingw32 --prefix="$DIST" --enable-internal-jimtcl --enable-cmsis-dap --enable-cmsis-dap-v2 --disable-werror CFLAGS="-O2 -D_WIN32_WINNT=0x0601" LDFLAGS="-static -static-libgcc" LIBS="-lsetupapi"
make -j4
cp src/openocd.exe /mnt/c/antigravity/openocd-arm968es/openocd-x86.exe
cp src/openocd.exe /mnt/c/antigravity/openocd-arm968es/bin/openocd-x86.exe
echo "=== i686 build finished successfully ==="
