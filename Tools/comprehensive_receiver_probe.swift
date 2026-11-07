import Foundation
import IOKit
import IOKit.hid
import CoreGraphics

print("Starting Comprehensive Receiver & Event Probe (5 seconds)...")

// 1. IOHIDManager on 0x248a:0x5b4a
let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
let matchDict: [String: Any] = [
    kIOHIDVendorIDKey as String: 0x248a,
    kIOHIDProductIDKey as String: 0x5b4a
]
IOHIDManagerSetDeviceMatching(manager, matchDict as CFDictionary)

IOHIDManagerRegisterInputValueCallback(manager, { context, result, sender, value in
    let element = IOHIDValueGetElement(value)
    let page = IOHIDElementGetUsagePage(element)
    let usage = IOHIDElementGetUsage(element)
    let intVal = IOHIDValueGetIntegerValue(value)
    print("  [HID RAW] Page: 0x\(String(page, radix: 16)), Usage: 0x\(String(usage, radix: 16)), Value: \(intVal)")
}, nil)

IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
let openRes = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
print("IOHIDManager open result: \(openRes)")

if let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> {
    print("Found \(devices.count) HID interfaces:")
    for d in devices {
        let name = IOHIDDeviceGetProperty(d, kIOHIDProductKey as CFString) as? String ?? "Unknown"
        let page = IOHIDDeviceGetProperty(d, kIOHIDPrimaryUsagePageKey as CFString) as? Int ?? 0
        let usage = IOHIDDeviceGetProperty(d, kIOHIDPrimaryUsageKey as CFString) as? Int ?? 0
        print("  - Interface: '\(name)', Primary Page: 0x\(String(page, radix: 16)), Usage: 0x\(String(usage, radix: 16))")
        
        // List elements on device
        if let elements = IOHIDDeviceCopyMatchingElements(d, nil, IOOptionBits(kIOHIDOptionsTypeNone)) as? [IOHIDElement] {
            let buttonElements = elements.filter { IOHIDElementGetUsagePage($0) == 0x09 }
            print("    Button elements count: \(buttonElements.count)")
            for b in buttonElements {
                print("      Usage 0x\(String(IOHIDElementGetUsage(b), radix: 16)) (Min: \(IOHIDElementGetLogicalMin(b)), Max: \(IOHIDElementGetLogicalMax(b)))")
            }
        }
    }
}

// Run runloop for 2 seconds
CFRunLoopRunInMode(.defaultMode, 2.0, false)
IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
print("Probe complete.")
