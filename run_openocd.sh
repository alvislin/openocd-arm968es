#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${DIR}"

echo "==================================================="
echo " Starting OpenOCD for ARM968E-S via CMSIS-DAP (Linux)"
echo "==================================================="

exec ./openocd "$@"
