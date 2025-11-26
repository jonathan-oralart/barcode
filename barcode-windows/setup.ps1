# Barcode Scanner Setup Script
# Run this script as Administrator on a new Windows computer

param(
    [string]$InstallPath = "$env:USERPROFILE\barcode"
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "`n=== $Message ===" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[!] $Message" -ForegroundColor Yellow
}

function Test-Command {
    param([string]$Command)
    $null = Get-Command $Command -ErrorAction SilentlyContinue
    return $?
}

function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

Write-Host @"

 ____                          _        ____                                  
| __ )  __ _ _ __ ___ ___   __| | ___  / ___|  ___ __ _ _ __  _ __   ___ _ __ 
|  _ \ / _` | '__/ __/ _ \ / _` |/ _ \ \___ \ / __/ _` | '_ \| '_ \ / _ \ '__|
| |_) | (_| | | | (_| (_) | (_| |  __/  ___) | (_| (_| | | | | | | |  __/ |   
|____/ \__,_|_|  \___\___/ \__,_|\___| |____/ \___\__,_|_| |_|_| |_|\___|_|   
                                                                              
                        Windows Setup Script
"@ -ForegroundColor Magenta

Write-Host "This script will install:"
Write-Host "  - Git"
Write-Host "  - Python 3"
Write-Host "  - Required Python packages"
Write-Host "  - Clone the barcode scanner repository"
Write-Host "`nInstall location: $InstallPath`n"

# Step 1: Check/Install Git
Write-Step "Checking Git"

if (Test-Command "git") {
    $gitVersion = git --version
    Write-Success "Git is already installed: $gitVersion"
} else {
    Write-Host "Git not found. Installing via winget..."
    
    if (Test-Command "winget") {
        winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
        Refresh-Path
        
        if (Test-Command "git") {
            Write-Success "Git installed successfully"
        } else {
            Write-Warning "Git installed but not in PATH. You may need to restart your terminal."
        }
    } else {
        Write-Host "winget not available. Please install Git manually from: https://git-scm.com/download/win" -ForegroundColor Red
        exit 1
    }
}

# Step 2: Check/Install Python
Write-Step "Checking Python"

$pythonCmd = $null
if (Test-Command "python") {
    $pythonVersion = python --version 2>&1
    if ($pythonVersion -match "Python 3") {
        $pythonCmd = "python"
        Write-Success "Python is already installed: $pythonVersion"
    }
}

if (-not $pythonCmd -and (Test-Command "python3")) {
    $pythonVersion = python3 --version 2>&1
    if ($pythonVersion -match "Python 3") {
        $pythonCmd = "python3"
        Write-Success "Python 3 is already installed: $pythonVersion"
    }
}

if (-not $pythonCmd) {
    Write-Host "Python 3 not found. Installing via winget..."
    
    if (Test-Command "winget") {
        winget install --id Python.Python.3.12 -e --source winget --accept-package-agreements --accept-source-agreements
        Refresh-Path
        
        # Try to find python after install
        if (Test-Command "python") {
            $pythonCmd = "python"
            Write-Success "Python installed successfully"
        } elseif (Test-Command "python3") {
            $pythonCmd = "python3"
            Write-Success "Python installed successfully"
        } else {
            Write-Warning "Python installed but not in PATH. You may need to restart your terminal."
            Write-Host "Try running this script again after restarting PowerShell."
            exit 1
        }
    } else {
        Write-Host "winget not available. Please install Python manually from: https://python.org" -ForegroundColor Red
        exit 1
    }
}

# Step 3: Clone Repository
Write-Step "Cloning Repository"

if (Test-Path $InstallPath) {
    Write-Host "Directory $InstallPath already exists."
    $overwrite = Read-Host "Do you want to remove it and re-clone? (y/n)"
    if ($overwrite -eq 'y') {
        Remove-Item -Recurse -Force $InstallPath
    } else {
        Write-Host "Skipping clone, using existing directory."
    }
}

if (-not (Test-Path $InstallPath)) {
    Write-Host "Cloning https://github.com/jonathan-oralart/barcode to $InstallPath..."
    git clone https://github.com/jonathan-oralart/barcode $InstallPath
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Repository cloned successfully"
    } else {
        Write-Host "Failed to clone repository" -ForegroundColor Red
        exit 1
    }
}

# Step 4: Install Python Dependencies
Write-Step "Installing Python Dependencies"

$requirementsPath = Join-Path $InstallPath "barcode-windows\requirements.txt"

if (Test-Path $requirementsPath) {
    Write-Host "Installing packages from requirements.txt..."
    & $pythonCmd -m pip install --upgrade pip
    & $pythonCmd -m pip install -r $requirementsPath
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Python dependencies installed successfully"
    } else {
        Write-Warning "Some dependencies may have failed to install"
    }
} else {
    Write-Warning "requirements.txt not found at $requirementsPath"
}

# Step 5: Create Desktop Shortcut
Write-Step "Creating Desktop Shortcut"

$desktopPath = [Environment]::GetFolderPath("Desktop")
$shortcutPath = Join-Path $desktopPath "Barcode Scanner.lnk"
$scriptPath = Join-Path $InstallPath "barcode-windows\barcode_scanner.py"

$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($shortcutPath)
$Shortcut.TargetPath = "pythonw"
$Shortcut.Arguments = "`"$scriptPath`""
$Shortcut.WorkingDirectory = Join-Path $InstallPath "barcode-windows"
$Shortcut.Save()

Write-Success "Desktop shortcut created"

# Summary
Write-Host "`n" + ("=" * 60) -ForegroundColor Green
Write-Host @"

  Setup Complete!

  Next Steps:
  -----------
  1. IMPORTANT: Install the WinUSB driver using Zadig
     Download from: https://zadig.akeo.ie/
     
     - Run Zadig as Administrator
     - Options -> List All Devices
     - Select "Symbol Bar Code Scanner"
     - Click "Replace Driver" (set to WinUSB)

  2. Run the Barcode Scanner:
     - Use the desktop shortcut, OR
     - Run: $pythonCmd "$scriptPath"

  3. The app will appear in your system tray

  Repository location: $InstallPath

"@ -ForegroundColor White
Write-Host ("=" * 60) -ForegroundColor Green

# Open Zadig download page
$openZadig = Read-Host "`nWould you like to open the Zadig download page now? (y/n)"
if ($openZadig -eq 'y') {
    Start-Process "https://zadig.akeo.ie/"
}

Write-Host "`nSetup script finished!" -ForegroundColor Cyan

