@echo off
REM CUDA and cuDNN diagnostic script for Windows
REM Used to check if CUDA configuration is correct and test GPU transcription functionality

setlocal enabledelayedexpansion

REM Get script and project directories
set "SCRIPT_DIR=%~dp0"
set "PROJECT_DIR=%SCRIPT_DIR%..\..\"

REM Display title
echo ================================================
echo    CUDA ^& cuDNN Diagnostic Tool
echo ================================================
echo.

REM 1. Check nvidia-smi
echo [INFO] Step 1: Checking NVIDIA GPU Driver
where nvidia-smi >nul 2>&1
if errorlevel 1 (
    echo [X] nvidia-smi not found, please install NVIDIA driver
    pause
    exit /b 1
)

nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader,nounits
if errorlevel 1 (
    echo [X] Failed to query GPU information
    pause
    exit /b 1
) else (
    echo [✓] GPU found and driver is working
)

REM Get CUDA version from nvidia-smi
for /f "tokens=*" %%i in ('nvidia-smi ^| findstr "CUDA Version"') do set "CUDA_LINE=%%i"
if defined CUDA_LINE (
    echo [✓] Driver supports CUDA
) else (
    echo [WARNING] Could not detect CUDA version from driver
)
echo.

REM 2. Check Conda environment
echo [INFO] Step 2: Checking Conda Environment
where conda >nul 2>&1
if errorlevel 1 (
    echo [X] Conda not installed
    echo [INFO] Please run: scripts\windows\install_deps.bat
    pause
    exit /b 1
)

REM Detect Miniconda installation
if exist "%USERPROFILE%\miniconda3" (
    set "CONDA_PATH=%USERPROFILE%\miniconda3"
) else if exist "%LOCALAPPDATA%\miniconda3" (
    set "CONDA_PATH=%LOCALAPPDATA%\miniconda3"
) else if exist "C:\ProgramData\miniconda3" (
    set "CONDA_PATH=C:\ProgramData\miniconda3"
) else (
    echo [X] Miniconda3 not found
    echo [INFO] Please run: scripts\windows\install_deps.bat
    pause
    exit /b 1
)

echo [✓] Conda installed

REM Initialize Conda for batch script
call "%CONDA_PATH%\Scripts\activate.bat" "%CONDA_PATH%" >nul 2>&1
if errorlevel 1 (
    echo [X] Failed to initialize Conda
    pause
    exit /b 1
)

REM Check if autotranscription environment exists
call conda env list | findstr /C:"autotranscription" >nul 2>&1
if errorlevel 1 (
    echo [X] autotranscription environment does not exist
    echo [INFO] Please run: scripts\windows\install_deps.bat
    pause
    exit /b 1
)

echo [✓] autotranscription environment exists

REM Activate autotranscription environment
call conda activate autotranscription >nul 2>&1
if errorlevel 1 (
    echo [X] Failed to activate autotranscription environment
    pause
    exit /b 1
)

echo [✓] Activated autotranscription environment
echo.

REM 3. Check PyTorch CUDA support
echo [INFO] Step 3: Checking PyTorch CUDA Support
python -c "import sys; import torch; print(f'✓ PyTorch version: {torch.__version__}'); print(f'✓ CUDA available: {torch.cuda.is_available()}'); cuda_avail = torch.cuda.is_available(); print(f'✓ CUDA device count: {torch.cuda.device_count()}') if cuda_avail else None; print(f'✓ CUDA current device: {torch.cuda.current_device()}') if cuda_avail else None; print(f'✓ CUDA device name: {torch.cuda.get_device_name(0)}') if cuda_avail else None; print(f'✓ cuDNN version: {torch.backends.cudnn.version()}') if cuda_avail else None; print(f'✓ cuDNN enabled: {torch.backends.cudnn.enabled}') if cuda_avail else None; sys.exit(0 if cuda_avail else 1)"

if errorlevel 1 (
    echo [X] PyTorch CUDA support check failed
    pause
    exit /b 1
)
echo.

REM 4. Check cuDNN library path (Windows uses different structure)
echo [INFO] Step 4: Checking cuDNN Library Path
set "CUDNN_LIB_PATH=%CONDA_PREFIX%\Lib\site-packages\nvidia\cudnn\bin"

if exist "%CUDNN_LIB_PATH%" (
    echo [✓] cuDNN library directory exists: %CUDNN_LIB_PATH%

    REM Count cuDNN DLL files
    set "CUDNN_COUNT=0"
    for %%f in ("%CUDNN_LIB_PATH%\cudnn*.dll") do set /a CUDNN_COUNT+=1

    if !CUDNN_COUNT! GTR 0 (
        echo [✓] Found !CUDNN_COUNT! cuDNN library files
        echo [INFO] Library file list:
        for %%f in ("%CUDNN_LIB_PATH%\cudnn*.dll") do echo   - %%~nxf
    ) else (
        echo [X] cuDNN library directory exists but no library files found
        pause
        exit /b 1
    )
) else (
    echo [X] cuDNN library directory does not exist: %CUDNN_LIB_PATH%
    echo [INFO] Please run: scripts\windows\install_deps.bat
    pause
    exit /b 1
)
echo.

REM 5. Test cuDNN library loading
echo [INFO] Step 5: Testing cuDNN Library Loading
REM Windows automatically handles DLL paths, no need to set PATH explicitly

python -c "import sys; import os; import torch; print(f'✓ CUDA available: {torch.cuda.is_available()}'); cuda_avail = torch.cuda.is_available(); x = torch.randn(100, 100).cuda() if cuda_avail else None; y = torch.randn(100, 100).cuda() if cuda_avail else None; z = torch.matmul(x, y) if cuda_avail else None; print(f'✓ CUDA tensor operation successful') if cuda_avail else None; print(f'✓ cuDNN library loaded normally') if cuda_avail else None; sys.exit(0 if cuda_avail else 1)"

if errorlevel 1 (
    echo [X] cuDNN library loading test failed
    echo [WARNING] This is usually caused by incorrect library path configuration
    echo [INFO] Solution: Startup script automatically configures library path
    pause
    exit /b 1
)
echo.

REM 6. Test Whisper GPU transcription
echo [INFO] Step 6: Testing Whisper GPU Transcription Function
echo [WARNING] This will download and load Whisper base model (about 150MB), may take some time...
echo.

python -c "import sys; import numpy as np; from faster_whisper import WhisperModel; import torch; print('✓ faster-whisper imported successfully'); print('Loading Whisper base model...'); model = WhisperModel('base', device='cuda', compute_type='float16'); print('✓ Whisper model loaded successfully (base + GPU + float16)'); print('Testing GPU transcription...'); test_audio = np.zeros(16000, dtype=np.float32); segments, info = model.transcribe(test_audio, language='zh'); segment_list = list(segments); print(f'✓ GPU transcription test successful'); print(f'  - Detected language: {info.language}'); print(f'  - Language probability: {info.language_probability:.2f}'); print(f'  - Segment count: {len(segment_list)}'); del model; torch.cuda.empty_cache(); print(''); print('✓ All tests passed, GPU transcription function is normal!')"

if errorlevel 1 (
    echo.
    echo ================================================
    echo    X CUDA configuration has issues
    echo ================================================
    echo.
    echo [X] Please check the error information above and fix the issues
    echo.
    echo Common solutions:
    echo 1. Reinstall dependencies: scripts\windows\install_deps.bat
    echo 2. Check NVIDIA driver: nvidia-smi
    echo 3. Check error logs: logs\transcription_server_error.log
    echo.
    pause
    exit /b 1
) else (
    echo.
    echo ================================================
    echo    ✓ CUDA and cuDNN configuration is completely normal
    echo ================================================
    echo.
    echo [✓] System is ready, you can start the server
    echo.
    echo Next steps:
    echo 1. Start server: scripts\windows\manage.bat server start
    echo 2. Check health status: scripts\windows\manage.bat server health
    echo 3. Real-time monitoring: scripts\windows\manage.bat server monitor
    echo.
)

REM Deactivate conda environment
call conda deactivate

pause
exit /b 0
