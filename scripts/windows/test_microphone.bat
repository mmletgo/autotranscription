@echo off
REM Windows麦克风测试脚本
REM Test microphone input on Windows

setlocal

REM 尝试多个可能的Miniconda路径
set "MINICONDA_PATH="

REM 首先尝试 ProgramData (系统级安装)
if exist "C:\ProgramData\miniconda3\Scripts\conda.exe" (
    set "MINICONDA_PATH=C:\ProgramData\miniconda3"
)

REM 然后尝试用户目录
if "%MINICONDA_PATH%"=="" (
    if exist "%USERPROFILE%\miniconda3\Scripts\conda.exe" (
        set "MINICONDA_PATH=%USERPROFILE%\miniconda3"
    )
)

REM 检查是否找到Miniconda
if "%MINICONDA_PATH%"=="" (
    echo Error: Miniconda not found
    echo Tried:
    echo   - C:\ProgramData\miniconda3
    echo   - %USERPROFILE%\miniconda3
    echo Please run install_deps.bat first
    pause
    exit /b 1
)

echo Found Miniconda at: %MINICONDA_PATH%

REM 激活conda环境
echo Activating conda environment...
call "%MINICONDA_PATH%\Scripts\activate.bat" "%MINICONDA_PATH%"
call conda activate autotranscription

REM 运行麦克风测试
echo.
echo ========================================
echo Windows Microphone Test Tool
echo ========================================
echo.

python "%~dp0test_microphone.py"

echo.
pause
