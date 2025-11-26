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
python -m pip install -qq --disable-pip-version-check -r requirements.txt
if errorlevel 1 (
    echo Error: Failed to install dependencies
    pause
    exit /b 1
)
python -m pip install -qq --disable-pip-version-check pyinstaller
if errorlevel 1 (
    echo Error: Failed to install PyInstaller
    pause
    exit /b 1
)

echo.
echo Building executable...
python -m PyInstaller --onefile --windowed --name "Barcode Scanner" barcode_scanner.py
if errorlevel 1 (
    echo Error: Build failed
    pause
    exit /b 1
)

echo.
echo Done! Starting Barcode Scanner...
echo.
pause

