import Foundation
import CoreGraphics

@main
struct TestCalibration {
    @MainActor
    static func main() async {
        print("=========================================================")
        print("Running Strict Guided Calibration & Safety Regression Suite")
        print("=========================================================")

        let engine = InputEngine()
        let dm = DeviceManager()

        // -------------------------------------------------------------
        // Test 1: Initial state
        // -------------------------------------------------------------
        assert(dm.calibrationState == .idle, "Initial state must be idle")
        print("  ✓ [PASS] Initial calibration state is idle")

        // -------------------------------------------------------------
        // Test 2: InputEngine Safety Barrier (Buttons 0, 1, 2)
        // -------------------------------------------------------------
        print("\n--- Verifying InputEngine Safety Barrier ---")
        engine.setAction(.wisprFlowPTT(), forButton: 0) // Left click
        assert(engine.action(forButton: 0) == nil, "InputEngine MUST reject remapping Button 0 (Left Click)")
        engine.setAction(.undo, forButton: 1) // Right click
        assert(engine.action(forButton: 1) == nil, "InputEngine MUST reject remapping Button 1 (Right Click)")
        engine.setAction(.undo, forButton: 2) // Middle click
        assert(engine.action(forButton: 2) == nil, "InputEngine MUST reject remapping Button 2 (Middle Click)")
        print("  ✓ [PASS] InputEngine strictly rejects registering actions for buttons 0, 1, 2")

        // Verify handleEvent safety: simulate an event for button 0
        if let dummyEvent = CGEvent(source: nil) {
            dummyEvent.setIntegerValueField(.mouseEventButtonNumber, value: 0)
            let result = engine.handleEvent(proxy: nil, type: .otherMouseDown, event: dummyEvent)
            assert(result != nil, "Button 0 event MUST NEVER be suppressed by InputEngine")
        }
        if let dummyEvent1 = CGEvent(source: nil) {
            dummyEvent1.setIntegerValueField(.mouseEventButtonNumber, value: 1)
            let result = engine.handleEvent(proxy: nil, type: .otherMouseDown, event: dummyEvent1)
            assert(result != nil, "Button 1 event MUST NEVER be suppressed by InputEngine")
        }
        if let dummyEvent2 = CGEvent(source: nil) {
            dummyEvent2.setIntegerValueField(.mouseEventButtonNumber, value: 2)
            let result = engine.handleEvent(proxy: nil, type: .otherMouseDown, event: dummyEvent2)
            assert(result != nil, "Button 2 event MUST NEVER be suppressed by InputEngine")
        }
        print("  ✓ [PASS] InputEngine handleEvent hard-passes buttons 0, 1, 2 without suppression")

        // -------------------------------------------------------------
        // Test 3: Start calibration
        // -------------------------------------------------------------
        print("\n--- Testing Guided Calibration Step 1: Positive Control ---")
        dm.startCalibration(engine: engine)
        assert(dm.calibrationState == .step1_positiveControl, "Must enter step1_positiveControl")
        assert(engine.isCalibrating, "Engine must enter calibration mode")

        // Rejection in Step 1: Left Click (0) or Right Click (1) must NOT satisfy positive control!
        dm.handleCalibrationEvent(button: 0, type: "Down", engine: engine)
        assert(dm.positiveControlObservedButton == nil, "Button 0 (Left Click) MUST NOT satisfy positive control")
        assert(dm.calibrationState == .step1_positiveControl, "Left Click must not advance Step 1")

        dm.handleCalibrationEvent(button: 1, type: "Down", engine: engine)
        assert(dm.positiveControlObservedButton == nil, "Button 1 (Right Click) MUST NOT satisfy positive control")
        assert(dm.calibrationState == .step1_positiveControl, "Right Click must not advance Step 1")
        print("  ✓ [PASS] Step 1 rejects Left Click (0) and Right Click (1) as positive control")

        // Valid Positive Control: Middle Click (Button 2)
        dm.handleCalibrationEvent(button: 2, type: "Down", engine: engine)
        assert(dm.positiveControlObservedButton == 2, "Button 2 (Middle Click) satisfies positive control")
        try? await Task.sleep(nanoseconds: 600_000_000)
        assert(dm.calibrationState == .step2_frontButton, "Must advance to step 2 after middle click")
        print("  ✓ [PASS] Step 1 accepted Middle Click (2) and advanced to Step 2")

        // -------------------------------------------------------------
        // Test 4: Step 2: Front Button Rejection of 0, 1, 2
        // -------------------------------------------------------------
        print("\n--- Testing Guided Calibration Step 2: Front Side Button ---")
        // User clicks left click (0) on UI
        dm.handleCalibrationEvent(button: 0, type: "Down", engine: engine)
        assert(dm.detectedFrontButton == nil, "Button 0 (Left Click) MUST NOT be captured as front button")
        dm.handleCalibrationEvent(button: 0, type: "Up", engine: engine)
        assert(dm.calibrationState == .step2_frontButton, "Left Click must NOT advance to Step 3")

        // User clicks right click (1)
        dm.handleCalibrationEvent(button: 1, type: "Down", engine: engine)
        assert(dm.detectedFrontButton == nil, "Button 1 (Right Click) MUST NOT be captured as front button")
        dm.handleCalibrationEvent(button: 1, type: "Up", engine: engine)
        assert(dm.calibrationState == .step2_frontButton, "Right Click must NOT advance to Step 3")

        // User clicks middle click (2)
        dm.handleCalibrationEvent(button: 2, type: "Down", engine: engine)
        assert(dm.detectedFrontButton == nil, "Button 2 (Middle Click) MUST NOT be captured as front button")
        dm.handleCalibrationEvent(button: 2, type: "Up", engine: engine)
        assert(dm.calibrationState == .step2_frontButton, "Middle Click must NOT advance to Step 3")
        print("  ✓ [PASS] Step 2 strictly ignores Buttons 0, 1, 2 (Left, Right, Middle)")

        // Valid Front Side Button: Quartz Button 4
        dm.handleCalibrationEvent(button: 4, type: "Down", engine: engine)
        assert(dm.detectedFrontButton == 4, "Front button down recorded")
        dm.handleCalibrationEvent(button: 4, type: "Up", engine: engine)
        try? await Task.sleep(nanoseconds: 600_000_000)
        assert(dm.calibrationState == .step3_rearButton, "Must advance to Step 3 after valid Front button")
        print("  ✓ [PASS] Step 2 accepted valid Front Side Button (4) and advanced to Step 3")

        // -------------------------------------------------------------
        // Test 5: Step 3: Rear Button Rejection of 0, 1, 2 & Duplicate Button
        // -------------------------------------------------------------
        print("\n--- Testing Guided Calibration Step 3: Rear Side Button ---")
        // CRITICAL BUG REPRODUCTION: User clicks Left Click (0) to interact with UI while in Step 3!
        dm.handleCalibrationEvent(button: 0, type: "Down", engine: engine)
        assert(dm.detectedRearButton == nil, "Button 0 (Left Click) MUST NEVER be captured as rear button!")
        dm.handleCalibrationEvent(button: 0, type: "Up", engine: engine)
        assert(dm.calibrationState == .step3_rearButton, "Left Click MUST NEVER complete calibration or set rear button to 0!")

        // Duplicate rejection: User presses the SAME Front Button (4) again during Step 3
        dm.handleCalibrationEvent(button: 4, type: "Down", engine: engine)
        assert(dm.detectedRearButton != 4, "Rear button MUST NOT accept the identical button as Front button (4)")
        dm.handleCalibrationEvent(button: 4, type: "Up", engine: engine)
        assert(dm.calibrationState == .step3_rearButton, "Duplicate button must NOT complete calibration")
        print("  ✓ [PASS] Step 3 rejects Left Click (0) and duplicate Front Button (4)")

        // Valid Rear Side Button: Quartz Button 3
        dm.handleCalibrationEvent(button: 3, type: "Down", engine: engine)
        assert(dm.detectedRearButton == 3, "Rear button down recorded")
        dm.handleCalibrationEvent(button: 3, type: "Up", engine: engine)
        assert(dm.calibrationState == .completed(frontBtn: 4, rearBtn: 3), "Calibration must complete with Front 4, Rear 3")
        assert(!engine.isCalibrating, "Engine must exit calibration mode")
        print("  ✓ [PASS] Step 3 accepted distinct Rear Side Button (3) and completed successfully")

        // -------------------------------------------------------------
        // Test 6: HID Multi-Interface Value Handling Rejections
        // -------------------------------------------------------------
        print("\n--- Testing HID Multi-Interface Rejections ---")
        let dm2 = DeviceManager()
        dm2.startCalibration(engine: engine)

        // HID Button 1 (Left Click down: page 0x09, usage 1, value 1)
        dm2.handleRawHIDValue(interfaceName: "Mouse (0x02)", page: 0x09, usage: 1, intVal: 1)
        assert(dm2.positiveControlObservedButton == nil, "HID Usage 1 (Left Click) must NOT be positive control")
        assert(dm2.calibrationState == .step1_positiveControl, "HID Left click must not advance state")

        // HID Middle Click (page 0x09, usage 3, value 1)
        dm2.handleRawHIDValue(interfaceName: "Mouse (0x02)", page: 0x09, usage: 3, intVal: 1)
        assert(dm2.positiveControlObservedButton == 2, "HID Usage 3 (Middle Click) satisfies positive control")
        try? await Task.sleep(nanoseconds: 600_000_000)
        assert(dm2.calibrationState == .step2_frontButton, "Must advance to step 2")

        // HID Left Click or Right Click in Step 2 must be rejected
        dm2.handleRawHIDValue(interfaceName: "Mouse (0x02)", page: 0x09, usage: 1, intVal: 1)
        assert(dm2.detectedFrontButton == nil, "HID Left Click must NOT be captured as front side button")
        dm2.handleRawHIDValue(interfaceName: "Mouse (0x02)", page: 0x09, usage: 2, intVal: 1)
        assert(dm2.detectedFrontButton == nil, "HID Right Click must NOT be captured as front side button")
        dm2.handleRawHIDValue(interfaceName: "Generic Desktop (0x01)", page: 0x01, usage: 0x38, intVal: 1) // Scroll wheel
        assert(dm2.detectedFrontButton == nil, "HID Scroll Wheel must NOT be captured as front side button")

        // HID Release Value 0 must NOT be interpreted as Button ID 0
        dm2.handleRawHIDValue(interfaceName: "Mouse (0x02)", page: 0x09, usage: 1, intVal: 0)
        assert(dm2.detectedFrontButton == nil, "HID Release (intVal 0) must not set button 0")

        // Valid HID Consumer AC Forward (0x0C:0x225)
        dm2.handleRawHIDValue(interfaceName: "Keyboard/Consumer (0x06)", page: 0x0C, usage: 0x225, intVal: 1)
        assert(dm2.detectedFrontButton == 4, "Consumer AC Forward must map to Front Side Button 4")
        dm2.handleRawHIDValue(interfaceName: "Keyboard/Consumer (0x06)", page: 0x0C, usage: 0x225, intVal: 0)
        try? await Task.sleep(nanoseconds: 600_000_000)
        assert(dm2.calibrationState == .step3_rearButton, "Must advance to Step 3")

        // Step 3: Consumer AC Back (0x0C:0x224)
        dm2.handleRawHIDValue(interfaceName: "Keyboard/Consumer (0x06)", page: 0x0C, usage: 0x224, intVal: 1)
        assert(dm2.detectedRearButton == 3, "Consumer AC Back must map to Rear Side Button 3")
        dm2.handleRawHIDValue(interfaceName: "Keyboard/Consumer (0x06)", page: 0x0C, usage: 0x224, intVal: 0)
        assert(dm2.calibrationState == .completed(frontBtn: 4, rearBtn: 3), "HID calibration complete")
        print("  ✓ [PASS] Multi-interface HID correctly rejects buttons 1, 2, scroll wheel, and handles release 0")

        print("\n=========================================================")
        print("ALL STRICT CALIBRATION & SAFETY REGRESSION TESTS PASSED!")
        print("=========================================================")
    }
}
