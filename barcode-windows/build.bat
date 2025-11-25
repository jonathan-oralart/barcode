@echo off
echo Building Barcode Scanner executable...
echo.

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo Error: Python is not installed or not in PATH
    echo Please install Python from https://python.org
    pause
    exit /b 1
)

REM Install dependencies
echo Installing dependencies...
pip install -r requirements.txt
pip install pyinstaller

echo.
echo Building executable...
pyinstaller --onefile --windowed --name "Barcode Scanner" barcode_scanner.py

echo.
echo Done! Executable is in the 'dist' folder.
echo.
pause

