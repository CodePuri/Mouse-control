import Cocoa
import Foundation

print("=== Wispr Flow Shortcut Injection Tester ===")
print("Checking Accessibility status: \(AXIsProcessTrusted())")

// 1. Verify Wispr Flow is running
let runningFlow = NSRunningApplication.runningApplications(withBundleIdentifier: "com.electron.wispr-flow")
print("Wispr Flow running instances: \(runningFlow.count)")

// 2. Open TextEdit to provide a focused target for dictation
print("Activating TextEdit...")
let textEditScript = "tell application \"TextEdit\" to activate"
var error: NSDictionary?
if let script = NSAppleScript(source: textEditScript) {
    script.executeAndReturnError(&error)
}

print("Starting 3-second countdown to focus TextEdit...")
for i in (1...3).reversed() {
    print("\(i)...")
    Thread.sleep(forTimeInterval: 1.0)
}

func testHoldKey(keyCode: CGKeyCode, duration: TimeInterval, label: String, useHidSource: Bool) {
    print("\n--- Testing: \(label) (KeyCode \(keyCode), Duration: \(duration)s, HIDSource: \(useHidSource)) ---")
    
    let source: CGEventSource? = useHidSource ? CGEventSource(stateID: .hidSystemState) : nil
    
    guard let downEvent = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) else {
        print("Failed to create down event")
        return
    }
    guard let upEvent = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
        print("Failed to create up event")
        return
    }
    
    print("Posting down event (type: \(downEvent.type.rawValue), flags: \(downEvent.flags.rawValue))...")
    downEvent.post(tap: .cghidEventTap)
    
    let holdSteps = Int(duration * 10)
    for s in 1...holdSteps {
        Thread.sleep(forTimeInterval: 0.1)
        if s % 5 == 0 {
            print("Holding... (\(Double(s) * 0.1)s)")
        }
    }
    
    print("Posting up event (type: \(upEvent.type.rawValue), flags: \(upEvent.flags.rawValue))...")
    upEvent.post(tap: .cghidEventTap)
    print("Key released.")
}

// Test with KeyCode 61 (Right Option - Wispr Flow's configured shortcut)
testHoldKey(keyCode: 61, duration: 2.0, label: "Right Option (PTT)", useHidSource: true)

print("\nWaiting 2 seconds before next test...")
Thread.sleep(forTimeInterval: 2.0)

// Test with KeyCode 58 (Left Option - just in case user keyboard has Left Option)
testHoldKey(keyCode: 58, duration: 2.0, label: "Left Option", useHidSource: true)

print("\n=== Injection Test Completed ===")
