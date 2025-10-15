@echo off
REM AutoTranscription Windows Client Management Script
REM Manages client with hotkey support

setlocal EnableDelayedExpansion

REM Configuration
set "PROJECT_DIR=%~dp0..\.."
set "SCRIPT_NAME=%~nx0"
set "CLIENT_SCRIPT=%PROJECT_DIR%\client\client.py"
set "CONFIG_FILE=%PROJECT_DIR%\config\client_config.json"
set "LOG_FILE=%PROJECT_DIR%\logs\client.log"

REM Parse command
if "%1"=="" goto :start_client
if "%1"=="start" goto :start_client
if "%1"=="check" goto :check_connection
if "%1"=="config" goto :show_config
if "%1"=="-h" goto :show_help
if "%1"=="--help" goto :show_help

echo [ERROR] Unknown command: %1
goto :show_help

:show_help
echo AutoTranscription Client Management Script
echo.
echo Usage: %SCRIPT_NAME% [command]
echo.
echo Commands:
echo     start       Start client (default)
echo     check       Test server connection
echo     config      Show configuration
echo     -h, --help  Show this help message
echo.
echo Examples:
echo     %SCRIPT_NAME%             # Start client
echo     %SCRIPT_NAME% start       # Start client
echo     %SCRIPT_NAME% check       # Test connection
echo     %SCRIPT_NAME% config      # Show config
echo.
echo Environment Variables:
echo     SERVER_URL    Override server URL
echo     HOTKEY        Override hotkey combination
echo.
goto :end

:start_client
echo [INFO] Starting AutoTranscription client...

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
    echo [INFO] Please run: scripts\windows\manage.bat install-client
    exit /b 1
)

REM Check if client script exists
if not exist "%CLIENT_SCRIPT%" (
    echo [ERROR] Client script not found: %CLIENT_SCRIPT%
    exit /b 1
)

REM Check if config exists
if not exist "%CONFIG_FILE%" (
    echo [ERROR] Configuration file not found: %CONFIG_FILE%
    echo [INFO] Please run: scripts\windows\manage.bat install-client
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

REM Check server connection before starting
echo [INFO] Checking server connection...
call :check_connection_internal
if errorlevel 1 (
    echo [WARNING] Server connection check failed
    echo [INFO] Client will start but may not work without server
    timeout /t 2 /nobreak >nul
)

echo [INFO] Starting client...
echo [INFO] Press the hotkey (default: Alt) to start recording
echo [INFO] Press Ctrl+C to stop client
echo.

REM Apply environment variable overrides if set
set "CLIENT_ARGS="
if not "%SERVER_URL%"=="" (
    echo [INFO] Using custom server URL: %SERVER_URL%
    set "CLIENT_ARGS=!CLIENT_ARGS! --server-url %SERVER_URL%"
)
if not "%HOTKEY%"=="" (
    echo [INFO] Using custom hotkey: %HOTKEY%
    set "CLIENT_ARGS=!CLIENT_ARGS! --key-combo %HOTKEY%"
)

REM Start client (foreground)
python "%CLIENT_SCRIPT%" %CLIENT_ARGS%
goto :end

:check_connection
call :check_connection_internal
goto :end

:check_connection_internal
REM Read server URL from config
if not exist "%CONFIG_FILE%" (
    echo [ERROR] Configuration file not found: %CONFIG_FILE%
    exit /b 1
)

REM Extract server_url from JSON config using PowerShell
for /f "delims=" %%i in ('powershell -Command "Get-Content '%CONFIG_FILE%' | ConvertFrom-Json | Select-Object -ExpandProperty server_url"') do set "SERVER_URL=%%i"

if "%SERVER_URL%"=="" (
    echo [ERROR] Could not read server_url from config
    exit /b 1
)

echo [INFO] Testing connection to: %SERVER_URL%

REM Test connection using curl
curl -s --connect-timeout 5 "%SERVER_URL%/api/health" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Cannot connect to server at %SERVER_URL%
    echo.
    echo Troubleshooting:
    echo   - Ensure server is running
    echo   - Check server URL in config\client_config.json
    echo   - Check network connection
    echo   - Check firewall settings
    exit /b 1
)

echo [SUCCESS] Server is reachable
echo.

REM Get server health info
echo Server Health Information:
curl -s "%SERVER_URL%/api/health" 2>nul
echo.
goto :eof

:show_config
echo ========================================
echo Client Configuration
echo ========================================
echo.

if not exist "%CONFIG_FILE%" (
    echo [ERROR] Configuration file not found: %CONFIG_FILE%
    exit /b 1
)

type "%CONFIG_FILE%"
echo.
echo Configuration file: %CONFIG_FILE%
echo.

REM Show current server connection status
echo Server Connection Status:
call :check_connection_internal
goto :end

:end
endlocal
