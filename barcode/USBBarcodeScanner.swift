import Foundation
import IOKit.hid
import AppKit

class USBBarcodeScanner {
    private var hidManager: IOHIDManager?
    private var barcodeBuffer = ""
    private var lastKeystrokeTime = Date()
    private let keystrokeTimeout: TimeInterval = 0.1
    
    // Symbol Bar Code Scanner (Symbol Technologies, Inc, 2008)
    private let targetVendorID: Int? = 0x05E0  // 1504
    private let targetProductID: Int? = 0x1200 // 4608
    
    func start() {
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
            // Monitor all keyboard devices if no specific device set
            deviceMatch = [
                kIOHIDDeviceUsagePageKey: 0x01, // Generic Desktop
                kIOHIDDeviceUsageKey: 0x06      // Keyboard
            ]
            print("⚠️ No specific device set - monitoring all keyboards")
            print("Run 'List USB Devices' from menu bar to find your scanner's IDs")
        }
        
        IOHIDManagerSetDeviceMatching(manager, deviceMatch as CFDictionary)
        
        // Register input value callback
        IOHIDManagerRegisterInputValueCallback(manager, { context, result, sender, value in
            let scanner = Unmanaged<USBBarcodeScanner>.fromOpaque(context!).takeUnretainedValue()
            scanner.handleInputValue(value)
        }, Unmanaged.passUnretained(self).toOpaque())
        
        // Open the manager
        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if openResult == kIOReturnSuccess {
            IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
            print("✅ Started monitoring USB barcode scanner")
        } else {
            print("❌ Failed to open HID manager")
        }
    }
    
    private func handleInputValue(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let usagePage = IOHIDElementGetUsagePage(element)
        
        // Check if this is a keyboard event (usage page 7)
        guard usagePage == 0x07 else { return }
        
        let usage = IOHIDElementGetUsage(element)
        let pressed = IOHIDValueGetIntegerValue(value)
        
        // Only process key down events
        guard pressed != 0 else { return }
        
        let currentTime = Date()
        
        // Reset buffer if too much time has passed
        if currentTime.timeIntervalSince(lastKeystrokeTime) > keystrokeTimeout {
            if !barcodeBuffer.isEmpty {
                print("⏱️ Timeout - resetting buffer: \(barcodeBuffer)")
            }
            barcodeBuffer = ""
        }
        
        lastKeystrokeTime = currentTime
        
        // Convert HID usage to character
        if let character = convertHIDUsageToCharacter(Int(usage)) {
            if character == "\n" { // Enter key
                if !barcodeBuffer.isEmpty {
                    print("📊 Barcode scanned: \(barcodeBuffer)")
                    launchChromeWithBarcode(barcodeBuffer)
                    barcodeBuffer = ""
                }
            } else {
                barcodeBuffer += character
                print("📝 Buffer: \(barcodeBuffer)")
            }
        }
    }
    
    private func convertHIDUsageToCharacter(_ usage: Int) -> String? {
        // HID Usage codes for keyboard
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
        let urlString = "https://lms.3shape.com/ui/CaseRecord/\(barcode)"
        
        guard let encodedURL = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encodedURL) else {
            print("❌ Invalid URL")
            return
        }
        
        // Try to open in Chrome
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        
        if let chromeURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.google.Chrome") {
            NSWorkspace.shared.open([url], withApplicationAt: chromeURL, configuration: configuration)
            print("✅ Opened in Chrome: \(urlString)")
        } else {
            // Fallback to default browser
            NSWorkspace.shared.open(url)
            print("✅ Opened in default browser: \(urlString)")
        }
    }
    
    func stop() {
        if let manager = hidManager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            print("Stopped monitoring")
        }
    }
}
