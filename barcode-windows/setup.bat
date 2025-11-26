@echo off
:: Barcode Scanner Setup Script
:: This script launches the PowerShell setup script

echo.
echo  ========================================
echo   Barcode Scanner - Windows Setup
echo  ========================================
echo.
echo  This will install Git, Python, and the
echo  Barcode Scanner application.
echo.

:: Run the PowerShell setup script
powershell -ExecutionPolicy Bypass -File "%~dp0setup.ps1"

pause

