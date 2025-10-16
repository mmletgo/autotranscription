@echo off
REM AutoTranscription Windows Dependencies Installation Script
REM Supports: Windows 10+, Python 3.8+
REM GPU Support: NVIDIA CUDA (auto-detected)

setlocal EnableDelayedExpansion

REM Configuration
set "PROJECT_DIR=%~dp0..\.."
set "SCRIPT_NAME=%~nx0"
set "INSTALL_MODE=%~1"
set "CUDA_AVAILABLE=false"
set "GPU_AVAILABLE=false"

REM Parse installation mode
if "%INSTALL_MODE%"=="" set "INSTALL_MODE=full"
if "%INSTALL_MODE%"=="-h" goto :show_help
if "%INSTALL_MODE%"=="--help" goto :show_help
if "%INSTALL_MODE%"=="help" goto :show_help

REM Validate installation mode
if not "%INSTALL_MODE%"=="full" if not "%INSTALL_MODE%"=="client" if not "%INSTALL_MODE%"=="server" (
    echo [ERROR] Unknown installation mode: %INSTALL_MODE%
    echo.
    goto :show_help
)

echo [INFO] Starting AutoTranscription installation (%INSTALL_MODE% mode)...
echo.

REM Check Python
call :check_python
if errorlevel 1 exit /b 1

REM Check CUDA for server/full mode
if "%INSTALL_MODE%"=="full" call :check_cuda
if "%INSTALL_MODE%"=="server" call :check_cuda

REM Check/Install Miniconda
call :check_miniconda
if errorlevel 1 exit /b 1

REM Create Conda environment
call :create_conda_env
if errorlevel 1 exit /b 1

REM Install dependencies based on mode
if "%INSTALL_MODE%"=="full" call :install_full_deps
if "%INSTALL_MODE%"=="client" call :install_client_deps
if "%INSTALL_MODE%"=="server" call :install_server_deps
if errorlevel 1 exit /b 1

REM Create configuration files
if "%INSTALL_MODE%"=="full" call :create_full_config
if "%INSTALL_MODE%"=="client" call :create_client_config
if "%INSTALL_MODE%"=="server" call :create_server_config

REM Create log directory
call :create_log_dir

REM Verify installation
call :verify_installation
if errorlevel 1 exit /b 1

REM Show post-install information
call :show_post_install_info

echo.
echo [SUCCESS] Installation complete!
goto :end

REM ===== Functions =====

:show_help
echo AutoTranscription Dependencies Installation Script
echo.
echo Usage: %SCRIPT_NAME% [mode]
echo.
echo Modes:
echo     full            Install complete system dependencies (default)
echo     client          Install client dependencies only
echo     server          Install server dependencies only
echo     -h, --help      Show this help message
echo.
echo Examples:
echo     %SCRIPT_NAME%                # Install complete system
echo     %SCRIPT_NAME% full           # Install complete system
echo     %SCRIPT_NAME% client         # Install client only
echo     %SCRIPT_NAME% server         # Install server only
echo.
goto :eof

:check_python
echo [INFO] Checking Python environment...
where python >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python not found. Please install Python 3.8+ from python.org
    exit /b 1
)

for /f "tokens=2" %%i in ('python --version 2^>^&1') do set "PYTHON_VERSION=%%i"
echo [INFO] Found Python version: %PYTHON_VERSION%

REM Extract minor version (e.g., from 3.10.5 get 10)
for /f "tokens=2 delims=." %%a in ("%PYTHON_VERSION%") do set "MINOR_VERSION=%%a"
if %MINOR_VERSION% LSS 8 (
    echo [ERROR] Python 3.8+ required, current version: %PYTHON_VERSION%
    exit /b 1
)
goto :eof

:check_cuda
echo [INFO] Checking CUDA environment...
where nvidia-smi >nul 2>&1
if errorlevel 1 (
    echo [WARNING] NVIDIA GPU not detected, will use CPU mode
    set "GPU_AVAILABLE=false"
    set "CUDA_AVAILABLE=false"
    goto :eof
)

REM Get CUDA version
for /f "tokens=9" %%i in ('nvidia-smi ^| findstr /C:"CUDA Version"') do set "CUDA_VERSION=%%i"
echo [INFO] Detected NVIDIA GPU, driver supports CUDA: %CUDA_VERSION%
set "GPU_AVAILABLE=true"

REM Check if CUDA toolkit is installed
where nvcc >nul 2>&1
if errorlevel 1 (
    echo [WARNING] CUDA Toolkit not found
    echo [INFO] Please install CUDA Toolkit 11.8+ from: https://developer.nvidia.com/cuda-downloads
    echo [INFO] Installation will continue with CPU mode
    set "CUDA_AVAILABLE=false"
) else (
    echo [INFO] CUDA Toolkit found
    set "CUDA_AVAILABLE=true"
)
goto :eof

:check_miniconda
echo [INFO] Checking Miniconda installation...
where conda >nul 2>&1
if not errorlevel 1 (
    for /f "tokens=2" %%i in ('conda --version 2^>^&1') do set "CONDA_VERSION=%%i"
    echo [INFO] Conda already installed, version: !CONDA_VERSION!

    REM Configure conda channels (ensure they are set)
    echo [INFO] Ensuring Conda channels are configured...
    call conda config --add channels defaults 2>nul
    call conda config --add channels conda-forge 2>nul
    call conda config --set channel_priority flexible 2>nul
    echo [INFO] Channels configured: defaults, conda-forge

    goto :eof
)

echo.
echo ========================================
echo [INFO] Conda Not Found - Manual Installation Required
echo ========================================
echo.
echo Miniconda needs to be installed before continuing.
echo.
echo Please follow these steps:
echo.
echo 1. Download Miniconda from:
echo    https://docs.conda.io/en/latest/miniconda.html
echo.
echo 2. Choose "Miniconda3 Windows 64-bit" installer
echo.
echo 3. During installation:
echo    - Check "Add Miniconda3 to my PATH environment variable"
echo    - Or check "Register Miniconda3 as my default Python"
echo.
echo 4. After installation completes:
echo    - Close this Command Prompt window
echo    - Open a NEW Command Prompt window
echo    - Navigate back to: %PROJECT_DIR%
echo    - Run this script again: %SCRIPT_NAME% %INSTALL_MODE%
echo.
echo ========================================
echo.
pause
exit /b 1

:create_conda_env
echo [INFO] Creating Conda virtual environment...

REM Check if environment already exists
conda env list | findstr /C:"autotranscription" >nul 2>&1
if not errorlevel 1 (
    echo [WARNING] Conda environment 'autotranscription' already exists, removing...
    call conda env remove -n autotranscription -y
)

echo [INFO] Creating Conda environment: autotranscription
call conda create -n autotranscription python=3.10 -y
if errorlevel 1 (
    echo [ERROR] Failed to create Conda environment
    exit /b 1
)

echo [INFO] Activating Conda environment...
call conda activate autotranscription
if errorlevel 1 (
    echo [ERROR] Failed to activate Conda environment
    exit /b 1
)

echo [SUCCESS] Conda environment created
goto :eof

:install_full_deps
echo [INFO] Installing complete system dependencies...
call conda activate autotranscription

REM Upgrade pip
echo [INFO] Upgrading pip...
python -m pip install --upgrade pip setuptools wheel

REM Install system dependencies via conda
echo [INFO] Installing system-level dependencies...
call conda install -y portaudio ffmpeg || echo [WARNING] Some conda packages failed, continuing...

REM Install PyTorch
if "%CUDA_AVAILABLE%"=="true" (
    echo [INFO] Installing CUDA version of PyTorch...
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 || (
        echo [WARNING] PyTorch CUDA version failed, installing CPU version...
        pip install torch torchvision torchaudio
    )
) else (
    echo [INFO] Installing CPU version of PyTorch...
    pip install torch torchvision torchaudio
)

REM Install web service dependencies
echo [INFO] Installing web service dependencies...
pip install flask gunicorn gevent flask-cors

REM Install core packages
echo [INFO] Installing core application packages...
pip install faster-whisper psutil numpy scipy requests

REM Install client dependencies
echo [INFO] Installing client dependencies...
pip install soundfile pynput transitions pyperclip sounddevice opencc-python-reimplemented

REM Install PyAudio
echo [INFO] Installing PyAudio...
call "%PROJECT_DIR%\scripts\windows\install_pyaudio.bat"
if errorlevel 1 (
    echo [WARNING] PyAudio installation may have failed
    echo [INFO] You can try manual installation later using:
    echo [INFO]   conda activate autotranscription
    echo [INFO]   conda install -c conda-forge pyaudio
)

REM Clean conda cache
echo [INFO] Cleaning conda cache...
call conda clean -a -y

echo [SUCCESS] Complete system dependencies installed
goto :eof

:install_client_deps
echo [INFO] Installing client dependencies...
call conda activate autotranscription

REM Upgrade pip
echo [INFO] Upgrading pip...
python -m pip install --upgrade pip setuptools wheel

REM Install system dependencies
echo [INFO] Installing audio processing dependencies...
call conda install -y portaudio ffmpeg || echo [WARNING] Some conda packages failed, continuing...

REM Install client core dependencies
echo [INFO] Installing client core dependencies...
pip install numpy scipy requests soundfile pynput transitions pyperclip sounddevice opencc-python-reimplemented

REM Install PyAudio
echo [INFO] Installing PyAudio...
call "%PROJECT_DIR%\scripts\windows\install_pyaudio.bat"
if errorlevel 1 (
    echo [WARNING] PyAudio installation may have failed
    echo [INFO] You can try manual installation later using:
    echo [INFO]   conda activate autotranscription
    echo [INFO]   conda install -c conda-forge pyaudio
)

REM Clean conda cache
echo [INFO] Cleaning conda cache...
call conda clean -a -y

echo [SUCCESS] Client dependencies installed
goto :eof

:install_server_deps
echo [INFO] Installing server dependencies...
call conda activate autotranscription

REM Upgrade pip
echo [INFO] Upgrading pip...
python -m pip install --upgrade pip setuptools wheel

REM Install PyTorch
if "%CUDA_AVAILABLE%"=="true" (
    echo [INFO] Installing CUDA version of PyTorch...
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 || (
        echo [WARNING] PyTorch CUDA version failed, installing CPU version...
        pip install torch torchvision torchaudio
    )
) else (
    echo [INFO] Installing CPU version of PyTorch...
    pip install torch torchvision torchaudio
)

REM Install web service dependencies
echo [INFO] Installing web service dependencies...
pip install flask gunicorn gevent flask-cors

REM Install server core dependencies
echo [INFO] Installing server core dependencies...
pip install faster-whisper psutil

REM Clean conda cache
echo [INFO] Cleaning conda cache...
call conda clean -a -y

echo [SUCCESS] Server dependencies installed
goto :eof

:create_full_config
call :create_server_config
call :create_client_config
goto :eof

:create_server_config
echo [INFO] Creating server configuration file...
if not exist "%PROJECT_DIR%\config" mkdir "%PROJECT_DIR%\config"

if exist "%PROJECT_DIR%\config\server_config.json" (
    echo [INFO] Server configuration file already exists, skipping
    goto :eof
)

REM Set device based on CUDA availability
if "%CUDA_AVAILABLE%"=="true" (
    set "DEVICE=cuda"
    set "COMPUTE_TYPE=float16"
) else (
    set "DEVICE=cpu"
    set "COMPUTE_TYPE=int8"
)

(
echo {
echo     "model_size": "large-v3",
echo     "device": "%DEVICE%",
echo     "compute_type": "%COMPUTE_TYPE%",
echo     "language": "zh",
echo     "initial_prompt": "以下是普通话的句子。",
echo     "network_mode": "lan",
echo     "host": "0.0.0.0",
echo     "port": 5000,
echo     "workers": 4,
echo     "max_concurrent_transcriptions": 8,
echo     "queue_size": 100,
echo     "timeout": 600,
echo     "log_level": "INFO"
echo }
) > "%PROJECT_DIR%\config\server_config.json"

echo [SUCCESS] Server configuration file created
goto :eof

:create_client_config
echo [INFO] Creating client configuration file...
if not exist "%PROJECT_DIR%\config" mkdir "%PROJECT_DIR%\config"

if exist "%PROJECT_DIR%\config\client_config.json" (
    echo [INFO] Client configuration file already exists, skipping
    goto :eof
)

(
echo {
echo     "server_url": "http://localhost:5000",
echo     "max_time": 30,
echo     "zh_convert": "none",
echo     "streaming": true,
echo     "key_combo": "^<alt^>",
echo     "sample_rate": 16000,
echo     "channels": 1,
echo     "audio_device": null,
echo     "enable_beep": false
echo }
) > "%PROJECT_DIR%\config\client_config.json"

echo [SUCCESS] Client configuration file created
goto :eof

:create_log_dir
echo [INFO] Creating log directory...
if not exist "%PROJECT_DIR%\logs" mkdir "%PROJECT_DIR%\logs"
echo [SUCCESS] Log directory created
goto :eof

:verify_installation
echo [INFO] Verifying installation...
call conda activate autotranscription

REM Get Python version
python --version
echo Conda environment: %CONDA_DEFAULT_ENV%

REM Check key modules based on installation mode
echo [INFO] Checking module imports...

if "%INSTALL_MODE%"=="full" (
    python -c "import flask, faster_whisper, torch, soundfile, pynput" 2>nul
    if errorlevel 1 (
        echo [ERROR] Some core modules failed to import
        exit /b 1
    )
    echo [SUCCESS] Core system modules imported successfully

    REM Check PyAudio separately
    python -c "import pyaudio" 2>nul
    if errorlevel 1 (
        echo [WARNING] PyAudio not imported - client audio recording may not work
        echo [INFO] To install PyAudio manually, activate environment and run:
        echo [INFO]   conda install -c conda-forge pyaudio
    ) else (
        echo [SUCCESS] PyAudio imported successfully
    )
)

if "%INSTALL_MODE%"=="client" (
    python -c "import soundfile, pynput, transitions" 2>nul
    if errorlevel 1 (
        echo [ERROR] Some core modules failed to import
        exit /b 1
    )
    echo [SUCCESS] Core client modules imported successfully

    REM Check PyAudio separately
    python -c "import pyaudio" 2>nul
    if errorlevel 1 (
        echo [WARNING] PyAudio not imported - audio recording may not work
        echo [INFO] To install PyAudio manually, activate environment and run:
        echo [INFO]   conda install -c conda-forge pyaudio
    ) else (
        echo [SUCCESS] PyAudio imported successfully
    )
)

if "%INSTALL_MODE%"=="server" (
    python -c "import flask, faster_whisper, torch" 2>nul
    if errorlevel 1 (
        echo [ERROR] Some modules failed to import
        exit /b 1
    )
    echo [SUCCESS] All server modules imported successfully
)

echo [SUCCESS] Installation verification passed
goto :eof

:show_post_install_info
echo.
echo ========================================
echo Installation Complete - %INSTALL_MODE% mode
echo ========================================
echo.

if "%INSTALL_MODE%"=="full" (
    echo Next steps:
    echo   1. Activate environment: conda activate autotranscription
    echo   2. Start server: scripts\windows\manage.bat server start
    echo   3. Start client: scripts\windows\manage.bat client
    echo.
    echo Environment info:
    echo   - Conda environment: autotranscription
    echo   - Python version: %PYTHON_VERSION%
    if "%CUDA_AVAILABLE%"=="true" (
        echo   - GPU acceleration: Enabled (CUDA %CUDA_VERSION%^)
    ) else (
        echo   - GPU acceleration: Disabled (CPU mode^)
    )
    echo.
    echo Configuration files:
    echo   - Server: config\server_config.json
    echo   - Client: config\client_config.json
)

if "%INSTALL_MODE%"=="client" (
    echo Next steps:
    echo   1. Activate environment: conda activate autotranscription
    echo   2. Configure server URL in config\client_config.json
    echo   3. Start client: scripts\windows\manage.bat client
    echo.
    echo Configuration file:
    echo   - Client: config\client_config.json
)

if "%INSTALL_MODE%"=="server" (
    echo Next steps:
    echo   1. Activate environment: conda activate autotranscription
    echo   2. Start server: scripts\windows\manage.bat server start
    echo   3. Check health: scripts\windows\manage.bat server health
    echo.
    echo Configuration file:
    echo   - Server: config\server_config.json
    if "%CUDA_AVAILABLE%"=="true" (
        echo   - GPU acceleration: Enabled (CUDA %CUDA_VERSION%^)
    ) else (
        echo   - GPU acceleration: Disabled (CPU mode^)
    )
)

echo.
echo Common commands:
echo   - View status: scripts\windows\manage.bat status
echo   - View help: scripts\windows\manage.bat --help
echo.
goto :eof

:end
endlocal
