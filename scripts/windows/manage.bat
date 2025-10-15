@echo off
REM AutoTranscription Windows Management Script
REM Provides one-click installation, startup, and management functions

setlocal EnableDelayedExpansion

REM Configuration variables
set "PROJECT_DIR=%~dp0..\.."
set "SCRIPT_NAME=%~nx0"

REM Color codes (using PowerShell for colored output)
REM 0=Black 1=DarkBlue 2=DarkGreen 3=DarkCyan 4=DarkRed 5=DarkMagenta 6=DarkYellow 7=Gray
REM 8=DarkGray 9=Blue 10=Green 11=Cyan 12=Red 13=Magenta 14=Yellow 15=White

REM Display banner
call :show_banner

REM Parse command
if "%1"=="" goto :show_help
if "%1"=="install" goto :install_system
if "%1"=="install-client" goto :install_client_only
if "%1"=="install-server" goto :install_server_only
if "%1"=="start" goto :start_system
if "%1"=="stop" goto :stop_system
if "%1"=="restart" goto :restart_system
if "%1"=="server" goto :manage_server
if "%1"=="client" goto :start_client
if "%1"=="status" goto :show_status
if "%1"=="clean" goto :clean_system
if "%1"=="reset" goto :reset_system
if "%1"=="-h" goto :show_help
if "%1"=="--help" goto :show_help
if "%1"=="help" goto :show_help

echo [ERROR] Unknown command: %1
echo.
goto :show_help

:show_banner
echo.
echo               _        _
echo   __ _ _   _^| ^|_ ___ ^| ^|_ _ __ __ _ _ __  ___
echo  / _` ^| ^| ^| ^| __/ _ \^| __^| '__/ _` ^| '_ \/ __^|
echo ^| (_^| ^| ^|_^| ^| ^|^| (_) ^| ^|_^| ^| ^| (_^| ^| ^| ^| \__ \
echo  \__,_^\__,_^\__\___/ \__^|_^|  \__,_^|_^| ^|_^|___/
echo.
echo          AI TRANSCRIPTION SYSTEM (Windows)
echo.
goto :eof

:show_help
echo AutoTranscription Windows Management Script
echo.
echo Usage: %SCRIPT_NAME% ^<command^> [options]
echo.
echo Commands:
echo     install         Install complete system dependencies
echo     install-client  Install client dependencies only
echo     install-server  Install server dependencies only
echo     start           Start server and client
echo     stop            Stop server and client
echo     restart         Restart server and client
echo     server          Manage server (start^|stop^|restart^|status^|logs^|health)
echo     client          Start client
echo     status          Show system status
echo     clean           Clean system (keep configuration)
echo     reset           Complete system reset (delete all data)
echo     -h, --help      Show this help message
echo.
echo Examples:
echo     %SCRIPT_NAME% install             # Install complete system
echo     %SCRIPT_NAME% install-client      # Install client only
echo     %SCRIPT_NAME% install-server      # Install server only
echo     %SCRIPT_NAME% start               # Start complete system
echo     %SCRIPT_NAME% server start        # Start server only
echo     %SCRIPT_NAME% server status       # Check server status
echo     %SCRIPT_NAME% client              # Start client
echo     %SCRIPT_NAME% status              # View system status
echo.
goto :end

:install_system
echo [STEP] Starting AutoTranscription complete system installation...
call "%PROJECT_DIR%\scripts\windows\install_deps.bat" full
if errorlevel 1 (
    echo [ERROR] Installation failed
    exit /b 1
)
echo [SUCCESS] Complete system installation finished!
echo.
echo Next steps:
echo   %SCRIPT_NAME% start     # Start system
echo   %SCRIPT_NAME% server    # Manage server
echo   %SCRIPT_NAME% client    # Start client
echo.
echo Activate environment: conda activate autotranscription
goto :end

:install_client_only
echo [STEP] Starting client dependencies installation...
call "%PROJECT_DIR%\scripts\windows\install_deps.bat" client
if errorlevel 1 (
    echo [ERROR] Installation failed
    exit /b 1
)
echo [SUCCESS] Client dependencies installation finished!
echo.
echo Next steps:
echo   %SCRIPT_NAME% client    # Start client
echo.
echo Activate environment: conda activate autotranscription
echo.
echo To connect to server:
echo   1. Ensure server is running
echo   2. Modify server_url in config\client_config.json
echo   3. Run %SCRIPT_NAME% client
goto :end

:install_server_only
echo [STEP] Starting server dependencies installation...
call "%PROJECT_DIR%\scripts\windows\install_deps.bat" server
if errorlevel 1 (
    echo [ERROR] Installation failed
    exit /b 1
)
echo [SUCCESS] Server dependencies installation finished!
echo.
echo Next steps:
echo   %SCRIPT_NAME% server start     # Start server
echo   %SCRIPT_NAME% server status    # Check server status
echo.
echo Activate environment: conda activate autotranscription
goto :end

:start_system
echo [STEP] Starting AutoTranscription system...

REM Check conda installation
where conda >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Conda not installed, please run: %SCRIPT_NAME% install
    exit /b 1
)

REM Check environment
conda env list | findstr /C:"autotranscription" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Conda environment not created, please run: %SCRIPT_NAME% install
    exit /b 1
)

REM Start server
echo [INFO] Starting server...
call "%PROJECT_DIR%\scripts\windows\start_server.bat" start
if errorlevel 1 (
    echo [ERROR] Failed to start server
    exit /b 1
)

REM Wait for server to start
timeout /t 3 /nobreak >nul

REM Start client in background
echo [INFO] Starting client...
start "" /B call "%PROJECT_DIR%\scripts\windows\start_client.bat" start

REM Wait for client to start
timeout /t 2 /nobreak >nul

echo.
echo [SUCCESS] System started!
echo.
echo Server address: http://localhost:5000
echo Hotkey: Check key_combo in config\client_config.json
echo View status: %SCRIPT_NAME% status
echo.
echo Conda environment: conda activate autotranscription
goto :end

:stop_system
echo [STEP] Stopping AutoTranscription system...

REM Stop client processes
echo [INFO] Stopping client...
taskkill /F /IM python.exe /FI "WINDOWTITLE eq *client.py*" >nul 2>&1
taskkill /F /FI "IMAGENAME eq python.exe" /FI "COMMANDLINE eq *client.py*" >nul 2>&1

REM Stop server
echo [INFO] Stopping server...
call "%PROJECT_DIR%\scripts\windows\start_server.bat" stop

echo [SUCCESS] System stopped
goto :end

:restart_system
echo [STEP] Restarting AutoTranscription system...
call :stop_system
timeout /t 2 /nobreak >nul
call :start_system
goto :end

:manage_server
if "%2"=="" (
    echo [ERROR] Please specify server command: start^|stop^|restart^|status^|logs^|health
    exit /b 1
)
call "%PROJECT_DIR%\scripts\windows\start_server.bat" %2
goto :end

:start_client
REM Check conda installation
where conda >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Conda not installed, please run: %SCRIPT_NAME% install
    exit /b 1
)

REM Check environment
conda env list | findstr /C:"autotranscription" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Conda environment not created, please run: %SCRIPT_NAME% install
    exit /b 1
)

REM Check server connection
call "%PROJECT_DIR%\scripts\windows\start_client.bat" check >nul 2>&1
if errorlevel 1 (
    echo [WARNING] Server may not be running, client might not work properly
    echo [INFO] If standalone mode, please run: %SCRIPT_NAME% server start
    echo [INFO] If remote server, please check server_url in config\client_config.json
    echo.
)

REM Start client
call "%PROJECT_DIR%\scripts\windows\start_client.bat" start
goto :end

:show_status
echo System Status Check
echo ================================
echo.

REM Check Conda installation
where conda >nul 2>&1
if errorlevel 1 (
    echo [X] Conda: Not installed
) else (
    echo [+] Conda: Installed
    conda --version 2>nul | findstr /C:"conda"

    REM Check AutoTranscription environment
    conda env list | findstr /C:"autotranscription" >nul 2>&1
    if errorlevel 1 (
        echo [X] Conda environment: Not created
    ) else (
        echo [+] Conda environment: Created
    )
)

REM Check configuration files
if exist "%PROJECT_DIR%\config\server_config.json" (
    echo [+] Server configuration: Created
) else (
    echo [X] Server configuration: Not created
)

if exist "%PROJECT_DIR%\config\client_config.json" (
    echo [+] Client configuration: Created
) else (
    echo [X] Client configuration: Not created
)

REM Check server status
if exist "%PROJECT_DIR%\logs\transcription_server.pid" (
    set /p SERVER_PID=<"%PROJECT_DIR%\logs\transcription_server.pid"
    tasklist /FI "PID eq !SERVER_PID!" 2>nul | find "!SERVER_PID!" >nul
    if not errorlevel 1 (
        echo [+] Server: Running
        echo     - PID: !SERVER_PID!

        REM Try to get server details
        curl -s "http://localhost:5000/api/health" >nul 2>&1
        if not errorlevel 1 (
            echo     - Status: healthy
        )
    ) else (
        echo [X] Server: Not running
        del "%PROJECT_DIR%\logs\transcription_server.pid" 2>nul
    )
) else (
    echo [X] Server: Not running
)

REM Check client process status
tasklist 2>nul | findstr /I "python.exe" | findstr /I "client.py" >nul 2>&1
if not errorlevel 1 (
    echo [+] Client process: Running
) else (
    echo [X] Client process: Not running
)

REM Check GPU support
where nvidia-smi >nul 2>&1
if not errorlevel 1 (
    nvidia-smi --query-gpu=name --format=csv,noheader,nounits 2>nul | head -1
    if not errorlevel 1 (
        echo [+] GPU: Detected
    )
) else (
    echo [X] GPU: Not detected
)

echo ================================
goto :end

:clean_system
echo [STEP] Cleaning AutoTranscription system...

REM Stop services
call "%PROJECT_DIR%\scripts\windows\start_server.bat" stop >nul 2>&1

REM Clean logs
if exist "%PROJECT_DIR%\logs" (
    rmdir /S /Q "%PROJECT_DIR%\logs" 2>nul
    echo [INFO] Cleaned log files
)

REM Clean Python cache
for /d /r "%PROJECT_DIR%" %%d in (__pycache__) do @if exist "%%d" rd /s /q "%%d" 2>nul
echo [INFO] Cleaned Python cache

echo [SUCCESS] System cleaned
goto :end

:reset_system
echo [WARNING] This will delete all data and configuration!
set /p CONFIRM="Type 'RESET' to confirm reset: "
if not "%CONFIRM%"=="RESET" (
    echo [INFO] Reset cancelled
    goto :end
)

echo [STEP] Resetting AutoTranscription system...

REM Stop services
call "%PROJECT_DIR%\scripts\windows\start_server.bat" stop >nul 2>&1

REM Delete Conda environment
where conda >nul 2>&1
if not errorlevel 1 (
    conda env list | findstr /C:"autotranscription" >nul 2>&1
    if not errorlevel 1 (
        conda env remove -n autotranscription -y
        echo [INFO] Deleted Conda environment
    )
)

REM Clean all files
call :clean_system

echo [SUCCESS] System reset complete
echo [INFO] Please run '%SCRIPT_NAME% install' to reinstall
goto :end

:end
endlocal
