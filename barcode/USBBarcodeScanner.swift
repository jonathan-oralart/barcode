import Foundation
import IOKit.hid
import AppKit
import ApplicationServices

class USBBarcodeScanner {
    private var hidManager: IOHIDManager?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var barcodeBuffer = ""
    private var lastKeystrokeTime = Date()
    private let keystrokeTimeout: TimeInterval = 0.1
    
    // Track if we're currently receiving scanner input
    private var isReceivingScannerInput = false
    private var scannerInputStartTime = Date()
    
    // Symbol Bar Code Scanner (Symbol Technologies, Inc, 2008)
    private let targetVendorID: Int? = 0x05E0  // 1504
    private let targetProductID: Int? = 0x1200 // 4608
    
    // Static reference for the event tap callback
    private static var sharedInstance: USBBarcodeScanner?
    
    func start() {
        USBBarcodeScanner.sharedInstance = self
        
        // Check and request Accessibility permission (needed for event tap)
        if !checkAccessibilityPermission() {
            print("⚠️ Accessibility permission not granted")
            requestAccessibilityPermission()
            return
        }
        
        // Start HID monitoring (non-exclusive, just to detect scanner input)
        startHIDMonitoring()
        
        // Start event tap to block scanner keystrokes from other apps
        startEventTap()
    }
    
    private func startHIDMonitoring() {
        hidManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        
        guard let manager = hidManager else {
            print("Failed to create HID manager")
            return
        }
        
        // Set up device matching
        var deviceMatch: [String: Any] = [:]
        
        if let vendorID = targetVendorID, let productID = targetProductID {
            deviceMatch = [
                kIOHIDVendorIDKey: vendorID,
                kIOHIDProductIDKey: productID
            ]
            print("Monitoring specific device - Vendor: 0x\(String(format: "%04X", vendorID)), Product: 0x\(String(format: "%04X", productID))")
        } else {
            deviceMatch = [
                kIOHIDDeviceUsagePageKey: 0x01,
                kIOHIDDeviceUsageKey: 0x06
            ]
            print("⚠️ No specific device set - monitoring all keyboards")
        }
        
        IOHIDManagerSetDeviceMatching(manager, deviceMatch as CFDictionary)
        
        // Register input value callback
        IOHIDManagerRegisterInputValueCallback(manager, { context, result, sender, value in
            let scanner = Unmanaged<USBBarcodeScanner>.fromOpaque(context!).takeUnretainedValue()
            scanner.handleInputValue(value)
        }, Unmanaged.passUnretained(self).toOpaque())
        
        // Open non-exclusively (this always works)
        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if openResult == kIOReturnSuccess {
            IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
            print("✅ Started HID monitoring")
        } else {
            print("❌ Failed to open HID manager: \(String(format: "0x%08X", openResult))")
        }
    }
    
    private func startEventTap() {
        // Create event tap to intercept keyboard events
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let scanner = USBBarcodeScanner.sharedInstance else {
                    return Unmanaged.passRetained(event)
                }
                
                // Check if we should block this event
                if scanner.shouldBlockEvent() {
                    // Block the event by returning nil
                    return nil
                }
                
                return Unmanaged.passRetained(event)
            },
            userInfo: nil
        )
        
        guard let tap = eventTap else {
            print("❌ Failed to create event tap - need Accessibility permission")
            return
        }
        
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        
        print("✅ Started event tap (blocking scanner input from other apps)")
    }
    
    private func shouldBlockEvent() -> Bool {
        // Block events while we're receiving scanner input
        // Scanner input is characterized by very rapid keystrokes
        return isReceivingScannerInput
    }
    
    private func handleInputValue(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let usagePage = IOHIDElementGetUsagePage(element)
        
        guard usagePage == 0x07 else { return }
        
        let usage = IOHIDElementGetUsage(element)
        let pressed = IOHIDValueGetIntegerValue(value)
        
        guard pressed != 0 else { return }
        
        let currentTime = Date()
        
        // Reset buffer if too much time has passed
        if currentTime.timeIntervalSince(lastKeystrokeTime) > keystrokeTimeout {
            if !barcodeBuffer.isEmpty {
                print("⏱️ Timeout - resetting buffer: \(barcodeBuffer)")
            }
            barcodeBuffer = ""
            isReceivingScannerInput = false
        }
        
        // Mark that we're receiving scanner input
        isReceivingScannerInput = true
        lastKeystrokeTime = currentTime
        
        // Convert HID usage to character
        if let character = convertHIDUsageToCharacter(Int(usage)) {
            if character == "\n" {
                if !barcodeBuffer.isEmpty {
                    print("📊 Barcode scanned: \(barcodeBuffer)")
                    launchChromeWithBarcode(barcodeBuffer)
                    barcodeBuffer = ""
                }
                // Stop blocking after Enter is pressed
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.isReceivingScannerInput = false
                }
            } else {
                barcodeBuffer += character
                print("📝 Buffer: \(barcodeBuffer)")
            }
        }
    }
    
    private func convertHIDUsageToCharacter(_ usage: Int) -> String? {
        switch usage {
        case 0x04...0x1D: // a-z
            return String(UnicodeScalar(usage - 0x04 + 0x61)!)
        case 0x1E...0x26: // 1-9
            return String(usage - 0x1D)
        case 0x27: // 0
            return "0"
        case 0x28: // Enter
            return "\n"
        case 0x2C: // Space
            return " "
        case 0x2D: // - (minus/hyphen)
            return "-"
        case 0x2E: // = (equals)
            return "="
        case 0x36: // , (comma)
            return ","
        case 0x37: // . (period)
            return "."
        default:
            return nil
        }
    }
    
    private func launchChromeWithBarcode(_ barcode: String) {
        let urlString = "https://lms.3shape.com/pages/admin/case_list.asp?page=case_search_result&cmd=search_result&searchbox_text=\(barcode)"
        
        guard let encodedURL = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encodedURL) else {
            print("❌ Invalid URL")
            return
        }
        
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        
        if let chromeURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.google.Chrome") {
            NSWorkspace.shared.open([url], withApplicationAt: chromeURL, configuration: configuration)
            print("✅ Opened in Chrome: \(urlString)")
        } else {
            NSWorkspace.shared.open(url)
            print("✅ Opened in default browser: \(urlString)")
        }
    }
    
    func stop() {
        // Stop event tap
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        
        // Stop HID monitoring
        if let manager = hidManager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        hidManager = nil
        
        USBBarcodeScanner.sharedInstance = nil
        print("Stopped monitoring")
    }
    
    private func checkAccessibilityPermission() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let hasPermission = AXIsProcessTrustedWithOptions(options)
        
        if hasPermission {
            print("✅ Accessibility permission granted")
        } else {
            print("❌ Accessibility permission not granted")
        }
        
        return hasPermission
    }
    
    private func requestAccessibilityPermission() {
        print("📋 Requesting Accessibility permission...")
        
        // Prompt for permission
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options)
        
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = "This app needs Accessibility permission to block barcode scanner input from appearing in other applications.\n\nPlease:\n1. Open System Settings\n2. Go to Privacy & Security > Accessibility\n3. Enable this app\n4. Restart the app"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "OK")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}
