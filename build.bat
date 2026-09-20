@echo off
setlocal
cd /d "%~dp0"

echo ===================================================
echo  Triggering OpenOCD Build for Windows 7+ via WSL
echo ===================================================

wsl -u root bash -c "cd $(wslpath '%CD%') && chmod +x build.sh && ./build.sh %*"

if errorlevel 1 (
    echo.
    echo Build failed with error code %errorlevel%.
    pause
    exit /b %errorlevel%
)

echo.
echo Build succeeded!
pause
