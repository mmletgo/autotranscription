@echo off
REM 启用麦克风访问权限 (需要管理员权限)
REM Enable microphone access for desktop apps (requires admin)

echo ========================================
echo 启用Windows麦克风访问权限
echo Enable Microphone Access
echo ========================================
echo.

REM 检查管理员权限
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo 错误: 需要管理员权限
    echo Error: Administrator privileges required
    echo.
    echo 请右键点击此脚本,选择"以管理员身份运行"
    echo Please right-click this script and select "Run as administrator"
    echo.
    pause
    exit /b 1
)

echo 正在修改注册表以允许麦克风访问...
echo Modifying registry to allow microphone access...
echo.

REM 允许麦克风访问 (全局)
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone" /v "Value" /t REG_SZ /d "Allow" /f

REM 允许桌面应用访问麦克风
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone" /v "Value" /t REG_SZ /d "Allow" /f

echo.
echo ========================================
echo 完成! 设置已应用
echo Done! Settings applied
echo ========================================
echo.
echo 请重新运行客户端测试麦克风
echo Please restart the client to test microphone
echo.
pause
