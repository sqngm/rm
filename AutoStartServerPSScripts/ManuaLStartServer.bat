@echo off

:restart
:: ���� RumbleverseClient ��ע�� Server.dll
start /b "" ..\Rumbleverse\Binaries\Win64\RumbleverseClient-Win64-Shipping.exe "-log" "-windowed" "-nullrhi"
echo �ȴ�����˳�ʼ��...
timeout /t 20 /nobreak

:: ִ��ע�����
.\Injector.exe --process-name RumbleverseClient-Win64-Shipping.exe --inject .\Server.dll
echo Injection complete.

:: ��� CMD ����
cls

:checkProcess
:: ʹ�� wmic ��� RumbleverseClient �Ƿ�������
wmic process where "name='RumbleverseClient-Win64-Shipping.exe'" get name | findstr /I "RumbleverseClient-Win64-Shipping.exe" >nul

if %ERRORLEVEL% == 0 (
    :: ������̻������У��ȴ� 5 ����ٴμ��
    echo �������������
    timeout /t 5 /nobreak >nul
    goto checkProcess
    cls
) else (
    :: ��������ѹرգ�����������ע��
    goto restart
)

pause