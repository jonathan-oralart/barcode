# barcode_scanner.py
# Windows USB Barcode Scanner - System Tray App
# Monitors Symbol Bar Code Scanner and opens URLs in browser

import sys
import os
import winreg
import ctypes
from ctypes import wintypes

# Check for VC++ Redistributable before importing other modules
def check_vcredist():
    """Check if Visual C++ Redistributable is installed."""
    try:
        # Try to check registry for VC++ 2015-2022 redistributable
        registry_paths = [
            r"SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64",
            r"SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x64",
        ]
        
        for path in registry_paths:
            try:
                key = winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, path)
                winreg.CloseKey(key)
                return True
            except WindowsError:
                continue
        
        # If registry check fails, return True to avoid false positives
        return True
    except Exception:
        return True

def show_vcredist_error():
    """Show error message if VC++ Redistributable is missing."""
    message = (
        "Microsoft Visual C++ Redistributable is required but may not be installed.\n\n"
        "Please download and install it from:\n"
        "https://aka.ms/vs/17/release/vc_redist.x64.exe\n\n"
        "After installation, restart this application."
    )
    ctypes.windll.user32.MessageBoxW(
        0, 
        message, 
        "Missing Dependency - Barcode Scanner", 
        0x10  # MB_ICONERROR
    )
    sys.exit(1)

# Check VC++ before importing dependencies that might need it
if not check_vcredist():
    show_vcredist_error()

try:
    import hid
    import webbrowser
    import time
    from pystray import Icon, Menu, MenuItem
    from PIL import Image, ImageDraw
    import threading
    import tkinter as tk
    from tkinter import scrolledtext
    from datetime import datetime
except ImportError as e:
    if "DLL load failed" in str(e) or "VCRUNTIME" in str(e):
        show_vcredist_error()
    else:
        ctypes.windll.user32.MessageBoxW(
            0,
            f"Failed to import required modules:\n\n{str(e)}\n\nPlease reinstall the application.",
            "Import Error - Barcode Scanner",
            0x10  # MB_ICONERROR
        )
        sys.exit(1)

# Symbol Bar Code Scanner IDs
VENDOR_ID = 0x05E0   # 1504
PRODUCT_ID = 0x1200  # 4608

# Target URL template
URL_TEMPLATE = "https://lms.3shape.com/pages/admin/case_list.asp?page=case_search_result&cmd=search_result&searchbox_text={barcode}"


class LogWindow:
    """Simple GUI window to display log output."""
    def __init__(self):
        self.window = None
        self.text_widget = None
        self.visible = False
        self.log_buffer = []
        
    def create_window(self):
        """Create the log window."""
        if self.window:
            return
            
        self.window = tk.Tk()
        self.window.title("Barcode Scanner - Log")
        self.window.geometry("800x600")
        
        # Create text widget with scrollbar
        self.text_widget = scrolledtext.ScrolledText(
            self.window,
            wrap=tk.WORD,
            font=("Consolas", 9),
            bg="#1e1e1e",
            fg="#d4d4d4",
            insertbackground="#d4d4d4"
        )
        self.text_widget.pack(fill=tk.BOTH, expand=True, padx=5, pady=5)
        
        # Configure tags for colored output
        self.text_widget.tag_config("error", foreground="#f48771")
        self.text_widget.tag_config("success", foreground="#7fcd91")
        self.text_widget.tag_config("info", foreground="#75beff")
        self.text_widget.tag_config("warning", foreground="#ffd700")
        
        # Handle window close
        self.window.protocol("WM_DELETE_WINDOW", self.hide)
        
        # Add any buffered logs
        for log_entry in self.log_buffer:
            self._append_to_widget(log_entry)
        self.log_buffer.clear()
        
        self.window.withdraw()  # Start hidden
        
    def _append_to_widget(self, message):
        """Append message to text widget with appropriate color."""
        timestamp = datetime.now().strftime("%H:%M:%S")
        full_message = f"[{timestamp}] {message}\n"
        
        # Determine color based on emoji/content
        tag = "info"
        if "✅" in message or "success" in message.lower():
            tag = "success"
        elif "❌" in message or "error" in message.lower():
            tag = "error"
        elif "⚠️" in message or "warning" in message.lower():
            tag = "warning"
        
        self.text_widget.insert(tk.END, full_message, tag)
        self.text_widget.see(tk.END)
        
    def log(self, message):
        """Add a log message."""
        if self.text_widget:
            self.text_widget.after(0, self._append_to_widget, message)
        else:
            # Buffer logs before window is created
            self.log_buffer.append(message)
    
    def show(self):
        """Show the log window."""
        if self.window:
            self.window.deiconify()
            self.window.lift()
            self.window.focus_force()
            self.visible = True
    
    def hide(self):
        """Hide the log window."""
        if self.window:
            self.window.withdraw()
            self.visible = False
    
    def toggle(self):
        """Toggle log window visibility."""
        if self.visible:
            self.hide()
        else:
            self.show()


# Global log window instance
log_window = None


def log_print(message):
    """Print to both console and GUI log."""
    print(message)
    if log_window:
        log_window.log(message)


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
    log_print(f"✅ Opened: {barcode}")


def list_hid_devices():
    """List all connected HID devices."""
    log_print("\n=== Connected USB HID Devices ===\n")
    for device in hid.enumerate():
        log_print(f"Device: {device.get('product_string', 'Unknown')}")
        log_print(f"Manufacturer: {device.get('manufacturer_string', 'Unknown')}")
        log_print(f"Vendor ID: 0x{device['vendor_id']:04X} ({device['vendor_id']})")
        log_print(f"Product ID: 0x{device['product_id']:04X} ({device['product_id']})")
        log_print("---")


def scanner_loop(stop_event, status_callback):
    """Main loop to monitor the barcode scanner."""
    while not stop_event.is_set():
        try:
            device = hid.device()
            device.open(VENDOR_ID, PRODUCT_ID)
            device.set_nonblocking(True)
            log_print("✅ Scanner connected")
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
                            log_print(f"⏱️ Timeout - resetting buffer: {buffer}")
                        buffer = ""
                    
                    last_key_time = current_time
                    
                    # HID keyboard reports: [modifier, reserved, key1, key2, ...]
                    for key in data[2:8]:
                        if key == 0:
                            continue
                        char = hid_to_char(key)
                        if char == '\n':
                            if buffer:
                                log_print(f"📊 Barcode scanned: {buffer}")
                                open_url(buffer)
                                buffer = ""
                        elif char:
                            buffer += char
                            log_print(f"📝 Buffer: {buffer}")
                            
                time.sleep(0.01)
                
        except OSError as e:
            log_print(f"❌ Scanner disconnected or not found: {e}")
            status_callback(False)
            time.sleep(2)
        except Exception as e:
            log_print(f"❌ Error: {e}")
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
        global log_window
        log_window = LogWindow()
        
    def update_status(self, connected):
        """Update connection status and icon."""
        self.connected = connected
        if self.icon:
            self.icon.icon = create_icon(connected)
            
    def quit_app(self, icon, item):
        """Clean shutdown."""
        log_print("🛑 Shutting down...")
        self.stop_event.set()
        icon.stop()
        if log_window and log_window.window:
            log_window.window.quit()
        
    def show_devices(self, icon, item):
        """List connected HID devices."""
        list_hid_devices()
    
    def toggle_log(self, icon, item):
        """Toggle log window visibility."""
        if log_window:
            log_window.toggle()
        
    def run(self):
        """Start the application."""
        # Create log window in main thread
        log_window.create_window()
        
        # Start scanner thread
        scanner_thread = threading.Thread(
            target=scanner_loop,
            args=(self.stop_event, self.update_status),
            daemon=True
        )
        scanner_thread.start()
        
        # Create system tray icon in a separate thread
        def run_icon():
            self.icon = Icon(
                "Barcode Scanner",
                create_icon(False),
                menu=Menu(
                    MenuItem("USB Barcode Scanner", lambda: None, enabled=False),
                    MenuItem("Show/Hide Log", self.toggle_log),
                    MenuItem("List USB Devices", self.show_devices),
                    Menu.SEPARATOR,
                    MenuItem("Quit", self.quit_app)
                )
            )
            self.icon.run()
        
        icon_thread = threading.Thread(target=run_icon, daemon=True)
        icon_thread.start()
        
        log_print("🔎 Barcode Scanner started - check system tray")
        log_print("💡 Click 'Show/Hide Log' in tray menu to view this window")
        
        # Run tkinter main loop
        log_window.window.mainloop()


def main():
    app = BarcodeScannerApp()
    app.run()


if __name__ == "__main__":
    main()

