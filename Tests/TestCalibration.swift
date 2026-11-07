import Foundation
import CoreGraphics

@main
struct TestCalibration {
    @MainActor
    static func main() async {
        print("=========================================================")
        print("Running Guided Calibration Test Suite")
        print("=========================================================")

        let engine = InputEngine()
        let dm = DeviceManager()

        // Test 1: Initial state
        var state = dm.calibrationState
        assert(state == .idle, "Initial state must be idle")
        print("  ✓ [PASS] Initial calibration state is idle")

        // Test 2: Start calibration
        dm.startCalibration(engine: engine)
        state = dm.calibrationState
        let isEngineCal = engine.isCalibrating
        assert(state == .step1_positiveControl, "Must enter step1_positiveControl")
        assert(isEngineCal, "Engine must enter calibration mode (transformations suspended)")
        print("  ✓ [PASS] Calibration started, pipeline in positive control check, transformations suspended")

        // Test 3: Positive control event (Button 2 Middle Click Down)
        dm.handleCalibrationEvent(button: 2, type: "Down", engine: engine)
        let observedPositive = dm.positiveControlObservedButton
        assert(observedPositive == 2, "Positive control observed button must be 2")
        print("  ✓ [PASS] Positive control event recorded (Button 2 Middle Click)")

        // Wait for auto-advance to step 2
        try? await Task.sleep(nanoseconds: 600_000_000)
        state = dm.calibrationState
        assert(state == .step2_frontButton, "Must advance to step 2: frontButton")
        print("  ✓ [PASS] Auto-advanced to Step 2: Front Button")

        // Test 4: Front button press and release
        dm.handleCalibrationEvent(button: 4, type: "Down", engine: engine)
        let detectedFront = dm.detectedFrontButton
        assert(detectedFront == 4, "Front button down recorded")
        dm.handleCalibrationEvent(button: 4, type: "Up", engine: engine)
        print("  ✓ [PASS] Front button press and release recorded")

        // Wait for auto-advance to step 3
        try? await Task.sleep(nanoseconds: 600_000_000)
        state = dm.calibrationState
        assert(state == .step3_rearButton, "Must advance to step 3: rearButton")
        print("  ✓ [PASS] Auto-advanced to Step 3: Rear Button")

        // Test 5: Rear button press and release
        dm.handleCalibrationEvent(button: 3, type: "Down", engine: engine)
        let detectedRear = dm.detectedRearButton
        assert(detectedRear == 3, "Rear button down recorded")
        dm.handleCalibrationEvent(button: 3, type: "Up", engine: engine)
        print("  ✓ [PASS] Rear button press and release recorded")

        // Test 6: Completion
        state = dm.calibrationState
        assert(state == .completed(frontBtn: 4, rearBtn: 3), "Must be in completed state with front=4, rear=3")
        let isEngineExited = !engine.isCalibrating
        assert(isEngineExited, "Engine must have exited calibration mode upon completion")
        print("  ✓ [PASS] Calibration completed, engine remapping restored")

        print("=========================================================")
        print("ALL GUIDED CALIBRATION TESTS PASSED (0 WARNINGS)!")
        print("=========================================================")
    }
}
