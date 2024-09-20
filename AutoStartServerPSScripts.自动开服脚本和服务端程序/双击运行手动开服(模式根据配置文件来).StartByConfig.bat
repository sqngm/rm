@echo off

:restart
:: 启动 RumbleverseClient 并注入 Server.dll
start /b "" ..\Rumbleverse\Binaries\Win64\RumbleverseClient-Win64-Shipping.exe "-log" "-windowed" "-nullrhi"
echo 等待服务端初始化...
timeout /t 20 /nobreak

:: 执行注入操作
.\Injector.exe --process-name RumbleverseClient-Win64-Shipping.exe --inject .\Server.dll
echo Injection complete.

:: 清空 CMD 窗口
cls

:checkProcess
:: 使用 wmic 检查 RumbleverseClient 是否在运行
wmic process where "name='RumbleverseClient-Win64-Shipping.exe'" get name | findstr /I "RumbleverseClient-Win64-Shipping.exe" >nul

if %ERRORLEVEL% == 0 (
    :: 如果进程还在运行，等待 5 秒后再次检查
    echo 服务端正在运行
    timeout /t 5 /nobreak >nul
    goto checkProcess
    cls
) else (
    :: 如果进程已关闭，重新启动并注入
    goto restart
)

pause