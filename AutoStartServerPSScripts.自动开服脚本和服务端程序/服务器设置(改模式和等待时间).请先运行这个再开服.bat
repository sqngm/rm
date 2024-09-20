@echo off
if not exist "..\Rumbleverse\Binaries\Win64\Config.ini" (
    copy "Config.ini" "..\Rumbleverse\Binaries\Win64\Config.ini"
)

@REM copy "Config.ini" "..\Rumbleverse\Binaries\Win64\Config.ini"
start /b "" "..\Rumbleverse\Binaries\Win64\Config.ini"
