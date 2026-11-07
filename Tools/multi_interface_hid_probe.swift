import Foundation
import IOKit
import IOKit.hid
import CoreGraphics

@main
struct MultiInterfaceHIDProbe {
    static func main() {
        print("=================================================================")
        print("  KREO MULTI-INTERFACE HID & CONSUMER PROBE (10 SECONDS)")
        print("  Monitoring: Mouse (0x02), Keyboard (0x06), Consumer (0x0C), Vendor (0xFF01)")
        print("=================================================================")
        
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matchDict: [String: Any] = [
            kIOHIDVendorIDKey as String: 0x248a,
            kIOHIDProductIDKey as String: 0x5b4a
        ]
        IOHIDManagerSetDeviceMatching(manager, matchDict as CFDictionary)
        
        // 1. Input Value Callback for element transitions
        IOHIDManagerRegisterInputValueCallback(manager, { context, result, sender, value in
            let element = IOHIDValueGetElement(value)
            let page = IOHIDElementGetUsagePage(element)
            let usage = IOHIDElementGetUsage(element)
            let intVal = IOHIDValueGetIntegerValue(value)
            let time = IOHIDValueGetTimeStamp(value)
            
            // Format usage page and usage
            let pageHex = String(format: "0x%02X", page)
            let usageHex = String(format: "0x%04X", usage)
            
            var desc = "Unknown"
            
            switch page {
            case 0x09: // Button Page
                desc = "Mouse Button \(usage) (0x\(String(usage, radix: 16)))"
            case 0x0C: // Consumer Page
                if usage == 0x224 {
                    desc = "Consumer AC Back (0x224)"
                } else if usage == 0x225 {
                    desc = "Consumer AC Forward (0x225)"
                } else {
                    desc = "Consumer Usage 0x\(String(usage, radix: 16))"
                }
            case 0x07: // Keyboard Page
                // Do not log individual character letters to protect privacy
                if usage == 0x4B || usage == 0x4E { // PageUp / PageDown
                    desc = "Keyboard Scan Code (Nav/Function 0x\(String(usage, radix: 16)))"
                } else {
                    desc = "Keyboard Usage 0x\(String(usage, radix: 16)) [Non-text Metadata]"
                }
            case 0xFF01: // Vendor Page
                desc = "Vendor Usage 0x\(String(usage, radix: 16))"
            case 0x01: // Generic Desktop
                if usage == 0x38 {
                    desc = "Scroll Wheel"
                } else if usage == 0x30 || usage == 0x31 {
                    // Ignore normal continuous X/Y motion to avoid log flood
                    return
                } else {
                    desc = "Generic Desktop Usage 0x\(String(usage, radix: 16))"
                }
            default:
                desc = "Page \(pageHex) Usage \(usageHex)"
            }
            
            let phase = intVal != 0 ? "PRESS (Down)" : "RELEASE (Up)"
            print("  [HID VALUE] \(pageHex):\(usageHex) | \(desc) | Value: \(intVal) [\(phase)] (t: \(time))")
        }, nil)
        
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        let openStatus = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        print("IOHIDManager Open Status: \(openStatus == kIOReturnSuccess ? "SUCCESS" : "ERROR: \(openStatus)")")
        
        // 2. Register raw report callback on every matching device interface
        if let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> {
            print("Attached HID Interfaces: \(devices.count)")
            for dev in devices {
                let name = IOHIDDeviceGetProperty(dev, kIOHIDProductKey as CFString) as? String ?? "Unknown"
                let primaryPage = IOHIDDeviceGetProperty(dev, kIOHIDPrimaryUsagePageKey as CFString) as? Int ?? 0
                let primaryUsage = IOHIDDeviceGetProperty(dev, kIOHIDPrimaryUsageKey as CFString) as? Int ?? 0
                print("  -> Interface: '\(name)', Primary: 0x\(String(primaryPage, radix: 16)):0x\(String(primaryUsage, radix: 16))")
                
                // Allocate report buffer (64 bytes is standard for USB HID interrupt endpoints)
                let reportBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
                IOHIDDeviceRegisterInputReportCallback(dev, reportBuffer, 64, { context, result, sender, type, reportID, report, reportLength in
                    let bytes = Array(UnsafeBufferPointer(start: report, count: reportLength))
                    let hexDump = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
                    
                    // Filter out pure mouse motion reports (e.g. mouse reports with buttons=0 and small delta) to reduce flood
                    let isAllZero = bytes.allSatisfy { $0 == 0 }
                    if !isAllZero {
                        print("    [RAW REPORT] Type: \(type), ID: 0x\(String(reportID, radix: 16)), Len: \(reportLength), Bytes: [\(hexDump)]")
                    }
                }, nil)
            }
        }
        
        print("\nProbe is running for 10 seconds. Listening for ANY input on all interfaces...")
        CFRunLoopRunInMode(.defaultMode, 10.0, false)
        
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        print("Probe finished.")
    }
}
