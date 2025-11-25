# barcode_scanner.py
# Windows USB Barcode Scanner - System Tray App
# Uses PyUSB for exclusive access (requires WinUSB driver via Zadig)

import sys
import ctypes

# ============================================================================
# Single Instance Check
# ============================================================================

def ensure_single_instance():
    """Exit if another instance is already running."""
    mutex = ctypes.windll.kernel32.CreateMutexW(None, False, "Global\\BarcodeScannerMutex")
    if ctypes.windll.kernel32.GetLastError() == 183:
        ctypes.windll.user32.MessageBoxW(0, "Barcode Scanner is already running.\nCheck your system tray.", "Already Running", 0x40)
        sys.exit(0)

# ============================================================================
# Imports
# ============================================================================

try:
    import libusb_package
    import usb.core
    import usb.util
    import usb.backend.libusb1
    import webbrowser
    import time
    from pystray import Icon, Menu, MenuItem
    from PIL import Image
    import threading
    
    libusb_backend = usb.backend.libusb1.get_backend(find_library=libusb_package.find_library)
except ImportError as e:
    ctypes.windll.user32.MessageBoxW(0, f"Import error:\n\n{e}", "Error", 0x10)
    sys.exit(1)

# ============================================================================
# Configuration
# ============================================================================

VENDOR_ID = 0x05E0
PRODUCT_ID = 0x1200
URL_TEMPLATE = "https://lms.3shape.com/pages/admin/case_list.asp?page=case_search_result&cmd=search_result&searchbox_text={barcode}"

def create_icon_image(connected):
    """Create a simple barcode icon."""
    # Create a simple 16x16 icon programmatically
    img = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    pixels = img.load()
    
    color = (0, 180, 0, 255) if connected else (128, 128, 128, 255)
    
    # Draw simple barcode lines
    for y in range(2, 14):
        pixels[2, y] = color
        pixels[3, y] = color
        pixels[5, y] = color
        pixels[7, y] = color
        pixels[8, y] = color
        pixels[10, y] = color
        pixels[12, y] = color
        pixels[13, y] = color
    
    return img

# HID scancode to character (0-9, a-z, Enter only)
def hid_to_char(code):
    if 0x04 <= code <= 0x1D: return chr(code - 0x04 + ord('a'))  # a-z
    if 0x1E <= code <= 0x26: return str(code - 0x1D)              # 1-9
    if code == 0x27: return '0'
    if code == 0x28: return '\n'  # Enter
    return None

# ============================================================================
# USB Scanner
# ============================================================================

class USBBarcodeScanner:
    def __init__(self, barcode_callback, status_callback):
        self.barcode_callback = barcode_callback
        self.status_callback = status_callback
        self.device = None
        self.endpoint = None
        self.buffer = ""
    
    def connect(self):
        try:
            self.device = usb.core.find(idVendor=VENDOR_ID, idProduct=PRODUCT_ID, backend=libusb_backend)
            if self.device is None:
                return False
            
            try:
                self.device.set_configuration()
            except usb.core.USBError:
                pass
            
            cfg = self.device.get_active_configuration()
            intf = cfg[(0, 0)]
            self.endpoint = usb.util.find_descriptor(
                intf, custom_match=lambda e: usb.util.endpoint_direction(e.bEndpointAddress) == usb.util.ENDPOINT_IN
            )
            
            if self.endpoint is None:
                return False
            
            print("✅ Scanner connected")
            return True
            
        except usb.core.USBError as e:
            print(f"❌ USB Error: {e}")
            return False
    
    def disconnect(self):
        if self.device:
            try:
                usb.util.dispose_resources(self.device)
            except:
                pass
            self.device = None
            self.endpoint = None
    
    def read_loop(self, stop_event):
        while not stop_event.is_set():
            try:
                if self.device is None:
                    if not self.connect():
                        self.status_callback(False)
                        time.sleep(2)
                        continue
                    self.status_callback(True)
                
                try:
                    data = self.endpoint.read(self.endpoint.wMaxPacketSize, timeout=100)
                    self._process_data(data)
                except usb.core.USBError as e:
                    if e.errno == 10060:  # Windows timeout - normal when no data
                        continue
                    print(f"❌ Read error: {e}")
                    self.disconnect()
                    self.status_callback(False)
                    time.sleep(2)
                    
            except Exception as e:
                print(f"❌ Error: {e}")
                self.disconnect()
                self.status_callback(False)
                time.sleep(2)
        
        self.disconnect()
    
    def _process_data(self, data):
        if len(data) < 3:
            return
        
        for i in range(2, min(8, len(data))):
            key = data[i]
            if key == 0:
                continue
            
            char = hid_to_char(key)
            if char == '\n':
                if self.buffer:
                    print(f"📊 Scanned: {self.buffer}")
                    self.barcode_callback(self.buffer)
                    self.buffer = ""
            elif char:
                self.buffer += char

# ============================================================================
# Main Application
# ============================================================================

def open_url(barcode):
    url = URL_TEMPLATE.format(barcode=barcode)
    webbrowser.open(url)
    print(f"✅ Opened: {barcode}")

def show_help():
    ctypes.windll.user32.MessageBoxW(
        0,
        "Setup Instructions:\n\n"
        "1. Download Zadig: https://zadig.akeo.ie/\n"
        "2. Run as Administrator\n"
        "3. Options → List All Devices\n"
        "4. Select your scanner\n"
        "5. Select WinUSB driver\n"
        "6. Click Replace Driver",
        "Driver Setup", 0x40
    )

class App:
    def __init__(self):
        self.stop_event = threading.Event()
        self.icon = None
        
    def update_status(self, connected):
        if self.icon:
            self.icon.icon = create_icon_image(connected)
            
    def quit(self, icon, item):
        self.stop_event.set()
        icon.stop()
    
    def run(self):
        scanner = USBBarcodeScanner(open_url, self.update_status)
        threading.Thread(target=scanner.read_loop, args=(self.stop_event,), daemon=True).start()
        
        self.icon = Icon(
            "Barcode Scanner",
            create_icon_image(False),
            menu=Menu(
                MenuItem("Barcode Scanner", lambda: None, enabled=False),
                MenuItem("Help", lambda: show_help()),
                Menu.SEPARATOR,
                MenuItem("Quit", self.quit)
            )
        )
        
        print("✅ Barcode Scanner started - check system tray")
        self.icon.run()

def main():
    ensure_single_instance()
    App().run()

if __name__ == "__main__":
    main()
