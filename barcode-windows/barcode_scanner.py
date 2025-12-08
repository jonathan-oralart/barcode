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
    import os
    import json
    from pystray import Icon, Menu, MenuItem
    from PIL import Image, ImageDraw, ImageFont
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

# ============================================================================
# Settings Persistence
# ============================================================================

def get_config_path():
    """Get the path to the config file in AppData."""
    appdata = os.environ.get('APPDATA', os.path.expanduser('~'))
    config_dir = os.path.join(appdata, 'BarcodeScanner')
    os.makedirs(config_dir, exist_ok=True)
    return os.path.join(config_dir, 'settings.json')

def load_settings():
    """Load settings from disk. Returns defaults if file doesn't exist."""
    try:
        with open(get_config_path(), 'r') as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {'enabled': False}  # Default to keyboard mode

def save_settings(settings):
    """Save settings to disk."""
    try:
        with open(get_config_path(), 'w') as f:
            json.dump(settings, f)
    except Exception as e:
        print(f"⚠️ Could not save settings: {e}")

def create_icon_image(connected, enabled=True):
    """Create an emoji-based system tray icon."""
    size = 64
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Pick emoji based on state (single character emojis work better)
    if not connected:
        emoji = "⏸"  # Paused/disconnected
    elif enabled:
        emoji = "🔗"  # Link mode (opens URLs)
    else:
        emoji = "⌨"  # Keyboard mode
    
    # Try to load Segoe UI Emoji font (Windows emoji font)
    try:
        font = ImageFont.truetype("seguiemj.ttf", 56)
    except:
        try:
            font = ImageFont.truetype("C:\\Windows\\Fonts\\seguiemj.ttf", 56)
        except:
            font = ImageFont.load_default()
    
    # Draw centered using anchor
    draw.text((size // 2, size // 2), emoji, font=font, anchor="mm", embedded_color=True)
    
    return img

# HID scancode to character (US keyboard layout)
HID_CHARS = {
    0x28: '\n',  # Enter
    0x2C: ' ',   # Space
    0x2D: '-',   # - _
    0x2E: '=',   # = +
    0x2F: '[',   # [ {
    0x30: ']',   # ] }
    0x31: '\\',  # \ |
    0x33: ';',   # ; :
    0x34: "'",   # ' "
    0x35: '`',   # ` ~
    0x36: ',',   # , <
    0x37: '.',   # . >
    0x38: '/',   # / ?
}
HID_SHIFT_CHARS = {
    0x1E: '!', 0x1F: '@', 0x20: '#', 0x21: '$', 0x22: '%',
    0x23: '^', 0x24: '&', 0x25: '*', 0x26: '(', 0x27: ')',
    0x2D: '_', 0x2E: '+', 0x2F: '{', 0x30: '}', 0x31: '|',
    0x33: ':', 0x34: '"', 0x35: '~', 0x36: '<', 0x37: '>', 0x38: '?',
}

def hid_to_char(code, shift=False):
    # Letters a-z / A-Z
    if 0x04 <= code <= 0x1D:
        c = chr(code - 0x04 + ord('a'))
        return c.upper() if shift else c
    # Numbers 1-9, 0
    if 0x1E <= code <= 0x27:
        if shift:
            return HID_SHIFT_CHARS.get(code)
        return str(code - 0x1D) if code <= 0x26 else '0'
    # Symbols and special keys
    if shift and code in HID_SHIFT_CHARS:
        return HID_SHIFT_CHARS[code]
    return HID_CHARS.get(code)

# ============================================================================
# Window Detection
# ============================================================================

def get_foreground_window_title():
    """Get the title of the currently active foreground window."""
    hwnd = ctypes.windll.user32.GetForegroundWindow()
    if not hwnd:
        return ""
    
    # Get the length of the window title
    length = ctypes.windll.user32.GetWindowTextLengthW(hwnd)
    if length == 0:
        return ""
    
    # Create a buffer and get the title
    buffer = ctypes.create_unicode_buffer(length + 1)
    ctypes.windll.user32.GetWindowTextW(hwnd, buffer, length + 1)
    return buffer.value

# ============================================================================
# Keyboard Simulation (for passthrough mode)
# ============================================================================

VK_SHIFT = 0x10
VK_RETURN = 0x0D

def send_string(text):
    """Send alphanumeric string + Enter as keyboard input."""
    for char in text:
        # VkKeyScanW: low byte = VK code, high byte bit 0 = shift needed
        result = ctypes.windll.user32.VkKeyScanW(ord(char))
        vk = result & 0xFF
        need_shift = (result >> 8) & 1  # Check if shift is required
        
        if need_shift:
            ctypes.windll.user32.keybd_event(VK_SHIFT, 0, 0, 0)
        ctypes.windll.user32.keybd_event(vk, 0, 0, 0)
        ctypes.windll.user32.keybd_event(vk, 0, 2, 0)
        if need_shift:
            ctypes.windll.user32.keybd_event(VK_SHIFT, 0, 2, 0)
    # Send Enter
    ctypes.windll.user32.keybd_event(VK_RETURN, 0, 0, 0)
    ctypes.windll.user32.keybd_event(VK_RETURN, 0, 2, 0)

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
        self.prev_keys = set()  # Track keys from previous report for debouncing
    
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
        
        # Byte 0 is modifier: bit 1 = Left Shift, bit 5 = Right Shift
        shift = bool(data[0] & 0x22)
        
        # Get current keys from this report (non-zero key codes)
        current_keys = set(data[i] for i in range(2, min(8, len(data))) if data[i] != 0)
        
        # Only process newly pressed keys (not in previous report) - this debounces held keys
        new_keys = current_keys - self.prev_keys
        self.prev_keys = current_keys
        
        for key in sorted(new_keys):  # Sort for consistent ordering
            char = hid_to_char(key, shift)
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
    print(f"🔗 Opened: {barcode}")

def passthrough_barcode(barcode):
    """Send barcode as keyboard input to the active window."""
    send_string(barcode)
    print(f"⌨️ Typed: {barcode}")

def show_help(icon=None, item=None):
    def _show():
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
    threading.Thread(target=_show, daemon=True).start()

class App:
    def __init__(self):
        self.stop_event = threading.Event()
        self.icon = None
        settings = load_settings()
        self.enabled = settings.get('enabled', False)  # True = open URLs, False = keyboard passthrough
        self.connected = False
    
    def set_mode(self, enabled):
        """Set the mode and persist to disk."""
        if self.enabled != enabled:
            self.enabled = enabled
            save_settings({'enabled': enabled})
            mode = "URL mode" if enabled else "Keyboard mode"
            print(f"🔄 Switched to {mode}")
            if self.icon:
                self.icon.icon = create_icon_image(self.connected, self.enabled)
                self.icon.update_menu()
        
    def handle_barcode(self, barcode):
        """Route barcode based on enabled state, or handle command barcodes."""
        # Check for command barcodes
        if barcode == "[COMMAND] Keyboard":
            self.set_mode(False)
            return
        elif barcode == "[COMMAND] Link":
            self.set_mode(True)
            return
        
        # Check foreground window for auto-mode switching
        window_title = get_foreground_window_title()
        if window_title == "ScanPark - Google Chrome" or window_title == "Page 1 | Create Courier Ticket - Google Chrome":
            self.set_mode(False)
        elif window_title == "Case Search Results - Google Chrome" or window_title == "Case Flow - Google Chrome":
            self.set_mode(True)
        # Normal barcode processing
        if self.enabled:
            open_url(barcode)
        else:
            passthrough_barcode(barcode)
        
    def update_status(self, connected):
        self.connected = connected
        if self.icon:
            self.icon.icon = create_icon_image(connected, self.enabled)
            # Force icon refresh on Windows
            self.icon.visible = True
    
    def toggle_enabled(self, icon, item):
        self.set_mode(not self.enabled)
            
    def quit(self, icon, item):
        self.stop_event.set()
        icon.stop()
    
    def run(self):
        self.icon = Icon(
            "Barcode Scanner",
            create_icon_image(False, self.enabled),
            menu=Menu(
                MenuItem("Barcode Scanner", lambda: None, enabled=False),
                Menu.SEPARATOR,
                MenuItem(
                    lambda text: "Mode: Open URLs" if self.enabled else "Mode: Keyboard Input",
                    self.toggle_enabled,
                    default=True  # Left-click toggles mode
                ),
                Menu.SEPARATOR,
                MenuItem("Help", show_help),
                MenuItem("Quit", self.quit)
            )
        )
        
        def on_ready(icon):
            """Called when the icon is ready - start the scanner thread."""
            print("✅ Barcode Scanner started - check system tray")
            mode = "URL mode" if self.enabled else "Keyboard mode"
            print(f"📋 Mode: {mode} (click tray icon to toggle)")
            scanner = USBBarcodeScanner(self.handle_barcode, self.update_status)
            threading.Thread(target=scanner.read_loop, args=(self.stop_event,), daemon=True).start()
        
        self.icon.run(setup=on_ready)

def main():
    ensure_single_instance()
    App().run()

if __name__ == "__main__":
    main()
