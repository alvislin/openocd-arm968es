@echo off
setlocal
cd /d "%~dp0"

echo ===================================================
echo  Starting OpenOCD for ARM968E-S via CMSIS-DAP (x64)
echo ===================================================

openocd.exe -s ./scripts -f arm968es_cmsisdap.cfg %*

if errorlevel 1 (
    echo.
    echo OpenOCD exited with error code %errorlevel%.
    pause
)
