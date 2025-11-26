# Barcode Scanner for Windows

A Windows system tray application that monitors a USB barcode scanner and opens scanned barcodes in your web browser.

## Features

- Runs in the system tray
- Monitors Symbol Bar Code Scanner (Vendor ID: 0x05E0, Product ID: 0x1200)
- Automatically opens scanned barcodes in your default browser
- **Exclusive access** - Scanner input does NOT go to other applications

## Requirements

- Windows 10/11
- Python 3.8+ (for development)
- USB barcode scanner
- **WinUSB driver** (installed via Zadig - see setup below)

## ⚠️ IMPORTANT: First-Time Setup (WinUSB Driver)

Before the application can work, you must replace the scanner's default driver with WinUSB. This is a **one-time setup**.

### Step 1: Download Zadig

Download Zadig from: https://zadig.akeo.ie/

### Step 2: Install WinUSB Driver

1. **Plug in your barcode scanner**
2. **Run Zadig as Administrator**
3. Go to **Options → List All Devices**
4. Select **"Symbol Bar Code Scanner"** from the dropdown
5. Make sure the target driver shows **WinUSB**
6. Click **"Replace Driver"**
7. Wait for installation to complete

![Zadig Screenshot](https://zadig.akeo.ie/images/zadig_hid.png)

### Step 3: Verify

After installation:
- The scanner will **no longer work as a keyboard** (this is expected!)
- The scanner will **only work with this application**
- Run the Barcode Scanner app - it should now connect successfully

### Reverting the Driver (Optional)

If you need to restore the original keyboard functionality:
1. Open **Device Manager**
2. Find the scanner under "Universal Serial Bus devices"
3. Right-click → **Uninstall device** (check "Delete driver software")
4. Unplug and replug the scanner
5. Windows will reinstall the default HID driver

## Installation

### Option 1: Automatic Setup (Recommended for New Computers)

Run the setup script to automatically install everything:

1. Download `setup.bat` from this repository
2. Double-click `setup.bat` to run it
3. Follow the prompts

The script will:
- Install Git (if not present)
- Install Python 3 (if not present)
- Clone this repository to your user folder
- Install all Python dependencies
- Create a desktop shortcut

### Option 2: Use Pre-built Executable

Download `Barcode Scanner.exe` from the `dist` folder and run it.

### Option 3: Run from Source

1. Install Python from https://python.org

2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

3. Run the application:
   ```bash
   python barcode_scanner.py
   ```

## Building an Executable

To create a standalone `.exe` file:

```bash
build.bat
```

Or manually:
```bash
pip install pyinstaller
pyinstaller --onefile --windowed --name "Barcode Scanner" barcode_scanner.py
```

The executable will be in the `dist` folder.

## Configuration

To change the scanner device, edit these values in `barcode_scanner.py`:

```python
VENDOR_ID = 0x05E0   # Your scanner's vendor ID
PRODUCT_ID = 0x1200  # Your scanner's product ID
```

To find your scanner's IDs, run the app and click "List USB Devices" in the tray menu.

To change the URL that opens, edit:

```python
URL_TEMPLATE = "https://your-url.com?barcode={barcode}"
```

## Usage

1. Complete the WinUSB driver setup (above)
2. Start the application
3. Look for the barcode icon in your system tray (green = connected)
4. Scan a barcode with your scanner
5. The URL will open in your default browser

## Troubleshooting

### "Cannot access scanner - WinUSB driver may not be installed"
- You need to install the WinUSB driver using Zadig (see setup above)

### Scanner not detected
- Make sure the scanner is plugged in
- Check the Vendor ID and Product ID match your scanner
- Make sure you've installed the WinUSB driver

### Scanner detected but no data received
- Check the log window (Show/Hide Log in tray menu)
- Try unplugging and replugging the scanner

### Need to find your scanner's IDs
- Run the app and click "List USB Devices" in the tray menu
- Look for your scanner in the list

### Want to use scanner as keyboard again
- Uninstall the WinUSB driver via Device Manager
- Unplug and replug the scanner
