@echo off
REM PyAudio Installation Script for Windows
REM Automatically downloads and installs pre-compiled PyAudio wheel file

setlocal EnableDelayedExpansion

echo [INFO] Installing PyAudio for Windows...

REM Get Python version
for /f "tokens=2 delims= " %%i in ('python --version 2^>^&1') do set "PYTHON_VERSION=%%i"
echo [INFO] Detected Python version: %PYTHON_VERSION%

REM Extract major and minor version (e.g., 3.10)
for /f "tokens=1,2 delims=." %%a in ("%PYTHON_VERSION%") do (
    set "MAJOR_VERSION=%%a"
    set "MINOR_VERSION=%%b"
)
set "PYTHON_SHORT_VERSION=%MAJOR_VERSION%%MINOR_VERSION%"
echo [INFO] Python short version: %PYTHON_SHORT_VERSION%

REM Determine architecture
python -c "import platform; print(platform.machine())" > temp_arch.txt
set /p ARCH=<temp_arch.txt
del temp_arch.txt

if "%ARCH%"=="AMD64" (
    set "PLATFORM=win_amd64"
) else if "%ARCH%"=="x86_64" (
    set "PLATFORM=win_amd64"
) else (
    set "PLATFORM=win32"
)
echo [INFO] Platform: %PLATFORM%

REM Set PyAudio version
set "PYAUDIO_VERSION=0.2.14"

REM Construct wheel filename
set "WHEEL_NAME=PyAudio-%PYAUDIO_VERSION%-cp%PYTHON_SHORT_VERSION%-cp%PYTHON_SHORT_VERSION%-%PLATFORM%.whl"
echo [INFO] Target wheel file: %WHEEL_NAME%

REM Try installing from PyPI first (works for Python 3.11+)
echo [INFO] Attempting to install PyAudio from PyPI...
pip install PyAudio
if %ERRORLEVEL% EQU 0 (
    echo [SUCCESS] PyAudio installed successfully from PyPI!
    goto :end
)

echo [WARNING] PyPI installation failed, trying alternative sources...

REM Create temporary directory
set "TEMP_DIR=%TEMP%\pyaudio_install"
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"

REM Try downloading from unofficial Windows binaries repository
echo [INFO] Downloading from pipwin repository mirror...
set "DOWNLOAD_URL=https://github.com/intxcc/pyaudio_portaudio/releases/download/v19.7.0/%WHEEL_NAME%"

powershell -Command "& {try {Invoke-WebRequest -Uri '%DOWNLOAD_URL%' -OutFile '%TEMP_DIR%\%WHEEL_NAME%' -UseBasicParsing} catch {exit 1}}"
if %ERRORLEVEL% EQU 0 (
    echo [SUCCESS] Wheel file downloaded successfully
    echo [INFO] Installing from wheel file...
    pip install "%TEMP_DIR%\%WHEEL_NAME%"
    if %ERRORLEVEL% EQU 0 (
        echo [SUCCESS] PyAudio installed successfully!
        rmdir /S /Q "%TEMP_DIR%" 2>nul
        goto :end
    )
)

echo [WARNING] Automatic download failed

REM Provide manual installation instructions
echo.
echo ========================================
echo Manual Installation Required
echo ========================================
echo.
echo PyAudio could not be installed automatically.
echo.
echo Option 1: Install via conda (Recommended)
echo   conda install -c conda-forge pyaudio
echo.
echo Option 2: Download pre-compiled wheel manually
echo   1. Visit: https://github.com/intxcc/pyaudio_portaudio/releases
echo   2. Download: %WHEEL_NAME%
echo   3. Install: pip install %WHEEL_NAME%
echo.
echo Option 3: Build from source (requires Visual Studio)
echo   1. Install Microsoft Visual C++ Build Tools
echo   2. Download PortAudio
echo   3. pip install pyaudio
echo.
echo ========================================

REM Clean up
rmdir /S /Q "%TEMP_DIR%" 2>nul

exit /b 1

:end
echo [SUCCESS] PyAudio installation complete!
endlocal
