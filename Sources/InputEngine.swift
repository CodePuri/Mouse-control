import Foundation
import CoreGraphics
import os.log

/// Action triggered by a mouse button event.
public enum InputAction: Equatable, Hashable, Sendable, CustomStringConvertible {
    case wisprFlowPTT(keyCode: CGKeyCode = 61)
    case shortcut(keyCode: CGKeyCode, flags: CGEventFlags)
    case undo
    case redo
    case passthrough
    case disabled

    public var description: String {
        switch self {
        case .wisprFlowPTT(let keyCode):
            return "Wispr Flow PTT (keyCode: \(keyCode))"
        case .shortcut(let keyCode, let flags):
            return "Shortcut (keyCode: \(keyCode), flags: 0x\(String(flags.rawValue, radix: 16)))"
        case .undo:
            return "Undo (⌘Z)"
        case .redo:
            return "Redo (⇧⌘Z)"
        case .passthrough:
            return "Passthrough"
        case .disabled:
            return "Disabled"
        }
    }

    public var isSuppressed: Bool {
        switch self {
        case .passthrough:
            return false
        case .wisprFlowPTT, .shortcut, .undo, .redo, .disabled:
            return true
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .wisprFlowPTT(let keyCode):
            hasher.combine(0)
            hasher.combine(keyCode)
        case .shortcut(let keyCode, let flags):
            hasher.combine(1)
            hasher.combine(keyCode)
            hasher.combine(flags.rawValue)
        case .undo:
            hasher.combine(2)
        case .redo:
            hasher.combine(3)
        case .passthrough:
            hasher.combine(4)
        case .disabled:
            hasher.combine(5)
        }
    }

    public static func == (lhs: InputAction, rhs: InputAction) -> Bool {
        switch (lhs, rhs) {
        case let (.wisprFlowPTT(k1), .wisprFlowPTT(k2)):
            return k1 == k2
        case let (.shortcut(k1, f1), .shortcut(k2, f2)):
            return k1 == k2 && f1.rawValue == f2.rawValue
        case (.undo, .undo), (.redo, .redo), (.passthrough, .passthrough), (.disabled, .disabled):
            return true
        default:
            return false
        }
    }
}

/// Native macOS input remapping engine using CGEventTap.
///
/// Captures `otherMouseDown` and `otherMouseUp` events (e.g. side buttons 3, 4, 5+),
/// suppresses default browser navigation (Back/Forward), and generates synthetic
/// key events with loop-prevention tagging.
public final class InputEngine: @unchecked Sendable {
    /// Magic marker value tagged onto synthetic events to prevent infinite recursive loops.
    /// "MCTR" in ASCII: 0x4D435452
    public static let magicEventMarker: Int64 = 0x4D435452

    public typealias EventPoster = (CGEvent, CGEventTapLocation) -> Void

    private let lock = NSLock()
    private var _isPaused: Bool = false
    private var _isRunning: Bool = false
    private var _isCalibrating: Bool = false
    private var mappings: [Int: InputAction] = [:]
    private var latchedActions: [Int: InputAction] = [:]

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var backgroundThread: Thread?
    private var tapRunLoop: CFRunLoop?
    private var isStopping: Bool = false

    /// Custom poster for dispatching synthetic events (defaults to `event.post(tap:)`).
    public var eventPoster: EventPoster

    /// Optional hook called whenever a synthetic event is generated and posted.
    public var onSyntheticEventPosted: ((CGEvent) -> Void)?

    /// Optional hook called whenever a mouse button event is handled by the engine.
    public var onButtonEventHandled: ((Int, CGEventType, InputAction?) -> Void)?

    /// Optional hook called for every observed raw mouse event during calibration mode.
    public var onRawCalibrationEvent: ((Int, CGEventType, CGEvent) -> Void)?

    /// Whether the remapping service is currently paused.
    public var isPaused: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isPaused
    }

    /// Whether the background event tap is active and running.
    public var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isRunning
    }

    /// Whether calibration observation mode is active (transformations suspended).
    public var isCalibrating: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isCalibrating
    }

    public func enterCalibrationMode() {
        lock.lock()
        _isCalibrating = true
        lock.unlock()
    }

    public func exitCalibrationMode() {
        lock.lock()
        _isCalibrating = false
        lock.unlock()
    }

    public init(mappings: [Int: InputAction] = [:], isPaused: Bool = false) {
        // Immediate safety: filter out any attempt to map primary/secondary/middle buttons
        self.mappings = mappings.filter { $0.key >= 3 }
        self._isPaused = isPaused
        self.eventPoster = { event, location in
            event.post(tap: location)
        }
    }

    deinit {
        stop()
    }

    // MARK: - Configuration

    public func setAction(_ action: InputAction, forButton buttonNumber: Int) {
        // Immediate safety barrier: NEVER allow buttons 0, 1, or 2 (Left, Right, Middle) to be remapped
        guard buttonNumber >= 3 else { return }
        lock.lock()
        defer { lock.unlock() }
        mappings[buttonNumber] = action
    }

    public func action(forButton buttonNumber: Int) -> InputAction? {
        lock.lock()
        defer { lock.unlock() }
        return mappings[buttonNumber]
    }

    public func removeAction(forButton buttonNumber: Int) {
        lock.lock()
        defer { lock.unlock() }
        mappings.removeValue(forKey: buttonNumber)
    }

    public func setMappings(_ newMappings: [Int: InputAction]) {
        lock.lock()
        defer { lock.unlock() }
        self.mappings = newMappings.filter { $0.key >= 3 }
    }

    public func currentMappings() -> [Int: InputAction] {
        lock.lock()
        defer { lock.unlock() }
        return mappings
    }

    public func currentLatchedActions() -> [Int: InputAction] {
        lock.lock()
        defer { lock.unlock() }
        return latchedActions
    }

    // MARK: - Pause / Resume

    public func pause() {
        lock.lock()
        _isPaused = true
        lock.unlock()
    }

    public func resume() {
        lock.lock()
        _isPaused = false
        lock.unlock()
    }

    @discardableResult
    public func togglePause() -> Bool {
        lock.lock()
        _isPaused.toggle()
        let state = _isPaused
        lock.unlock()
        return state
    }

    // MARK: - Lifecycle

    /// Starts the CGEventTap on a dedicated background thread with its own CFRunLoop.
    /// Returns `true` if the event tap was created and started successfully.
    @discardableResult
    public func start() -> Bool {
        lock.lock()
        if _isRunning {
            lock.unlock()
            return true
        }

        let mask: CGEventMask = (1 << CGEventType.leftMouseDown.rawValue) |
                               (1 << CGEventType.leftMouseUp.rawValue) |
                               (1 << CGEventType.rightMouseDown.rawValue) |
                               (1 << CGEventType.rightMouseUp.rawValue) |
                               (1 << CGEventType.otherMouseDown.rawValue) |
                               (1 << CGEventType.otherMouseUp.rawValue)
        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let engine = Unmanaged<InputEngine>.fromOpaque(refcon).takeUnretainedValue()
                return engine.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: refcon
        ) else {
            lock.unlock()
            return false
        }

        self.eventTap = tap
        self.isStopping = false
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        let startSemaphore = DispatchSemaphore(value: 0)

        let thread = Thread { [weak self] in
            let currentRunLoop = CFRunLoopGetCurrent()

            guard let initialSelf = self else { return }
            initialSelf.lock.lock()
            initialSelf.tapRunLoop = currentRunLoop
            if let source = initialSelf.runLoopSource {
                CFRunLoopAddSource(currentRunLoop, source, .commonModes)
            }
            if let tap = initialSelf.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            initialSelf._isRunning = true
            initialSelf.lock.unlock()

            startSemaphore.signal()

            while true {
                guard let strongSelf = self else { break }
                strongSelf.lock.lock()
                let shouldStop = strongSelf.isStopping
                strongSelf.lock.unlock()
                if shouldStop { break }

                CFRunLoopRunInMode(.defaultMode, 0.1, true)
            }

            if let strongSelf = self {
                strongSelf.lock.lock()
                if let source = strongSelf.runLoopSource {
                    CFRunLoopRemoveSource(currentRunLoop, source, .commonModes)
                }
                if let tap = strongSelf.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: false)
                }
                strongSelf._isRunning = false
                strongSelf.lock.unlock()
            }
        }

        thread.name = "com.codepuri.mousecontrol.inputengine"
        self.backgroundThread = thread
        lock.unlock()

        thread.start()
        _ = startSemaphore.wait(timeout: .now() + 2.0)
        return true
    }

    /// Stops the background event tap and terminates its background run loop.
    /// Any keys currently latched in the down state are cleanly released.
    public func stop() {
        lock.lock()

        // Cleanly release all latched keys
        for (_, action) in latchedActions {
            releaseLatchedKey(action)
        }
        latchedActions.removeAll()

        guard _isRunning || backgroundThread != nil else {
            lock.unlock()
            return
        }

        isStopping = true

        let runLoopToStop = tapRunLoop
        let threadToJoin = backgroundThread

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        lock.unlock()

        if let rl = runLoopToStop {
            CFRunLoopStop(rl)
        }

        var attempts = 0
        while threadToJoin?.isFinished == false && attempts < 20 {
            Thread.sleep(forTimeInterval: 0.05)
            attempts += 1
        }

        lock.lock()
        self.eventTap = nil
        self.runLoopSource = nil
        self.backgroundThread = nil
        self.tapRunLoop = nil
        self._isRunning = false
        self.isStopping = false
        lock.unlock()
    }

    // MARK: - Event Handling Core

    /// Core event tap callback handler.
    /// Handles event suppression, action latching, and synthetic key generation.
    @discardableResult
    public func handleEvent(proxy: CGEventTapProxy?, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Re-enable tap if disabled by system timeout
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            lock.lock()
            if let tap = self.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            lock.unlock()
            return Unmanaged.passUnretained(event)
        }

        // Loop prevention: ignore any incoming event tagged with our marker
        let marker = event.getIntegerValueField(.eventSourceUserData)
        if marker == InputEngine.magicEventMarker {
            return Unmanaged.passUnretained(event)
        }

        // Check if calibration observation mode is active
        lock.lock()
        let calibrating = self._isCalibrating
        lock.unlock()

        if calibrating {
            let buttonNumber = Int(event.getIntegerValueField(.mouseEventButtonNumber))
            onRawCalibrationEvent?(buttonNumber, type, event)
            // Never suppress or transform events during calibration mode
            return Unmanaged.passUnretained(event)
        }

        // Only handle otherMouseDown and otherMouseUp during normal remapping
        guard type == .otherMouseDown || type == .otherMouseUp else {
            return Unmanaged.passUnretained(event)
        }

        let buttonNumber = Int(event.getIntegerValueField(.mouseEventButtonNumber))

        // ABSOLUTE SAFETY BARRIER:
        // Buttons 0 (Left), 1 (Right), and 2 (Middle) must NEVER be suppressed or remapped.
        guard buttonNumber >= 3 else {
            return Unmanaged.passUnretained(event)
        }

        lock.lock()
        let paused = self._isPaused

        if type == .otherMouseDown {
            if paused {
                lock.unlock()
                return Unmanaged.passUnretained(event)
            }

            guard let action = self.mappings[buttonNumber], action != .passthrough else {
                lock.unlock()
                return Unmanaged.passUnretained(event)
            }

            // Latch action on button down
            self.latchedActions[buttonNumber] = action
            lock.unlock()

            // Dispatch down event based on action
            switch action {
            case .disabled:
                break
            case .wisprFlowPTT(let keyCode):
                if let synth = InputEngine.createSyntheticKeyEvent(keyCode: keyCode, isDown: true) {
                    postSyntheticEvent(synth)
                }
            case .shortcut(let keyCode, let flags):
                if let synth = InputEngine.createSyntheticKeyEvent(keyCode: keyCode, flags: flags, isDown: true) {
                    postSyntheticEvent(synth)
                }
            case .undo:
                if let synth = InputEngine.createSyntheticKeyEvent(keyCode: 6, flags: .maskCommand, isDown: true) {
                    postSyntheticEvent(synth)
                }
            case .redo:
                if let synth = InputEngine.createSyntheticKeyEvent(keyCode: 6, flags: [.maskCommand, .maskShift], isDown: true) {
                    postSyntheticEvent(synth)
                }
            case .passthrough:
                break
            }

            onButtonEventHandled?(buttonNumber, type, action)
            // Suppress event
            return nil
        }

        if type == .otherMouseUp {
            // Check if there is a latched action from button down
            guard let latched = self.latchedActions.removeValue(forKey: buttonNumber) else {
                lock.unlock()
                return Unmanaged.passUnretained(event)
            }
            lock.unlock()

            // Dispatch matching release based on the latched action
            switch latched {
            case .disabled:
                break
            case .wisprFlowPTT(let keyCode):
                if let synth = InputEngine.createSyntheticKeyEvent(keyCode: keyCode, isDown: false) {
                    postSyntheticEvent(synth)
                }
            case .shortcut(let keyCode, let flags):
                if let synth = InputEngine.createSyntheticKeyEvent(keyCode: keyCode, flags: flags, isDown: false) {
                    postSyntheticEvent(synth)
                }
            case .undo:
                if let synth = InputEngine.createSyntheticKeyEvent(keyCode: 6, flags: .maskCommand, isDown: false) {
                    postSyntheticEvent(synth)
                }
            case .redo:
                if let synth = InputEngine.createSyntheticKeyEvent(keyCode: 6, flags: [.maskCommand, .maskShift], isDown: false) {
                    postSyntheticEvent(synth)
                }
            case .passthrough:
                return Unmanaged.passUnretained(event)
            }

            onButtonEventHandled?(buttonNumber, type, latched)
            // Suppress event
            return nil
        }

        lock.unlock()
        return Unmanaged.passUnretained(event)
    }

    /// Programmatically triggers an assigned action for a given button number.
    /// Used by multi-interface IOHID telemetry (e.g. Consumer controls AC Back 0x224 / AC Forward 0x225
    /// or raw hardware button reports) so actions fire even if Quartz CGEventTap does not receive them.
    public func triggerAction(forButton buttonNumber: Int, isDown: Bool) {
        lock.lock()
        if _isPaused || _isCalibrating {
            lock.unlock()
            return
        }

        if isDown {
            guard let action = self.mappings[buttonNumber], action != .passthrough else {
                lock.unlock()
                return
            }
            self.latchedActions[buttonNumber] = action
            lock.unlock()

            switch action {
            case .disabled:
                break
            case .wisprFlowPTT(let keyCode):
                if let synth = InputEngine.createSyntheticKeyEvent(keyCode: keyCode, isDown: true) {
                    postSyntheticEvent(synth)
                }
            case .shortcut(let keyCode, let flags):
                if let synth = InputEngine.createSyntheticKeyEvent(keyCode: keyCode, flags: flags, isDown: true) {
                    postSyntheticEvent(synth)
                }
            case .undo:
                if let synth = InputEngine.createSyntheticKeyEvent(keyCode: 6, flags: .maskCommand, isDown: true) {
                    postSyntheticEvent(synth)
                }
            case .redo:
                if let synth = InputEngine.createSyntheticKeyEvent(keyCode: 6, flags: [.maskCommand, .maskShift], isDown: true) {
                    postSyntheticEvent(synth)
                }
            case .passthrough:
                break
            }
            onButtonEventHandled?(buttonNumber, .otherMouseDown, action)
        } else {
            guard let latched = self.latchedActions.removeValue(forKey: buttonNumber) else {
                lock.unlock()
                return
            }
            lock.unlock()
            releaseLatchedKey(latched)
            onButtonEventHandled?(buttonNumber, .otherMouseUp, latched)
        }
    }

    /// Simulate an action (press and immediate release) for testing or user preview.
    public func simulateAction(_ action: InputAction) {
        switch action {
        case .disabled, .passthrough:
            break
        case .wisprFlowPTT(let keyCode):
            if let down = InputEngine.createSyntheticKeyEvent(keyCode: keyCode, isDown: true) {
                postSyntheticEvent(down)
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { [weak self] in
                if let up = InputEngine.createSyntheticKeyEvent(keyCode: keyCode, isDown: false) {
                    self?.postSyntheticEvent(up)
                }
            }
        case .shortcut(let keyCode, let flags):
            if let down = InputEngine.createSyntheticKeyEvent(keyCode: keyCode, flags: flags, isDown: true) {
                postSyntheticEvent(down)
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) { [weak self] in
                if let up = InputEngine.createSyntheticKeyEvent(keyCode: keyCode, flags: flags, isDown: false) {
                    self?.postSyntheticEvent(up)
                }
            }
        case .undo:
            if let down = InputEngine.createSyntheticKeyEvent(keyCode: 6, flags: .maskCommand, isDown: true) {
                postSyntheticEvent(down)
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) { [weak self] in
                if let up = InputEngine.createSyntheticKeyEvent(keyCode: 6, flags: .maskCommand, isDown: false) {
                    self?.postSyntheticEvent(up)
                }
            }
        case .redo:
            if let down = InputEngine.createSyntheticKeyEvent(keyCode: 6, flags: [.maskCommand, .maskShift], isDown: true) {
                postSyntheticEvent(down)
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) { [weak self] in
                if let up = InputEngine.createSyntheticKeyEvent(keyCode: 6, flags: [.maskCommand, .maskShift], isDown: false) {
                    self?.postSyntheticEvent(up)
                }
            }
        }
    }

    // MARK: - Synthetic Key Helpers

    public static func createSyntheticKeyEvent(keyCode: CGKeyCode, flags: CGEventFlags? = nil, isDown: Bool) -> CGEvent? {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: isDown) else {
            return nil
        }
        if let flags = flags {
            event.flags = flags
        }
        event.setIntegerValueField(.eventSourceUserData, value: magicEventMarker)
        return event
    }

    public static func createMouseEvent(type: CGEventType, buttonNumber: Int, marker: Int64? = nil) -> CGEvent? {
        let mouseButton: CGMouseButton
        switch buttonNumber {
        case 0: mouseButton = .left
        case 1: mouseButton = .right
        default: mouseButton = .center
        }
        guard let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: .zero, mouseButton: mouseButton) else {
            return nil
        }
        event.setIntegerValueField(.mouseEventButtonNumber, value: Int64(buttonNumber))
        if let marker = marker {
            event.setIntegerValueField(.eventSourceUserData, value: marker)
        }
        return event
    }

    private func postSyntheticEvent(_ event: CGEvent) {
        onSyntheticEventPosted?(event)
        eventPoster(event, .cghidEventTap)
    }

    private func releaseLatchedKey(_ action: InputAction) {
        switch action {
        case .disabled, .passthrough:
            break
        case .wisprFlowPTT(let keyCode):
            if let synth = InputEngine.createSyntheticKeyEvent(keyCode: keyCode, isDown: false) {
                postSyntheticEvent(synth)
            }
        case .shortcut(let keyCode, let flags):
            if let synth = InputEngine.createSyntheticKeyEvent(keyCode: keyCode, flags: flags, isDown: false) {
                postSyntheticEvent(synth)
            }
        case .undo:
            if let synth = InputEngine.createSyntheticKeyEvent(keyCode: 6, flags: .maskCommand, isDown: false) {
                postSyntheticEvent(synth)
            }
        case .redo:
            if let synth = InputEngine.createSyntheticKeyEvent(keyCode: 6, flags: [.maskCommand, .maskShift], isDown: false) {
                postSyntheticEvent(synth)
            }
        }
    }
}
