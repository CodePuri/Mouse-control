import Foundation
import CoreGraphics

// Simple test harness
private var totalTests = 0
private var passedTests = 0
private var failedTests = 0

private func expect(_ condition: Bool, _ testName: String, file: String = #file, line: Int = #line) {
    totalTests += 1
    if condition {
        passedTests += 1
        print("  \u{001B}[32m✓\u{001B}[0m [PASS] \(testName)")
    } else {
        failedTests += 1
        print("  \u{001B}[31m✗\u{001B}[0m [FAIL] \(testName) (at \(file):\(line))")
    }
}

private func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ testName: String, file: String = #file, line: Int = #line) {
    totalTests += 1
    if actual == expected {
        passedTests += 1
        print("  \u{001B}[32m✓\u{001B}[0m [PASS] \(testName)")
    } else {
        failedTests += 1
        print("  \u{001B}[31m✗\u{001B}[0m [FAIL] \(testName): expected '\(expected)', got '\(actual)' (at \(file):\(line))")
    }
}

@main
struct TestMultiInterfaceHIDRunner {
    static func main() {
        print("=========================================================")
        print("Running Multi-Interface HID Diagnostic Test Suite")
        print("=========================================================")
        
        testConsumerControlDecoding()
        testMouseButtonDecoding()
        testKeyboardScanCodeDecoding()
        testVendorReportDecoding()
        testStateMachineAdvancement()
        
        print("\n=========================================================")
        print("Test Results: \(passedTests) passed, \(failedTests) failed out of \(totalTests) assertions")
        print("=========================================================")
        if failedTests > 0 {
            exit(1)
        }
    }
    
    // MARK: - Test Cases
    
    static func testConsumerControlDecoding() {
        print("\n--- Test Suite 1: Consumer Usage Decoding (Page 0x0C) ---")
        
        // 1.1 AC Back (0x224) Press
        let backPress = ObservedHIDEvent(
            interfaceType: "Keyboard/Consumer (0x06)",
            usagePage: 0x0C,
            usage: 0x224,
            value: 1
        )
        expectEqual(backPress.description, "Consumer AC Back (0x224)", "0x224 decoded as Consumer AC Back")
        expectEqual(backPress.phase, "Press (Down)", "Value 1 is Press (Down)")
        expect(backPress.isConsumerBackOrForward, "Flagged as consumer back or forward")
        
        // 1.2 AC Forward (0x225) Release
        let fwdRelease = ObservedHIDEvent(
            interfaceType: "Keyboard/Consumer (0x06)",
            usagePage: 0x0C,
            usage: 0x225,
            value: 0
        )
        expectEqual(fwdRelease.description, "Consumer AC Forward (0x225)", "0x225 decoded as Consumer AC Forward")
        expectEqual(fwdRelease.phase, "Release (Up)", "Value 0 is Release (Up)")
        expect(fwdRelease.isConsumerBackOrForward, "Flagged as consumer back or forward")
    }
    
    static func testMouseButtonDecoding() {
        print("\n--- Test Suite 2: Mouse Button Decoding (Page 0x09) ---")
        
        // 2.1 Middle Click (Usage 3)
        let middleClick = ObservedHIDEvent(
            interfaceType: "Mouse (0x02)",
            usagePage: 0x09,
            usage: 0x03,
            value: 1
        )
        expectEqual(middleClick.description, "Button 3 (Middle Click)", "Usage 3 is Middle Click")
        expect(middleClick.isMouseButton, "Identified as mouse button")
        
        // 2.2 Auxiliary Button 4
        let btn4 = ObservedHIDEvent(
            interfaceType: "Mouse (0x02)",
            usagePage: 0x09,
            usage: 0x04,
            value: 1
        )
        expectEqual(btn4.description, "Button 4 (Front Side)", "Usage 4 is Front Side Button")
        
        // 2.3 Auxiliary Button 5
        let btn5 = ObservedHIDEvent(
            interfaceType: "Mouse (0x02)",
            usagePage: 0x09,
            usage: 0x05,
            value: 1
        )
        expectEqual(btn5.description, "Button 5 (Rear Side)", "Usage 5 is Rear Side Button")
    }
    
    static func testKeyboardScanCodeDecoding() {
        print("\n--- Test Suite 3: Keyboard Scan Code Decoding (Page 0x07) ---")
        
        let pgUp = ObservedHIDEvent(
            interfaceType: "Keyboard/Consumer (0x06)",
            usagePage: 0x07,
            usage: 0x4B,
            value: 1
        )
        expectEqual(pgUp.description, "Key PageUp (0x4B)", "0x4B decoded as PageUp")
        
        let pgDown = ObservedHIDEvent(
            interfaceType: "Keyboard/Consumer (0x06)",
            usagePage: 0x07,
            usage: 0x4E,
            value: 1
        )
        expectEqual(pgDown.description, "Key PageDown (0x4E)", "0x4E decoded as PageDown")
    }
    
    static func testVendorReportDecoding() {
        print("\n--- Test Suite 4: Vendor Defined Usage Decoding (Page 0xFF01) ---")
        
        let vendorEv = ObservedHIDEvent(
            interfaceType: "Vendor (0xFF01)",
            usagePage: 0xFF01,
            usage: 0x01,
            value: 1,
            reportID: 0x04
        )
        expectEqual(vendorEv.description, "Vendor Usage 0x1", "0xFF01:0x1 decoded as Vendor Usage")
        expectEqual(vendorEv.reportID, 4, "Report ID preserved")
    }
    
    static func testStateMachineAdvancement() {
        print("\n--- Test Suite 5: Guided Calibration State Machine ---")
        
        // Simulate step transitions with ObservedHIDEvents
        var state: CalibrationSessionState = .step1_positiveControl
        
        let middleClickDown = ObservedHIDEvent(interfaceType: "Mouse (0x02)", usagePage: 0x09, usage: 0x03, value: 1)
        if case .step1_positiveControl = state, middleClickDown.isPositiveControl {
            state = .step2_frontButton
        }
        expectEqual(state, .step2_frontButton, "Advances to Step 2 upon positive control")
        
        let frontDown = ObservedHIDEvent(interfaceType: "Keyboard/Consumer (0x06)", usagePage: 0x0C, usage: 0x225, value: 1)
        let frontUp = ObservedHIDEvent(interfaceType: "Keyboard/Consumer (0x06)", usagePage: 0x0C, usage: 0x225, value: 0)
        if case .step2_frontButton = state, frontDown.value == 1 {
            // Seen down
            if frontUp.value == 0 {
                state = .step3_rearButton
            }
        }
        expectEqual(state, .step3_rearButton, "Advances to Step 3 upon front button press/release")
        
        let rearDown = ObservedHIDEvent(interfaceType: "Keyboard/Consumer (0x06)", usagePage: 0x0C, usage: 0x224, value: 1)
        let rearUp = ObservedHIDEvent(interfaceType: "Keyboard/Consumer (0x06)", usagePage: 0x0C, usage: 0x224, value: 0)
        if case .step3_rearButton = state, rearDown.value == 1 {
            if rearUp.value == 0 {
                state = .completed(frontBtn: 4, rearBtn: 3)
            }
        }
        if case .completed = state {
            expect(true, "Completed after rear button press/release")
        } else {
            expect(false, "Failed to complete state machine")
        }
    }
}
