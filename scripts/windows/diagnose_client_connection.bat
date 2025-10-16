@echo off
REM Client connection diagnostic script for Windows
REM Run this script on the client machine to diagnose connection issues

setlocal enabledelayedexpansion

REM Default server configuration
set "SERVER_IP=192.168.6.142"
set "SERVER_PORT=5000"

REM Check if user provided server IP as parameter
if not "%~1"=="" set "SERVER_IP=%~1"
if not "%~2"=="" set "SERVER_PORT=%~2"

echo ========================================
echo AutoTranscription Client Connection Diagnostic
echo ========================================
echo.
echo Server IP: %SERVER_IP%
echo Server Port: %SERVER_PORT%
echo.

REM 1. Check network connectivity
echo [1/6] Checking network connectivity...
ping -n 3 %SERVER_IP% >nul 2>&1
if errorlevel 1 (
    echo [X] Cannot ping server %SERVER_IP%
    echo    Please check:
    echo    - Are client and server on the same network?
    echo    - Does server firewall allow ICMP?
    exit /b 1
) else (
    echo [✓] Network connectivity normal
)
echo.

REM 2. Check port connectivity
echo [2/6] Checking port %SERVER_PORT% connectivity...
REM Use PowerShell to test TCP connection
powershell -Command "$test = Test-NetConnection -ComputerName %SERVER_IP% -Port %SERVER_PORT% -InformationLevel Quiet -WarningAction SilentlyContinue; if($test) { exit 0 } else { exit 1 }" >nul 2>&1
if errorlevel 1 (
    echo [X] Cannot connect to port %SERVER_PORT%
    echo    Please check:
    echo    - Is the server running?
    echo    - Does server firewall allow port %SERVER_PORT%?
    exit /b 1
) else (
    echo [✓] Port %SERVER_PORT% is accessible
)
echo.

REM 3. Check proxy settings
echo [3/6] Checking proxy settings...
set "PROXY_DETECTED=0"
if not "%http_proxy%"=="" (
    echo [WARNING] Proxy detected:
    echo    http_proxy=%http_proxy%
    set "PROXY_DETECTED=1"
)
if not "%https_proxy%"=="" (
    echo    https_proxy=%https_proxy%
    set "PROXY_DETECTED=1"
)
if not "%HTTP_PROXY%"=="" (
    echo    HTTP_PROXY=%HTTP_PROXY%
    set "PROXY_DETECTED=1"
)
if not "%HTTPS_PROXY%"=="" (
    echo    HTTPS_PROXY=%HTTPS_PROXY%
    set "PROXY_DETECTED=1"
)

if "%PROXY_DETECTED%"=="1" (
    echo.
    echo    Proxy may interfere with LAN connection, recommend temporarily disabling:
    echo    set no_proxy=%SERVER_IP%,localhost,127.0.0.1
    echo    Or:
    echo    set http_proxy=
    echo    set https_proxy=
) else (
    echo [✓] No proxy settings detected
)
echo.

REM 4. Test HTTP connection
echo [4/6] Testing HTTP API connection...
REM Use curl if available, otherwise use PowerShell
where curl >nul 2>&1
if errorlevel 1 (
    REM Use PowerShell Invoke-WebRequest
    powershell -Command "$ProgressPreference = 'SilentlyContinue'; try { $response = Invoke-WebRequest -Uri 'http://%SERVER_IP%:%SERVER_PORT%/api/health' -TimeoutSec 5 -UseBasicParsing; Write-Host '[✓] HTTP API connection successful'; Write-Host '   Response:' $response.Content; exit 0 } catch { Write-Host '[X] HTTP API connection failed'; Write-Host '   Error:' $_.Exception.Message; exit 1 }"
    if errorlevel 1 (
        exit /b 1
    )
) else (
    REM Use curl
    curl -s -w "\n%%{http_code}" --connect-timeout 5 http://%SERVER_IP%:%SERVER_PORT%/api/health > "%TEMP%\curl_response.txt" 2>&1

    REM Read response
    set /p RESPONSE=<"%TEMP%\curl_response.txt"

    REM Get HTTP code from last line
    for /f %%i in ('type "%TEMP%\curl_response.txt" ^| find /c /v ""') do set "LINE_COUNT=%%i"

    REM Simple check - if response contains "status" or "healthy", consider it success
    findstr /C:"status" /C:"healthy" "%TEMP%\curl_response.txt" >nul 2>&1
    if errorlevel 1 (
        echo [X] HTTP API connection failed
        type "%TEMP%\curl_response.txt"
        del "%TEMP%\curl_response.txt" >nul 2>&1
        exit /b 1
    ) else (
        echo [✓] HTTP API connection successful
        type "%TEMP%\curl_response.txt"
        del "%TEMP%\curl_response.txt" >nul 2>&1
    )
)
echo.

REM 5. Check local network configuration
echo [5/6] Checking local network configuration...
echo Local IP addresses:
ipconfig | findstr /C:"IPv4"
echo.
echo Default gateway:
ipconfig | findstr /C:"Default Gateway"
echo.

REM 6. Test transcription API (optional)
echo [6/6] Test transcription API (optional)...
set /p TEST_TRANSCRIBE="Do you want to test transcription API? This will send a small audio sample (y/n): "

if /i "%TEST_TRANSCRIBE%"=="y" (
    echo Testing transcription API...

    REM Use PowerShell to send POST request
    powershell -Command "$ProgressPreference = 'SilentlyContinue'; try { $body = @{audio=@(); sample_rate=16000} | ConvertTo-Json; $response = Invoke-WebRequest -Uri 'http://%SERVER_IP%:%SERVER_PORT%/api/transcribe' -Method POST -Body $body -ContentType 'application/json' -TimeoutSec 10 -UseBasicParsing; Write-Host '[✓] Transcription API accessible (Status:' $response.StatusCode ')'; exit 0 } catch { if($_.Exception.Response.StatusCode -eq 400) { Write-Host '[✓] Transcription API accessible (Status: 400 - expected for empty audio)'; exit 0 } else { Write-Host '[WARNING] Transcription API response abnormal (Status:' $_.Exception.Response.StatusCode ')'; exit 0 } }"
) else (
    echo Skipping transcription API test
)
echo.

echo ========================================
echo Diagnostic Complete!
echo ========================================
echo.
echo If all checks passed, please confirm client configuration:
echo 1. Check server_url in config\client_config.json
echo 2. Ensure it is set to: "server_url": "http://%SERVER_IP%:%SERVER_PORT%"
echo 3. If using proxy, add no_proxy environment variable
echo.
echo Start client command:
echo    scripts\windows\manage.bat client
echo.

pause
exit /b 0
