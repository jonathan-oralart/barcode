import Cocoa
import IOKit.hid
import Sparkle

class AppDelegate: NSObject, NSApplicationDelegate {
    let scanner = USBBarcodeScanner()
    var statusItem: NSStatusItem?
    private let updaterController: SPUStandardUpdaterController
    
    override init() {
        // Initialize Sparkle updater
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        super.init()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create menu bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "🔎"
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "USB Barcode Scanner Active", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "List USB Devices", action: #selector(listDevices), keyEquivalent: "l"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "u"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem?.menu = menu
        
        scanner.start()
    }
    
    @objc func listDevices() {
        listUSBDevices()
    }
    
    @objc func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
    
    @objc func quit() {
        scanner.stop()
        NSApplication.shared.terminate(nil)
    }
}

// Helper function to list all USB HID devices
func listUSBDevices() {
    let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    IOHIDManagerSetDeviceMatching(manager, nil)
    IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    
    guard let deviceSet = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
        print("No devices found")
        return
    }
    
    print("\n=== Connected USB HID Devices ===\n")
    
    for device in deviceSet {
        if let vendorID = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? Int,
           let productID = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int {
            
            let product = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "Unknown"
            let manufacturer = IOHIDDeviceGetProperty(device, kIOHIDManufacturerKey as CFString) as? String ?? "Unknown"
            
            print("Device: \(product)")
            print("Manufacturer: \(manufacturer)")
            print("Vendor ID: 0x\(String(format: "%04X", vendorID)) (\(vendorID))")
            print("Product ID: 0x\(String(format: "%04X", productID)) (\(productID))")
            print("---")
        }
    }
    
    IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
}
