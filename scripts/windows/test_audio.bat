@echo off
REM Audio device testing script for Windows
REM Tests all available audio output devices to find the working one

setlocal enabledelayedexpansion

REM Get script and project directories
set "SCRIPT_DIR=%~dp0"
set "PROJECT_ROOT=%SCRIPT_DIR%..\..\"

REM Detect Miniconda installation
if exist "%USERPROFILE%\miniconda3" (
    set "CONDA_PATH=%USERPROFILE%\miniconda3"
) else if exist "%LOCALAPPDATA%\miniconda3" (
    set "CONDA_PATH=%LOCALAPPDATA%\miniconda3"
) else if exist "C:\ProgramData\miniconda3" (
    set "CONDA_PATH=C:\ProgramData\miniconda3"
) else (
    echo Error: Miniconda3 not found
    echo Please install Miniconda first using install_deps.bat
    pause
    exit /b 1
)

REM Initialize Conda for batch script
call "%CONDA_PATH%\Scripts\activate.bat" "%CONDA_PATH%"
if errorlevel 1 (
    echo Error: Failed to initialize Conda
    pause
    exit /b 1
)

REM Activate autotranscription environment
call conda activate autotranscription
if errorlevel 1 (
    echo Error: Failed to activate autotranscription environment
    echo Please install dependencies first using install_deps.bat
    pause
    exit /b 1
)

REM Run the Python test script
echo Starting audio device test...
echo.
python "%SCRIPT_DIR%..\test_audio_devices.py"

set "EXIT_CODE=%errorlevel%"

REM Deactivate conda environment
call conda deactivate

echo.
echo Test completed with exit code: %EXIT_CODE%
pause
exit /b %EXIT_CODE%
