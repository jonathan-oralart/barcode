# Barcode Scanner for Windows

A Windows system tray application that monitors a USB barcode scanner and opens scanned barcodes in your web browser.

## Features

- Runs in the system tray
- Monitors Symbol Bar Code Scanner (Vendor ID: 0x05E0, Product ID: 0x1200)
- Automatically opens scanned barcodes in your default browser
- Blocks scanner input from reaching other applications (via exclusive HID access)

## Requirements

- Windows 10/11
- Python 3.8+
- The USB barcode scanner must be connected

## Installation

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

To create a standalone `.exe` file that doesn't require Python:

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

1. Start the application
2. Look for the barcode icon in your system tray
3. Scan a barcode with your scanner
4. The URL will open in your default browser

## Troubleshooting

### Scanner not detected
- Make sure the scanner is plugged in
- Check the Vendor ID and Product ID match your scanner
- Try running as Administrator

### Need to find your scanner's IDs
- Run the app and click "List USB Devices" in the tray menu
- Look for your scanner in the list

