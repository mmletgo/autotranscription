@echo off
REM AutoTranscription Client Service Uninstallation Script for Windows
REM Uses NSSM (Non-Sucking Service Manager) for Windows service management

setlocal enabledelayedexpansion

REM Get script and project directories
set "SCRIPT_DIR=%~dp0"
set "PROJECT_DIR=%SCRIPT_DIR%..\..\"
set "SERVICE_NAME=AutoTranscriptionClient"

REM Parse command line argument
set "ACTION=%~1"
if "%ACTION%"=="" set "ACTION=full"

REM Display help if requested
if "%ACTION%"=="-h" goto :show_help
if "%ACTION%"=="--help" goto :show_help
if "%ACTION%"=="help" goto :show_help

goto :main

:show_help
echo AutoTranscription Client Service Uninstallation Script (Windows)
echo.
echo Usage: %~nx0 [option]
echo.
echo Options:
echo     full        Complete uninstall (default) - Remove service, config and logs
echo     service     Only uninstall service - Keep config and log files
echo     clean       Clean residual files
echo     status      View current status before uninstall
echo     -h, --help  Show this help information
echo.
echo Examples:
echo     %~nx0              # Complete uninstall
echo     %~nx0 full         # Complete uninstall
echo     %~nx0 service      # Only uninstall service
echo     %~nx0 clean        # Clean residual files
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
if /i "%ACTION%"=="full" goto :full_uninstall
if /i "%ACTION%"=="service" goto :service_uninstall
if /i "%ACTION%"=="clean" goto :cleanup_residual
if /i "%ACTION%"=="status" goto :show_status

echo [X] Unknown command: %ACTION%
echo.
goto :show_help

:show_status
echo [INFO] Checking current service status...
echo.

REM Check if NSSM is available
where nssm >nul 2>&1
if errorlevel 1 (
    echo [WARNING] NSSM not found, cannot check service status
    pause
    exit /b 1
)

echo === Service Installation Status ===
echo.

REM Check if service exists
nssm status "%SERVICE_NAME%" >nul 2>&1
if errorlevel 1 (
    echo Service Status: Not installed
) else (
    echo Service Status: Installed
    echo Service Name: %SERVICE_NAME%
    nssm status "%SERVICE_NAME%"
)

echo.
echo === Related Files ===
echo.

if exist "%PROJECT_DIR%\.env" (
    echo Environment file: ^✓ %PROJECT_DIR%\.env
) else (
    echo Environment file: ^X Does not exist
)

if exist "%PROJECT_DIR%\logs" (
    echo Log directory: ^✓ %PROJECT_DIR%\logs
    for %%f in ("%PROJECT_DIR%\logs\*client*.log") do (
        echo   - %%~nxf
    )
) else (
    echo Log directory: ^X Does not exist
)

echo.
echo === Recent Logs ===
if exist "%PROJECT_DIR%\logs\client_service.log" (
    powershell -Command "Get-Content '%PROJECT_DIR%\logs\client_service.log' -Tail 10 -ErrorAction SilentlyContinue"
) else (
    echo Service log: Does not exist
)

pause
exit /b 0

:full_uninstall
echo [INFO] Starting complete uninstallation of AutoTranscription client service...
echo.

REM Show current status first
call :show_status_brief

echo.
set /p CONFIRM="Confirm complete uninstall? This will delete all related files [y/N]: "
if /i not "%CONFIRM%"=="y" (
    echo [INFO] Uninstall cancelled
    pause
    exit /b 0
)

REM Stop and disable service
call :stop_and_disable_service

REM Remove service files
call :remove_service_files

REM Remove environment file
call :remove_env_file

REM Cleanup logs
call :cleanup_logs

echo.
echo === Complete Uninstallation Finished ===
echo.
echo Deleted components:
echo   ^✓ Windows service configuration
echo   ^✓ Environment variable file
echo   ^✓ Client log files
echo.
echo Retained components:
echo   ^✓ Project source code
echo   ^✓ Configuration files (config/)
echo   ^✓ Conda environment
echo   ^✓ Server-related files
echo.
echo To reinstall service, run:
echo   scripts\windows\install_client_service.bat install
echo.
pause
exit /b 0

:service_uninstall
echo [INFO] Uninstalling system service (keeping config and logs)...
echo.

REM Stop and disable service
call :stop_and_disable_service

REM Remove service files
call :remove_service_files

REM Remove environment file
call :remove_env_file

echo.
echo === Service Uninstallation Finished ===
echo.
echo Deleted:
echo   ^✓ Windows service configuration
echo   ^✓ Environment variable file
echo.
echo Retained files:
echo   ^✓ Configuration files (config\client_config.json)
echo   ^✓ Log files (logs\)
echo   ^✓ Project source code
echo   ^✓ Conda environment
echo.
echo To reinstall service, run:
echo   scripts\windows\install_client_service.bat install
echo.
pause
exit /b 0

:cleanup_residual
echo [INFO] Cleaning residual files...

set "CLEANED=0"

REM Check if NSSM is available
where nssm >nul 2>&1
if not errorlevel 1 (
    REM Check for residual Windows service
    nssm status "%SERVICE_NAME%" >nul 2>&1
    if not errorlevel 1 (
        echo [INFO] Found residual Windows service
        nssm remove "%SERVICE_NAME%" confirm >nul 2>&1
        if not errorlevel 1 (
            echo [✓] Removed residual Windows service
            set "CLEANED=1"
        )
    )
)

REM Check for environment file
if exist "%PROJECT_DIR%\.env" (
    echo [INFO] Found residual environment file
    del /f /q "%PROJECT_DIR%\.env" >nul 2>&1
    if not errorlevel 1 (
        echo [✓] Removed residual environment file
        set "CLEANED=1"
    )
)

if "%CLEANED%"=="1" (
    echo [✓] Residual files cleanup completed
) else (
    echo [INFO] No residual files found
)

pause
exit /b 0

:show_status_brief
echo === Current Service Status ===
where nssm >nul 2>&1
if errorlevel 1 (
    echo NSSM Status: Not installed
    echo Service Status: Cannot check
) else (
    nssm status "%SERVICE_NAME%" >nul 2>&1
    if errorlevel 1 (
        echo Service Status: Not installed
    ) else (
        echo Service Status: Installed
    )
)
goto :eof

:stop_and_disable_service
echo [INFO] Stopping and disabling service...

where nssm >nul 2>&1
if errorlevel 1 (
    echo [WARNING] NSSM not found, cannot manage service
    goto :eof
)

REM Check if service exists
nssm status "%SERVICE_NAME%" >nul 2>&1
if errorlevel 1 (
    echo [INFO] Service not running
    goto :eof
)

REM Stop service
echo [INFO] Stopping service...
nssm stop "%SERVICE_NAME%" >nul 2>&1
if errorlevel 1 (
    echo [WARNING] Failed to stop service
) else (
    echo [✓] Service stopped
)

REM Disable auto-start
echo [INFO] Disabling auto-start...
nssm set "%SERVICE_NAME%" Start SERVICE_DEMAND_START >nul 2>&1
if errorlevel 1 (
    echo [WARNING] Failed to disable auto-start
) else (
    echo [✓] Auto-start disabled
)
goto :eof

:remove_service_files
echo [INFO] Removing service files...

where nssm >nul 2>&1
if errorlevel 1 (
    echo [X] NSSM not found, cannot remove service
    goto :eof
)

REM Check if service exists
nssm status "%SERVICE_NAME%" >nul 2>&1
if errorlevel 1 (
    echo [INFO] Windows service does not exist
    goto :eof
)

REM Remove service
echo [INFO] Removing Windows service...
nssm remove "%SERVICE_NAME%" confirm >nul 2>&1
if errorlevel 1 (
    echo [X] Failed to remove Windows service
) else (
    echo [✓] Windows service removed
)
goto :eof

:remove_env_file
echo [INFO] Removing environment configuration file...

if exist "%PROJECT_DIR%\.env" (
    echo [INFO] Deleting environment file: %PROJECT_DIR%\.env
    del /f /q "%PROJECT_DIR%\.env" >nul 2>&1
    if errorlevel 1 (
        echo [X] Failed to delete environment file
    ) else (
        echo [✓] Environment file deleted
    )
) else (
    echo [INFO] Environment file does not exist
)
goto :eof

:cleanup_logs
echo [INFO] Cleaning client log files...

if not exist "%PROJECT_DIR%\logs" (
    echo [INFO] Log directory does not exist
    goto :eof
)

set "CLEANED=0"
for %%f in ("%PROJECT_DIR%\logs\*client*.log") do (
    echo [INFO] Deleting log file: %%~nxf
    del /f /q "%%f" >nul 2>&1
    if not errorlevel 1 set "CLEANED=1"
)

if "%CLEANED%"=="1" (
    echo [✓] Client log files cleaned
) else (
    echo [INFO] No client log files found
)
goto :eof
