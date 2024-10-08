@echo off
start /b "" ..\..\Rumbleverse\Binaries\Win64\RumbleverseClient-Win64-Shipping.exe "-log" "-windowed" "-nullrhi"
timeout /t 11 /nobreak
..\Injector.exe --process-name RumbleverseClient-Win64-Shipping.exe --inject .\Playground.dll