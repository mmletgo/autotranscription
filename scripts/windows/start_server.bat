@echo off
REM AutoTranscription Windows Server Management Script
REM Manages high-concurrency transcription server

setlocal EnableDelayedExpansion

REM Configuration
set "PROJECT_DIR=%~dp0..\.."
set "SCRIPT_NAME=%~nx0"
set "SERVER_SCRIPT=%PROJECT_DIR%\server\transcription_server.py"
set "CONFIG_FILE=%PROJECT_DIR%\config\server_config.json"
set "PID_FILE=%PROJECT_DIR%\logs\transcription_server.pid"
set "LOG_FILE=%PROJECT_DIR%\logs\transcription_server.log"
set "ERROR_LOG_FILE=%PROJECT_DIR%\logs\transcription_server_error.log"

REM Parse command
if "%1"=="" goto :show_help
if "%1"=="start" goto :start_server
if "%1"=="stop" goto :stop_server
if "%1"=="restart" goto :restart_server
if "%1"=="status" goto :show_status
if "%1"=="logs" goto :show_logs
if "%1"=="health" goto :health_check
if "%1"=="config" goto :show_config
if "%1"=="-h" goto :show_help
if "%1"=="--help" goto :show_help

echo [ERROR] Unknown command: %1
goto :show_help

:show_help
echo AutoTranscription Server Management Script
echo.
echo Usage: %SCRIPT_NAME% ^<command^>
echo.
echo Commands:
echo     start       Start server
echo     stop        Stop server
echo     restart     Restart server
echo     status      Show server status
echo     logs        Show server logs
echo     health      Health check
echo     config      Show configuration
echo     -h, --help  Show this help message
echo.
echo Examples:
echo     %SCRIPT_NAME% start       # Start server
echo     %SCRIPT_NAME% stop        # Stop server
echo     %SCRIPT_NAME% status      # Check status
echo     %SCRIPT_NAME% logs        # View logs
echo.
goto :end

:start_server
echo [INFO] Starting AutoTranscription server...

REM Check if already running
if exist "%PID_FILE%" (
    set /p SERVER_PID=<"%PID_FILE%"
    tasklist /FI "PID eq !SERVER_PID!" 2>nul | find "!SERVER_PID!" >nul
    if not errorlevel 1 (
        echo [WARNING] Server is already running (PID: !SERVER_PID!^)
        echo [INFO] Use '%SCRIPT_NAME% stop' to stop it first
        goto :end
    )
    REM Clean up stale PID file
    del "%PID_FILE%" 2>nul
)

REM Check conda environment
where conda >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Conda not found. Please install Miniconda
    exit /b 1
)

REM Check if environment exists
conda env list | findstr /C:"autotranscription" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Conda environment 'autotranscription' not found
    echo [INFO] Please run: scripts\windows\manage.bat install
    exit /b 1
)

REM Check if server script exists
if not exist "%SERVER_SCRIPT%" (
    echo [ERROR] Server script not found: %SERVER_SCRIPT%
    exit /b 1
)

REM Check if config exists
if not exist "%CONFIG_FILE%" (
    echo [ERROR] Configuration file not found: %CONFIG_FILE%
    echo [INFO] Please run: scripts\windows\manage.bat install
    exit /b 1
)

REM Create logs directory
if not exist "%PROJECT_DIR%\logs" mkdir "%PROJECT_DIR%\logs"

echo [INFO] Activating conda environment...
call conda activate autotranscription
if errorlevel 1 (
    echo [ERROR] Failed to activate conda environment
    exit /b 1
)

echo [INFO] Starting server with configuration: %CONFIG_FILE%

REM Start server in background using start command
start "AutoTranscription Server" /B python "%SERVER_SCRIPT%" > "%LOG_FILE%" 2> "%ERROR_LOG_FILE%"

REM Wait a moment for server to start
timeout /t 2 /nobreak >nul

REM Get the PID of the python process running the server
for /f "tokens=2" %%i in ('tasklist /FI "IMAGENAME eq python.exe" /FI "WINDOWTITLE eq AutoTranscription Server" /NH 2^>nul ^| find "python.exe"') do (
    set "SERVER_PID=%%i"
    echo !SERVER_PID! > "%PID_FILE%"
    echo [SUCCESS] Server started (PID: !SERVER_PID!^)
    echo [INFO] Server address: http://localhost:5000
    echo [INFO] Log file: %LOG_FILE%
    echo [INFO] Error log: %ERROR_LOG_FILE%
    goto :health_wait
)

REM Alternative method: get any python.exe PID running transcription_server
for /f "tokens=2" %%i in ('wmic process where "name='python.exe' and commandline like '%%transcription_server%%'" get processid /format:value 2^>nul ^| find "="') do (
    set "PROC_LINE=%%i"
    set "SERVER_PID=!PROC_LINE:~10!"
    if not "!SERVER_PID!"=="" (
        echo !SERVER_PID! > "%PID_FILE%"
        echo [SUCCESS] Server started (PID: !SERVER_PID!^)
        echo [INFO] Server address: http://localhost:5000
        echo [INFO] Log file: %LOG_FILE%
        echo [INFO] Error log: %ERROR_LOG_FILE%
        goto :health_wait
    )
)

echo [WARNING] Server process started but PID not captured
echo [INFO] Check logs for details: %LOG_FILE%
goto :end

:health_wait
echo [INFO] Waiting for server to be ready...
timeout /t 3 /nobreak >nul
call :health_check
goto :end

:stop_server
echo [INFO] Stopping AutoTranscription server...

if not exist "%PID_FILE%" (
    REM Try to find and kill any running server process
    for /f "tokens=2" %%i in ('wmic process where "name='python.exe' and commandline like '%%transcription_server%%'" get processid /format:value 2^>nul ^| find "="') do (
        set "PROC_LINE=%%i"
        set "SERVER_PID=!PROC_LINE:~10!"
        if not "!SERVER_PID!"=="" (
            echo [INFO] Found server process (PID: !SERVER_PID!^)
            taskkill /F /PID !SERVER_PID! >nul 2>&1
            echo [SUCCESS] Server stopped
            goto :end
        )
    )
    echo [WARNING] Server is not running or PID file not found
    goto :end
)

set /p SERVER_PID=<"%PID_FILE%"
echo [INFO] Stopping server (PID: %SERVER_PID%^)...

tasklist /FI "PID eq %SERVER_PID%" 2>nul | find "%SERVER_PID%" >nul
if errorlevel 1 (
    echo [WARNING] Server process not found, cleaning up PID file
    del "%PID_FILE%" 2>nul
    goto :end
)

taskkill /F /PID %SERVER_PID% >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Failed to stop server
    exit /b 1
)

del "%PID_FILE%" 2>nul
echo [SUCCESS] Server stopped
goto :end

:restart_server
echo [INFO] Restarting AutoTranscription server...
call :stop_server
timeout /t 2 /nobreak >nul
call :start_server
goto :end

:show_status
echo ========================================
echo AutoTranscription Server Status
echo ========================================
echo.

if not exist "%PID_FILE%" (
    echo Status: [NOT RUNNING]
    echo.
    REM Check if any server process is actually running
    for /f "tokens=2" %%i in ('wmic process where "name='python.exe' and commandline like '%%transcription_server%%'" get processid /format:value 2^>nul ^| find "="') do (
        set "PROC_LINE=%%i"
        set "SERVER_PID=!PROC_LINE:~10!"
        if not "!SERVER_PID!"=="" (
            echo Warning: Found orphaned server process (PID: !SERVER_PID!^)
            echo Use '%SCRIPT_NAME% stop' to clean up
            goto :end
        )
    )
    goto :end
)

set /p SERVER_PID=<"%PID_FILE%"
tasklist /FI "PID eq %SERVER_PID%" 2>nul | find "%SERVER_PID%" >nul
if errorlevel 1 (
    echo Status: [NOT RUNNING]
    echo Note: Stale PID file found, cleaning up
    del "%PID_FILE%" 2>nul
    goto :end
)

echo Status: [RUNNING]
echo PID: %SERVER_PID%
echo.

REM Try to get server health info via API
curl -s "http://localhost:5000/api/health" >nul 2>&1
if not errorlevel 1 (
    echo API Status: Online
    echo Server URL: http://localhost:5000
    echo.
    echo Health Information:
    for /f "delims=" %%i in ('curl -s "http://localhost:5000/api/health"') do echo %%i
) else (
    echo API Status: Not responding
    echo Note: Server process running but API not accessible
)

echo.
echo Log file: %LOG_FILE%
echo Error log: %ERROR_LOG_FILE%
echo.
goto :end

:show_logs
echo ========================================
echo Server Logs
echo ========================================
echo.

if not exist "%LOG_FILE%" (
    echo [WARNING] Log file not found: %LOG_FILE%
    goto :check_error_log
)

echo === Main Log (last 50 lines^ ) ===
powershell -Command "Get-Content '%LOG_FILE%' -Tail 50"

:check_error_log
if not exist "%ERROR_LOG_FILE%" (
    echo [WARNING] Error log file not found: %ERROR_LOG_FILE%
    goto :end
)

echo.
echo === Error Log (last 50 lines^) ===
powershell -Command "Get-Content '%ERROR_LOG_FILE%' -Tail 50"
goto :end

:health_check
echo ========================================
echo Server Health Check
echo ========================================
echo.

curl -s "http://localhost:5000/api/health" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Server is not responding
    echo.
    echo Troubleshooting:
    echo   - Check if server is running: %SCRIPT_NAME% status
    echo   - Check server logs: %SCRIPT_NAME% logs
    echo   - Check if port 5000 is in use
    exit /b 1
)

echo [SUCCESS] Server is healthy
echo.
echo API Endpoints:
echo   - Health: http://localhost:5000/api/health
echo   - Status: http://localhost:5000/api/status
echo   - Config: http://localhost:5000/api/config
echo.

echo Detailed Health Information:
curl -s "http://localhost:5000/api/health" 2>nul
echo.
goto :end

:show_config
echo ========================================
echo Server Configuration
echo ========================================
echo.

if not exist "%CONFIG_FILE%" (
    echo [ERROR] Configuration file not found: %CONFIG_FILE%
    exit /b 1
)

type "%CONFIG_FILE%"
echo.
echo Configuration file: %CONFIG_FILE%
goto :end

:end
endlocal
