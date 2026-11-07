import Foundation
import CoreGraphics
import IOKit
import IOKit.hid

print("--- Kreo Chimera V2 Calibration Capture (Max 30s) ---")
print("IOKit Device Filter: VID 0x248a, PID 0x5b4a (K Chimera USB Receiver)")
print("CGEventTap Scope: Global macOS Event Stream (Honest limitation: CGEventTap cannot guarantee device isolation)")
print("Listening for side button events...")

// 1. IOKit Device Matching (Device-Attributed)
let hidManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
let matchDict: [String: Any] = [
    kIOHIDVendorIDKey as String: 0x248a,
    kIOHIDProductIDKey as String: 0x5b4a
]
IOHIDManagerSetDeviceMatching(hidManager, matchDict as CFDictionary)

let inputCallback: IOHIDValueCallback = { context, result, sender, value in
    let element = IOHIDValueGetElement(value)
    let page = IOHIDElementGetUsagePage(element)
    let usage = IOHIDElementGetUsage(element)
    let intVal = IOHIDValueGetIntegerValue(value)
    
    // Only report button or consumer state changes
    if page == kHIDPage_Button {
        let state = intVal == 1 ? "PRESSED (down)" : "RELEASED (up)"
        print("[IOKit 0x248a:0x5b4a] Button Usage \(usage): \(state)")
    } else if page == kHIDPage_Consumer {
        print("[IOKit 0x248a:0x5b4a] Consumer Usage \(usage): value=\(intVal)")
    }
}

IOHIDManagerRegisterInputValueCallback(hidManager, inputCallback, nil)
IOHIDManagerScheduleWithRunLoop(hidManager, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes.rawValue)
IOHIDManagerOpen(hidManager, IOOptionBits(kIOHIDOptionsTypeNone))

// 2. CGEventTap (System Event Stream)
let mask = (1 << CGEventType.otherMouseDown.rawValue) |
           (1 << CGEventType.otherMouseUp.rawValue)

let tapCallback: CGEventTapCallBack = { proxy, type, event, refcon in
    let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
    let state = (type == .otherMouseDown) ? "DOWN" : "UP"
    print("[CGEvent System Stream] otherMouse button=\(buttonNumber) \(state)")
    return Unmanaged.passRetained(event)
}

if let tap = CGEvent.tapCreate(
    tap: .cghidEventTap,
    place: .headInsertEventTap,
    options: .listenOnly,
    eventsOfInterest: CGEventMask(mask),
    callback: tapCallback,
    userInfo: nil
) {
    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
} else {
    print("[Warning] Could not establish CGEventTap; relying solely on IOKit.")
}

// Bounded timer: exactly 30 seconds
DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
    print("Calibration window closed (30 seconds elapsed). Exiting.")
    IOHIDManagerClose(hidManager, IOOptionBits(kIOHIDOptionsTypeNone))
    exit(0)
}

CFRunLoopRun()
