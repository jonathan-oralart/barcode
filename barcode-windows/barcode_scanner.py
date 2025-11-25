# barcode_scanner.py
# Windows USB Barcode Scanner - System Tray App
# Monitors Symbol Bar Code Scanner and opens URLs in browser

import hid
import webbrowser
import time
from pystray import Icon, Menu, MenuItem
from PIL import Image, ImageDraw
import threading

# Symbol Bar Code Scanner IDs
VENDOR_ID = 0x05E0   # 1504
PRODUCT_ID = 0x1200  # 4608

# Target URL template
URL_TEMPLATE = "https://lms.3shape.com/pages/admin/case_list.asp?page=case_search_result&cmd=search_result&searchbox_text={barcode}"


def hid_to_char(usage):
    """Convert HID usage code to character."""
    if 0x04 <= usage <= 0x1D:  # a-z
        return chr(usage - 0x04 + ord('a'))
    elif 0x1E <= usage <= 0x26:  # 1-9
        return str(usage - 0x1D)
    elif usage == 0x27:  # 0
        return '0'
    elif usage == 0x28:  # Enter
        return '\n'
    elif usage == 0x2C:  # Space
        return ' '
    elif usage == 0x2D:  # -
        return '-'
    elif usage == 0x2E:  # =
        return '='
    elif usage == 0x36:  # ,
        return ','
    elif usage == 0x37:  # .
        return '.'
    return None


def open_url(barcode):
    """Open the URL with the scanned barcode."""
    url = URL_TEMPLATE.format(barcode=barcode)
    webbrowser.open(url)
    print(f"✅ Opened: {barcode}")


def list_hid_devices():
    """List all connected HID devices."""
    print("\n=== Connected USB HID Devices ===\n")
    for device in hid.enumerate():
        print(f"Device: {device.get('product_string', 'Unknown')}")
        print(f"Manufacturer: {device.get('manufacturer_string', 'Unknown')}")
        print(f"Vendor ID: 0x{device['vendor_id']:04X} ({device['vendor_id']})")
        print(f"Product ID: 0x{device['product_id']:04X} ({device['product_id']})")
        print("---")


def scanner_loop(stop_event, status_callback):
    """Main loop to monitor the barcode scanner."""
    while not stop_event.is_set():
        try:
            device = hid.device()
            device.open(VENDOR_ID, PRODUCT_ID)
            device.set_nonblocking(True)
            print("✅ Scanner connected")
            status_callback(True)
            
            buffer = ""
            last_key_time = time.time()
            
            while not stop_event.is_set():
                data = device.read(64)
                if data:
                    current_time = time.time()
                    
                    # Reset buffer if too much time has passed (100ms timeout)
                    if current_time - last_key_time > 0.1:
                        if buffer:
                            print(f"⏱️ Timeout - resetting buffer: {buffer}")
                        buffer = ""
                    
                    last_key_time = current_time
                    
                    # HID keyboard reports: [modifier, reserved, key1, key2, ...]
                    for key in data[2:8]:
                        if key == 0:
                            continue
                        char = hid_to_char(key)
                        if char == '\n':
                            if buffer:
                                print(f"📊 Barcode scanned: {buffer}")
                                open_url(buffer)
                                buffer = ""
                        elif char:
                            buffer += char
                            print(f"📝 Buffer: {buffer}")
                            
                time.sleep(0.01)
                
        except OSError as e:
            print(f"Scanner disconnected or not found: {e}")
            status_callback(False)
            time.sleep(2)
        except Exception as e:
            print(f"Error: {e}")
            status_callback(False)
            time.sleep(2)


def create_icon(connected=True):
    """Create system tray icon."""
    img = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Draw barcode-like icon
    color = (0, 128, 0) if connected else (128, 128, 128)
    draw.rectangle([8, 16, 56, 48], outline=color, width=2)
    draw.line([16, 22, 16, 42], fill=color, width=2)
    draw.line([24, 22, 24, 42], fill=color, width=4)
    draw.line([32, 22, 32, 42], fill=color, width=2)
    draw.line([40, 22, 40, 42], fill=color, width=3)
    draw.line([48, 22, 48, 42], fill=color, width=2)
    
    return img


class BarcodeScannerApp:
    def __init__(self):
        self.stop_event = threading.Event()
        self.connected = False
        self.icon = None
        
    def update_status(self, connected):
        """Update connection status and icon."""
        self.connected = connected
        if self.icon:
            self.icon.icon = create_icon(connected)
            
    def quit_app(self, icon, item):
        """Clean shutdown."""
        print("Shutting down...")
        self.stop_event.set()
        icon.stop()
        
    def show_devices(self, icon, item):
        """List connected HID devices."""
        list_hid_devices()
        
    def run(self):
        """Start the application."""
        # Start scanner thread
        scanner_thread = threading.Thread(
            target=scanner_loop,
            args=(self.stop_event, self.update_status),
            daemon=True
        )
        scanner_thread.start()
        
        # Create and run system tray icon
        self.icon = Icon(
            "Barcode Scanner",
            create_icon(False),
            menu=Menu(
                MenuItem("USB Barcode Scanner", lambda: None, enabled=False),
                MenuItem("List USB Devices", self.show_devices),
                Menu.SEPARATOR,
                MenuItem("Quit", self.quit_app)
            )
        )
        
        print("🔎 Barcode Scanner started - check system tray")
        self.icon.run()


def main():
    app = BarcodeScannerApp()
    app.run()


if __name__ == "__main__":
    main()

