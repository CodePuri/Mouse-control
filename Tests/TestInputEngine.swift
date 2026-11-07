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

// MARK: - Test Suites

func testSyntheticKeyGenerationAndTagging() {
    print("\n--- Test Suite 1: Synthetic Key Generation & Tagging (0x4D435452) ---")

    // 1.1 Wispr Flow PTT synthetic events (KeyCode 61 Right Option)
    let pttDown = InputEngine.createSyntheticKeyEvent(keyCode: 61, isDown: true)
    expect(pttDown != nil, "Wispr Flow PTT key-down event created")
    if let pttDown = pttDown {
        expectEqual(pttDown.getIntegerValueField(.keyboardEventKeycode), 61, "PTT key-down keycode is 61")
        expectEqual(pttDown.getIntegerValueField(.eventSourceUserData), InputEngine.magicEventMarker, "PTT key-down tagged with magic marker 0x4D435452")
        expect(pttDown.flags.contains(.maskAlternate), "PTT key-down has maskAlternate flag")
    }

    let pttUp = InputEngine.createSyntheticKeyEvent(keyCode: 61, isDown: false)
    expect(pttUp != nil, "Wispr Flow PTT key-up event created")
    if let pttUp = pttUp {
        expectEqual(pttUp.getIntegerValueField(.keyboardEventKeycode), 61, "PTT key-up keycode is 61")
        expectEqual(pttUp.getIntegerValueField(.eventSourceUserData), InputEngine.magicEventMarker, "PTT key-up tagged with magic marker 0x4D435452")
        expect(!pttUp.flags.contains(.maskAlternate), "PTT key-up does not have maskAlternate flag")
    }

    // 1.2 Custom Shortcut synthetic event (KeyCode 9 'V', flags Command)
    let scDown = InputEngine.createSyntheticKeyEvent(keyCode: 9, flags: .maskCommand, isDown: true)
    expect(scDown != nil, "Shortcut key-down created")
    if let scDown = scDown {
        expectEqual(scDown.getIntegerValueField(.keyboardEventKeycode), 9, "Shortcut key-down keycode is 9")
        expectEqual(scDown.getIntegerValueField(.eventSourceUserData), InputEngine.magicEventMarker, "Shortcut key-down tagged with 0x4D435452")
        expect(scDown.flags.contains(.maskCommand), "Shortcut key-down has maskCommand")
    }

    // 1.3 Undo synthetic event (KeyCode 6 'Z', Command)
    let undoDown = InputEngine.createSyntheticKeyEvent(keyCode: 6, flags: .maskCommand, isDown: true)
    expect(undoDown != nil, "Undo key-down created")
    if let undoDown = undoDown {
        expectEqual(undoDown.getIntegerValueField(.keyboardEventKeycode), 6, "Undo keycode is 6 ('Z')")
        expect(undoDown.flags.contains(.maskCommand), "Undo has maskCommand")
        expectEqual(undoDown.getIntegerValueField(.eventSourceUserData), InputEngine.magicEventMarker, "Undo tagged with 0x4D435452")
    }

    // 1.4 Redo synthetic event (KeyCode 6 'Z', Command + Shift)
    let redoDown = InputEngine.createSyntheticKeyEvent(keyCode: 6, flags: [.maskCommand, .maskShift], isDown: true)
    expect(redoDown != nil, "Redo key-down created")
    if let redoDown = redoDown {
        expectEqual(redoDown.getIntegerValueField(.keyboardEventKeycode), 6, "Redo keycode is 6 ('Z')")
        expect(redoDown.flags.contains(.maskCommand), "Redo has maskCommand")
        expect(redoDown.flags.contains(.maskShift), "Redo has maskShift")
        expectEqual(redoDown.getIntegerValueField(.eventSourceUserData), InputEngine.magicEventMarker, "Redo tagged with 0x4D435452")
    }

    // 1.5 Loop Prevention: incoming event with 0x4D435452 marker must be ignored/passed through
    let engine = InputEngine(mappings: [4: .wisprFlowPTT(keyCode: 61)])
    var syntheticEvents: [CGEvent] = []
    engine.eventPoster = { event, _ in syntheticEvents.append(event) }

    let loopEvent = InputEngine.createMouseEvent(type: .otherMouseDown, buttonNumber: 4, marker: InputEngine.magicEventMarker)!
    let loopResult = engine.handleEvent(proxy: nil, type: .otherMouseDown, event: loopEvent)
    expect(loopResult != nil, "Event with 0x4D435452 is passed through untouched (loop prevention)")
    expect(syntheticEvents.isEmpty, "No synthetic events generated for tagged event")
    expect(engine.currentLatchedActions().isEmpty, "No actions latched for tagged event")
}

func testActionLatching() {
    print("\n--- Test Suite 2: Action Latching (Down -> Up) ---")

    let engine = InputEngine(mappings: [
        4: .wisprFlowPTT(keyCode: 61),
        3: .undo
    ])

    var postedEvents: [CGEvent] = []
    engine.eventPoster = { event, _ in postedEvents.append(event) }

    // 2.1 Basic latching: press down button 4
    let b4Down = InputEngine.createMouseEvent(type: .otherMouseDown, buttonNumber: 4)!
    let res4Down = engine.handleEvent(proxy: nil, type: .otherMouseDown, event: b4Down)
    expect(res4Down == nil, "Button 4 down is suppressed (returns nil)")
    expectEqual(engine.currentLatchedActions()[4], .wisprFlowPTT(keyCode: 61), "Button 4 action is latched as Wispr Flow PTT")
    expectEqual(postedEvents.count, 1, "One synthetic key posted on down")
    expectEqual(postedEvents.first?.getIntegerValueField(.keyboardEventKeycode), 61, "Keycode 61 posted on down")

    // 2.2 Protect release when mapping changes while button is held
    // Change mapping of button 4 to .redo while physically holding button 4 down!
    engine.setAction(.redo, forButton: 4)
    expectEqual(engine.action(forButton: 4), .redo, "Button 4 mapping successfully updated to .redo")
    expectEqual(engine.currentLatchedActions()[4], .wisprFlowPTT(keyCode: 61), "Latched action remains .wisprFlowPTT while button is held")

    // Release button 4
    let b4Up = InputEngine.createMouseEvent(type: .otherMouseUp, buttonNumber: 4)!
    let res4Up = engine.handleEvent(proxy: nil, type: .otherMouseUp, event: b4Up)
    expect(res4Up == nil, "Button 4 up is suppressed (returns nil)")
    expectEqual(postedEvents.count, 2, "Second synthetic key posted on up")
    expectEqual(postedEvents.last?.getIntegerValueField(.keyboardEventKeycode), 61, "Released keycode is 61 (matching latched PTT, NOT redo)")
    expect(engine.currentLatchedActions()[4] == nil, "Button 4 latch is cleared after up")

    // Next press uses updated mapping
    let b4DownNew = InputEngine.createMouseEvent(type: .otherMouseDown, buttonNumber: 4)!
    _ = engine.handleEvent(proxy: nil, type: .otherMouseDown, event: b4DownNew)
    expectEqual(engine.currentLatchedActions()[4], .redo, "Subsequent press latches the new action .redo")
    expectEqual(postedEvents.last?.getIntegerValueField(.keyboardEventKeycode), 6, "New press dispatches keycode 6 for Redo")
    _ = engine.handleEvent(proxy: nil, type: .otherMouseUp, event: b4Up)

    // 2.3 Concurrent multi-button latching
    postedEvents.removeAll()
    engine.setAction(.undo, forButton: 3)
    engine.setAction(.wisprFlowPTT(keyCode: 61), forButton: 4)

    let b3Down = InputEngine.createMouseEvent(type: .otherMouseDown, buttonNumber: 3)!
    _ = engine.handleEvent(proxy: nil, type: .otherMouseDown, event: b3Down)
    _ = engine.handleEvent(proxy: nil, type: .otherMouseDown, event: b4Down)

    expectEqual(engine.currentLatchedActions().count, 2, "Both button 3 and 4 latched simultaneously")
    expectEqual(engine.currentLatchedActions()[3], .undo, "Button 3 latched as Undo")
    expectEqual(engine.currentLatchedActions()[4], .wisprFlowPTT(keyCode: 61), "Button 4 latched as PTT")

    // Release button 4 first
    _ = engine.handleEvent(proxy: nil, type: .otherMouseUp, event: b4Up)
    expectEqual(engine.currentLatchedActions().count, 1, "Only button 3 remains latched")
    expectEqual(engine.currentLatchedActions()[3], .undo, "Button 3 still latched as Undo")
    expectEqual(postedEvents.last?.getIntegerValueField(.keyboardEventKeycode), 61, "Released button 4 dispatches PTT keyup 61")

    // Release button 3
    let b3Up = InputEngine.createMouseEvent(type: .otherMouseUp, buttonNumber: 3)!
    _ = engine.handleEvent(proxy: nil, type: .otherMouseUp, event: b3Up)
    expect(engine.currentLatchedActions().isEmpty, "All latches cleared after all buttons released")
    expectEqual(postedEvents.last?.getIntegerValueField(.keyboardEventKeycode), 6, "Released button 3 dispatches Undo keyup 6")
}

func testSuppressionLogic() {
    print("\n--- Test Suite 3: Event Suppression Logic ---")

    let engine = InputEngine(mappings: [
        3: .undo,
        4: .wisprFlowPTT(keyCode: 61),
        5: .disabled,
        6: .passthrough
    ])

    var postedEvents: [CGEvent] = []
    engine.eventPoster = { event, _ in postedEvents.append(event) }

    // 3.1 Configured buttons (3 and 4) are suppressed (return nil)
    let b4Down = InputEngine.createMouseEvent(type: .otherMouseDown, buttonNumber: 4)!
    let b4Up = InputEngine.createMouseEvent(type: .otherMouseUp, buttonNumber: 4)!
    expect(engine.handleEvent(proxy: nil, type: .otherMouseDown, event: b4Down) == nil, "Mapped button 4 down returns nil (suppressed)")
    expect(engine.handleEvent(proxy: nil, type: .otherMouseUp, event: b4Up) == nil, "Mapped button 4 up returns nil (suppressed)")

    let b3Down = InputEngine.createMouseEvent(type: .otherMouseDown, buttonNumber: 3)!
    let b3Up = InputEngine.createMouseEvent(type: .otherMouseUp, buttonNumber: 3)!
    expect(engine.handleEvent(proxy: nil, type: .otherMouseDown, event: b3Down) == nil, "Mapped button 3 down returns nil (suppressed)")
    expect(engine.handleEvent(proxy: nil, type: .otherMouseUp, event: b3Up) == nil, "Mapped button 3 up returns nil (suppressed)")

    // 3.2 Disabled button is suppressed (returns nil) but emits NO synthetic keys
    postedEvents.removeAll()
    let b5Down = InputEngine.createMouseEvent(type: .otherMouseDown, buttonNumber: 5)!
    let b5Up = InputEngine.createMouseEvent(type: .otherMouseUp, buttonNumber: 5)!
    expect(engine.handleEvent(proxy: nil, type: .otherMouseDown, event: b5Down) == nil, "Disabled button 5 down returns nil (suppressed)")
    expect(engine.handleEvent(proxy: nil, type: .otherMouseUp, event: b5Up) == nil, "Disabled button 5 up returns nil (suppressed)")
    expect(postedEvents.isEmpty, "Disabled button emits no synthetic keys")

    // 3.3 Unmapped button (button 7) passes through (returns event, non-nil)
    postedEvents.removeAll()
    let b7Down = InputEngine.createMouseEvent(type: .otherMouseDown, buttonNumber: 7)!
    let b7Up = InputEngine.createMouseEvent(type: .otherMouseUp, buttonNumber: 7)!
    expect(engine.handleEvent(proxy: nil, type: .otherMouseDown, event: b7Down) != nil, "Unmapped button 7 down passes through (non-nil)")
    expect(engine.handleEvent(proxy: nil, type: .otherMouseUp, event: b7Up) != nil, "Unmapped button 7 up passes through (non-nil)")
    expect(postedEvents.isEmpty, "Unmapped button emits no synthetic keys")

    // 3.4 Passthrough action button (button 6) passes through (returns event)
    let b6Down = InputEngine.createMouseEvent(type: .otherMouseDown, buttonNumber: 6)!
    let b6Up = InputEngine.createMouseEvent(type: .otherMouseUp, buttonNumber: 6)!
    expect(engine.handleEvent(proxy: nil, type: .otherMouseDown, event: b6Down) != nil, "Passthrough button 6 down passes through (non-nil)")
    expect(engine.handleEvent(proxy: nil, type: .otherMouseUp, event: b6Up) != nil, "Passthrough button 6 up passes through (non-nil)")
    expect(postedEvents.isEmpty, "Passthrough button emits no synthetic keys")

    // 3.5 Non-other mouse events (left click, right click) pass through untouched
    let leftDown = InputEngine.createMouseEvent(type: .leftMouseDown, buttonNumber: 0)!
    let rightDown = InputEngine.createMouseEvent(type: .rightMouseDown, buttonNumber: 1)!
    expect(engine.handleEvent(proxy: nil, type: .leftMouseDown, event: leftDown) != nil, "Left mouse down passes through")
    expect(engine.handleEvent(proxy: nil, type: .rightMouseDown, event: rightDown) != nil, "Right mouse down passes through")
}

func testPauseResumeToggling() {
    print("\n--- Test Suite 4: Pause / Resume Toggling ---")

    let engine = InputEngine(mappings: [
        4: .wisprFlowPTT(keyCode: 61)
    ])

    var postedEvents: [CGEvent] = []
    engine.eventPoster = { event, _ in postedEvents.append(event) }

    expect(!engine.isPaused, "Engine is initially unpaused")

    // 4.1 Paused engine passes all events through untouched
    engine.pause()
    expect(engine.isPaused, "Engine is paused after pause()")

    let b4Down = InputEngine.createMouseEvent(type: .otherMouseDown, buttonNumber: 4)!
    let b4Up = InputEngine.createMouseEvent(type: .otherMouseUp, buttonNumber: 4)!

    let resPausedDown = engine.handleEvent(proxy: nil, type: .otherMouseDown, event: b4Down)
    expect(resPausedDown != nil, "Button 4 down passes through when paused (non-nil)")
    expect(postedEvents.isEmpty, "No synthetic keys emitted while paused")
    expect(engine.currentLatchedActions().isEmpty, "Nothing latched while paused")

    let resPausedUp = engine.handleEvent(proxy: nil, type: .otherMouseUp, event: b4Up)
    expect(resPausedUp != nil, "Button 4 up passes through when paused (non-nil)")

    // 4.2 Resume restores suppression and synthetic key emission
    engine.resume()
    expect(!engine.isPaused, "Engine is unpaused after resume()")

    let resResumedDown = engine.handleEvent(proxy: nil, type: .otherMouseDown, event: b4Down)
    expect(resResumedDown == nil, "Button 4 down is suppressed after resume (returns nil)")
    expectEqual(postedEvents.count, 1, "Synthetic key posted on down after resume")

    let resResumedUp = engine.handleEvent(proxy: nil, type: .otherMouseUp, event: b4Up)
    expect(resResumedUp == nil, "Button 4 up is suppressed after resume (returns nil)")
    expectEqual(postedEvents.count, 2, "Synthetic key-up posted on up after resume")

    // 4.3 Toggle pause convenience method
    expect(engine.togglePause() == true, "togglePause() toggles from false to true")
    expect(engine.isPaused, "isPaused is true")
    expect(engine.togglePause() == false, "togglePause() toggles from true to false")
    expect(!engine.isPaused, "isPaused is false")

    // 4.4 Latched key held down across a pause call is safely released on up
    postedEvents.removeAll()
    _ = engine.handleEvent(proxy: nil, type: .otherMouseDown, event: b4Down)
    expectEqual(postedEvents.count, 1, "Button down latched and synthetic key posted")
    expectEqual(engine.currentLatchedActions().count, 1, "Action latched")

    // Pause while key is held down
    engine.pause()
    expect(engine.isPaused, "Engine paused while button held")

    // Button up arrives
    let resHeldUp = engine.handleEvent(proxy: nil, type: .otherMouseUp, event: b4Up)
    expect(resHeldUp == nil, "Button up handled to release held key (returns nil)")
    expectEqual(postedEvents.count, 2, "Synthetic key-up posted to prevent stuck key")
    expect(engine.currentLatchedActions().isEmpty, "Latch cleared")
}

func testLifecycleAndCleanup() {
    print("\n--- Test Suite 5: Background Lifecycle, Thread Safety & Cleanup ---")

    let engine = InputEngine(mappings: [
        3: .undo,
        4: .wisprFlowPTT(keyCode: 61)
    ])

    var postedEvents: [CGEvent] = []
    engine.eventPoster = { event, _ in postedEvents.append(event) }

    // 5.1 Clean start and stop
    let started = engine.start()
    expect(started, "engine.start() succeeded")
    expect(engine.isRunning, "engine.isRunning is true")

    // Verify calling start again is idempotent
    expect(engine.start(), "Second start() is idempotent and returns true")

    // Stop engine
    engine.stop()
    expect(!engine.isRunning, "engine.isRunning is false after stop()")

    // 5.2 Stop with held key cleanly releases synthetic key
    postedEvents.removeAll()
    let b3Down = InputEngine.createMouseEvent(type: .otherMouseDown, buttonNumber: 3)!
    _ = engine.handleEvent(proxy: nil, type: .otherMouseDown, event: b3Down)
    expectEqual(postedEvents.count, 1, "Synthetic Undo down posted")
    expectEqual(engine.currentLatchedActions().count, 1, "Action latched before stop")

    // Call stop() while key is latched down
    engine.stop()
    expectEqual(postedEvents.count, 2, "Synthetic Undo up cleanly dispatched during stop()")
    expectEqual(postedEvents.last?.getIntegerValueField(.keyboardEventKeycode), 6, "Released keycode is 6 ('Z')")
    expect(engine.currentLatchedActions().isEmpty, "Latched actions cleared after stop()")
}

func testCalibrationMode() {
    print("\n--- Test Suite 6: Calibration Observation Mode & Positive Control ---")

    var postedEvents: [CGEvent] = []
    let engine = InputEngine(mappings: [
        4: .wisprFlowPTT(keyCode: 61),
        3: .undo
    ])
    engine.eventPoster = { event, _ in
        postedEvents.append(event)
    }

    expect(!engine.isCalibrating, "Engine is not calibrating by default")

    var observedRawEvents: [(button: Int, type: CGEventType)] = []
    engine.onRawCalibrationEvent = { btn, type, _ in
        observedRawEvents.append((btn, type))
    }

    // 6.1 Before calibration: mapped button 4 down is suppressed
    let b4Down = InputEngine.createMouseEvent(type: .otherMouseDown, buttonNumber: 4)!
    let resultBefore = engine.handleEvent(proxy: nil, type: .otherMouseDown, event: b4Down)
    expect(resultBefore == nil, "Before calibration: button 4 down is suppressed")
    expectEqual(postedEvents.count, 1, "Synthetic PTT key posted")
    expectEqual(observedRawEvents.count, 0, "No raw calibration events reported while not calibrating")

    // Release held button 4
    let b4Up = InputEngine.createMouseEvent(type: .otherMouseUp, buttonNumber: 4)!
    _ = engine.handleEvent(proxy: nil, type: .otherMouseUp, event: b4Up)
    postedEvents.removeAll()

    // 6.2 Enter calibration mode
    engine.enterCalibrationMode()
    expect(engine.isCalibrating, "Engine is now in calibration mode")

    // 6.3 In calibration mode: button 4 down is NOT suppressed and reported to callback
    let calB4Down = InputEngine.createMouseEvent(type: .otherMouseDown, buttonNumber: 4)!
    let resultCalDown = engine.handleEvent(proxy: nil, type: .otherMouseDown, event: calB4Down)
    expect(resultCalDown != nil, "During calibration: button 4 down passes through untouched (non-nil)")
    expectEqual(postedEvents.count, 0, "No synthetic keys posted during calibration")
    expectEqual(observedRawEvents.count, 1, "Raw calibration event reported")
    expectEqual(observedRawEvents.first?.button, 4, "Reported button is 4")
    expectEqual(observedRawEvents.first?.type, .otherMouseDown, "Reported type is otherMouseDown")

    // 6.4 Positive control check: button 2 (Middle Click) passes through and is reported
    let b2Down = InputEngine.createMouseEvent(type: .otherMouseDown, buttonNumber: 2)!
    let resultB2 = engine.handleEvent(proxy: nil, type: .otherMouseDown, event: b2Down)
    expect(resultB2 != nil, "Positive control (middle click) passes through untouched")
    expectEqual(observedRawEvents.count, 2, "Positive control reported to raw observer")
    expectEqual(observedRawEvents.last?.button, 2, "Reported positive control button is 2 (Middle Click)")

    // 6.5 Exit calibration mode
    engine.exitCalibrationMode()
    expect(!engine.isCalibrating, "Engine exited calibration mode")

    // 6.6 After exiting calibration: normal remapping and suppression resume
    let postCalB4Down = InputEngine.createMouseEvent(type: .otherMouseDown, buttonNumber: 4)!
    let resultAfter = engine.handleEvent(proxy: nil, type: .otherMouseDown, event: postCalB4Down)
    expect(resultAfter == nil, "After calibration: button 4 down is suppressed again")
    expectEqual(postedEvents.count, 1, "Synthetic key posted again after calibration exit")

    // Clean up
    let postCalB4Up = InputEngine.createMouseEvent(type: .otherMouseUp, buttonNumber: 4)!
    _ = engine.handleEvent(proxy: nil, type: .otherMouseUp, event: postCalB4Up)
}

// MARK: - Main Runner

@main
struct TestInputEngineRunner {
    static func main() {
        print("=========================================================")
        print("Running InputEngine Test Suite (Mac Peripheral Control)")
        print("=========================================================")

        testSyntheticKeyGenerationAndTagging()
        testActionLatching()
        testSuppressionLogic()
        testPauseResumeToggling()
        testLifecycleAndCleanup()
        testCalibrationMode()

        print("\n=========================================================")
        print("Test Results: \(passedTests) passed, \(failedTests) failed out of \(totalTests) assertions")
        print("=========================================================")

        if failedTests > 0 {
            print("\u{001B}[31mTEST SUITE FAILED!\u{001B}[0m")
            exit(1)
        } else {
            print("\u{001B}[32mALL TESTS PASSED SUCCESSFULLY!\u{001B}[0m")
            exit(0)
        }
    }
}
