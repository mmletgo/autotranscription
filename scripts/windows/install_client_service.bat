@echo off
REM AutoTranscription Client Service Installation Script for Windows
REM Uses NSSM (Non-Sucking Service Manager) for Windows service management

setlocal enabledelayedexpansion

REM Get script and project directories
set "SCRIPT_DIR=%~dp0"
set "PROJECT_DIR=%SCRIPT_DIR%..\..\"
set "SERVICE_NAME=AutoTranscriptionClient"
set "CONDA_ENV_NAME=autotranscription"

REM Parse command line argument
set "ACTION=%~1"
if "%ACTION%"=="" set "ACTION=install"

REM Display help if requested
if "%ACTION%"=="-h" goto :show_help
if "%ACTION%"=="--help" goto :show_help
if "%ACTION%"=="help" goto :show_help

goto :main

:show_help
echo AutoTranscription Client Service Installation Script (Windows)
echo.
echo Usage: %~nx0 [option]
echo.
echo Options:
echo     install     Install client service (default)
echo     uninstall   Uninstall client service
echo     status      View service status
echo     enable      Enable auto-start on boot
echo     disable     Disable auto-start on boot
echo     start       Start service
echo     stop        Stop service
echo     restart     Restart service
echo     -h, --help  Show this help information
echo.
echo Examples:
echo     %~nx0 install     # Install service
echo     %~nx0 enable      # Enable auto-start on boot
echo     %~nx0 status      # View service status
echo.
echo Platform: Windows (uses NSSM)
echo.
pause
exit /b 0

:main
REM Check admin privileges
net session >nul 2>&1
if errorlevel 1 (
    echo [X] This script requires administrator privileges
    echo [INFO] Please run as administrator
    pause
    exit /b 1
)

REM Route to appropriate function
if /i "%ACTION%"=="install" goto :install_service
if /i "%ACTION%"=="uninstall" goto :uninstall_service
if /i "%ACTION%"=="status" goto :show_status
if /i "%ACTION%"=="enable" goto :enable_service
if /i "%ACTION%"=="disable" goto :disable_service
if /i "%ACTION%"=="start" goto :start_service
if /i "%ACTION%"=="stop" goto :stop_service
if /i "%ACTION%"=="restart" goto :restart_service

echo [X] Unknown command: %ACTION%
echo.
goto :show_help

:install_service
echo [INFO] Installing AutoTranscription client service...
echo.

REM Check if NSSM is installed
where nssm >nul 2>&1
if errorlevel 1 (
    echo [X] NSSM (Non-Sucking Service Manager) not found
    echo [INFO] Please install NSSM:
    echo    1. Download from https://nssm.cc/download
    echo    2. Extract and add to PATH
    echo    3. Or install with: choco install nssm
    pause
    exit /b 1
)

echo [✓] NSSM found

REM Detect Conda installation
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

echo [✓] Conda found at %CONDA_PATH%

REM Check if conda environment exists
call "%CONDA_PATH%\Scripts\activate.bat" "%CONDA_PATH%" >nul 2>&1
call conda env list | findstr /C:"%CONDA_ENV_NAME%" >nul 2>&1
if errorlevel 1 (
    echo [X] Conda environment '%CONDA_ENV_NAME%' does not exist
    echo [INFO] Please run: scripts\windows\install_deps.bat
    call conda deactivate >nul 2>&1
    pause
    exit /b 1
)

call conda deactivate >nul 2>&1
echo [✓] Conda environment '%CONDA_ENV_NAME%' found

REM Check if service already exists
nssm status "%SERVICE_NAME%" >nul 2>&1
if not errorlevel 1 (
    echo [WARNING] Service '%SERVICE_NAME%' already exists, removing first...
    call :uninstall_service
    echo.
)

REM Create logs directory
if not exist "%PROJECT_DIR%\logs" mkdir "%PROJECT_DIR%\logs"

REM Get Python executable path in conda environment
set "PYTHON_EXE=%CONDA_PATH%\envs\%CONDA_ENV_NAME%\python.exe"
if not exist "%PYTHON_EXE%" (
    echo [X] Python executable not found: %PYTHON_EXE%
    pause
    exit /b 1
)

echo [✓] Python executable: %PYTHON_EXE%

REM Install service using NSSM
echo [INFO] Creating Windows service...
nssm install "%SERVICE_NAME%" "%PYTHON_EXE%" "%PROJECT_DIR%\client\client.py"

if errorlevel 1 (
    echo [X] Failed to create service
    pause
    exit /b 1
)

REM Configure service parameters
nssm set "%SERVICE_NAME%" DisplayName "AutoTranscription Client Service"
nssm set "%SERVICE_NAME%" Description "AutoTranscription speech-to-text client service"
nssm set "%SERVICE_NAME%" AppDirectory "%PROJECT_DIR%"
nssm set "%SERVICE_NAME%" AppStdout "%PROJECT_DIR%\logs\client_service.log"
nssm set "%SERVICE_NAME%" AppStderr "%PROJECT_DIR%\logs\client_service_error.log"
nssm set "%SERVICE_NAME%" AppRotateFiles 1
nssm set "%SERVICE_NAME%" AppRotateBytes 10485760
nssm set "%SERVICE_NAME%" AppRestartDelay 10000

echo [✓] Service '%SERVICE_NAME%' installed successfully
echo.
echo === Windows Service Usage ===
echo.
echo Service management commands:
echo   Enable auto-start: %~nx0 enable
echo   Disable auto-start: %~nx0 disable
echo   Start service:     %~nx0 start
echo   Stop service:      %~nx0 stop
echo   Restart service:   %~nx0 restart
echo   View status:       %~nx0 status
echo.
echo NSSM commands:
echo   View service status: nssm status %SERVICE_NAME%
echo   Manual start:        nssm start %SERVICE_NAME%
echo   Manual stop:         nssm stop %SERVICE_NAME%
echo.
echo Windows Service Manager:
echo   Open services.msc and look for '%SERVICE_NAME%'
echo.
echo Log file locations:
echo   Service log: %PROJECT_DIR%\logs\client_service.log
echo   Error log:   %PROJECT_DIR%\logs\client_service_error.log
echo.
pause
exit /b 0

:uninstall_service
echo [INFO] Uninstalling AutoTranscription client service...

REM Check if NSSM is available
where nssm >nul 2>&1
if errorlevel 1 (
    echo [X] NSSM not found, cannot uninstall service
    pause
    exit /b 1
)

REM Check if service exists
nssm status "%SERVICE_NAME%" >nul 2>&1
if errorlevel 1 (
    echo [WARNING] Service '%SERVICE_NAME%' does not exist
    exit /b 0
)

REM Stop service if running
echo [INFO] Stopping service...
nssm stop "%SERVICE_NAME%" >nul 2>&1

REM Remove service
echo [INFO] Removing service...
nssm remove "%SERVICE_NAME%" confirm

if errorlevel 1 (
    echo [X] Failed to remove service
    pause
    exit /b 1
)

echo [✓] Service '%SERVICE_NAME%' uninstalled successfully
exit /b 0

:show_status
echo [INFO] Viewing service status...
echo.

REM Check if NSSM is available
where nssm >nul 2>&1
if errorlevel 1 (
    echo [X] NSSM not found
    pause
    exit /b 1
)

REM Check if service exists
nssm status "%SERVICE_NAME%" >nul 2>&1
if errorlevel 1 (
    echo [WARNING] Service '%SERVICE_NAME%' is not installed
    pause
    exit /b 1
)

echo Service Status:
nssm status "%SERVICE_NAME%"
echo.

REM Show recent logs
echo Recent logs:
if exist "%PROJECT_DIR%\logs\client_service.log" (
    powershell -Command "Get-Content '%PROJECT_DIR%\logs\client_service.log' -Tail 20"
) else (
    echo Log file does not exist
)

pause
exit /b 0

:enable_service
echo [INFO] Enabling auto-start on boot...

REM Check if service exists
nssm status "%SERVICE_NAME%" >nul 2>&1
if errorlevel 1 (
    echo [X] Service '%SERVICE_NAME%' is not installed
    echo [INFO] Please run: %~nx0 install
    pause
    exit /b 1
)

nssm set "%SERVICE_NAME%" Start SERVICE_AUTO_START

if errorlevel 1 (
    echo [X] Failed to enable auto-start
    pause
    exit /b 1
)

echo [✓] Auto-start on boot enabled
pause
exit /b 0

:disable_service
echo [INFO] Disabling auto-start on boot...

REM Check if service exists
nssm status "%SERVICE_NAME%" >nul 2>&1
if errorlevel 1 (
    echo [X] Service '%SERVICE_NAME%' is not installed
    pause
    exit /b 1
)

nssm set "%SERVICE_NAME%" Start SERVICE_DEMAND_START

if errorlevel 1 (
    echo [X] Failed to disable auto-start
    pause
    exit /b 1
)

echo [✓] Auto-start on boot disabled
pause
exit /b 0

:start_service
echo [INFO] Starting client service...

REM Check if service exists
nssm status "%SERVICE_NAME%" >nul 2>&1
if errorlevel 1 (
    echo [X] Service '%SERVICE_NAME%' is not installed
    echo [INFO] Please run: %~nx0 install
    pause
    exit /b 1
)

nssm start "%SERVICE_NAME%"

if errorlevel 1 (
    echo [X] Failed to start service
    pause
    exit /b 1
)

echo [✓] Client service started successfully
pause
exit /b 0

:stop_service
echo [INFO] Stopping client service...

REM Check if service exists
nssm status "%SERVICE_NAME%" >nul 2>&1
if errorlevel 1 (
    echo [X] Service '%SERVICE_NAME%' is not installed
    pause
    exit /b 1
)

nssm stop "%SERVICE_NAME%"

if errorlevel 1 (
    echo [X] Failed to stop service
    pause
    exit /b 1
)

echo [✓] Client service stopped successfully
pause
exit /b 0

:restart_service
echo [INFO] Restarting client service...

REM Check if service exists
nssm status "%SERVICE_NAME%" >nul 2>&1
if errorlevel 1 (
    echo [X] Service '%SERVICE_NAME%' is not installed
    echo [INFO] Please run: %~nx0 install
    pause
    exit /b 1
)

nssm restart "%SERVICE_NAME%"

if errorlevel 1 (
    echo [X] Failed to restart service
    pause
    exit /b 1
)

echo [✓] Client service restarted successfully
pause
exit /b 0
