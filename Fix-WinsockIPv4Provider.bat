@echo off
setlocal

set "SCRIPT=%~dp0Fix-WinsockIPv4Provider.ps1"

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator rights...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath powershell.exe -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -NoExit -File ""%SCRIPT%""'"
    exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -NoExit -File "%SCRIPT%"
