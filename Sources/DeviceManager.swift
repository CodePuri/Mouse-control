import Foundation
import IOKit
import IOKit.hid
import Combine

public struct LiveEventLogItem: Identifiable, Sendable {
    public let id = UUID()
    public let timestamp: Date
    public let source: String              // "Quartz Global Tap" or "Synthetic Preview"
    public let buttonNumber: Int          // Quartz button number (0, 1, 2, 3, 4, ...)
    public let buttonName: String          // e.g. "Middle Click (2)"
    public let hidEquivalent: String       // e.g. "Page 0x09 Usage 0x03 (Button 3)"
    public let eventPhase: String         // "Down (Press)" vs "Up (Release)"
    public let actionDescription: String
    public let suppressed: Bool
    
    public init(
        source: String = "Quartz Global Tap",
        buttonNumber: Int,
        eventPhase: String,
        actionDescription: String,
        suppressed: Bool
    ) {
        self.timestamp = Date()
        self.source = source
        self.buttonNumber = buttonNumber
        self.eventPhase = eventPhase
        self.actionDescription = actionDescription
        self.suppressed = suppressed
        
        switch buttonNumber {
        case 0:
            self.buttonName = "Primary Left (0)"
            self.hidEquivalent = "Page 0x09 Usage 0x01 (Button 1)"
        case 1:
            self.buttonName = "Secondary Right (1)"
            self.hidEquivalent = "Page 0x09 Usage 0x02 (Button 2)"
        case 2:
            self.buttonName = "Middle Click (2)"
            self.hidEquivalent = "Page 0x09 Usage 0x03 (Button 3)"
        case 3:
            self.buttonName = "Rear Side / Back (3)"
            self.hidEquivalent = "Page 0x09 Usage 0x04 (Button 4)"
        case 4:
            self.buttonName = "Front Side / Forward (4)"
            self.hidEquivalent = "Page 0x09 Usage 0x05 (Button 5)"
        default:
            self.buttonName = "Auxiliary (\(buttonNumber))"
            let hidUsageHex = String(format: "0x%02X", buttonNumber + 1)
            self.hidEquivalent = "Page 0x09 Usage \(hidUsageHex)"
        }
    }
}

public struct ObservedHIDEvent: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let interfaceType: String   // "Mouse (0x02)", "Keyboard/Consumer (0x06)", "Vendor (0xFF01)"
    public let usagePage: UInt32
    public let usage: UInt32
    public let value: Int
    public let reportID: UInt32
    public let phase: String          // "Press (Down)" vs "Release (Up)"
    public let description: String
    public let rawHex: String?
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        interfaceType: String,
        usagePage: UInt32,
        usage: UInt32,
        value: Int,
        reportID: UInt32 = 0,
        rawHex: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.interfaceType = interfaceType
        self.usagePage = usagePage
        self.usage = usage
        self.value = value
        self.reportID = reportID
        self.rawHex = rawHex
        self.phase = value != 0 ? "Press (Down)" : "Release (Up)"
        
        switch usagePage {
        case 0x09: // Button Page
            switch usage {
            case 1: self.description = "Button 1 (Left Click)"
            case 2: self.description = "Button 2 (Right Click)"
            case 3: self.description = "Button 3 (Middle Click)"
            case 4: self.description = "Button 4 (Front Side)"
            case 5: self.description = "Button 5 (Rear Side)"
            default: self.description = "Button \(usage)"
            }
        case 0x0C: // Consumer Page
            if usage == 0x224 {
                self.description = "Consumer AC Back (0x224)"
            } else if usage == 0x225 {
                self.description = "Consumer AC Forward (0x225)"
            } else {
                self.description = "Consumer Usage 0x\(String(usage, radix: 16))"
            }
        case 0x07: // Keyboard Page
            if usage == 0x4B {
                self.description = "Key PageUp (0x4B)"
            } else if usage == 0x4E {
                self.description = "Key PageDown (0x4E)"
            } else {
                self.description = "Key ScanCode 0x\(String(usage, radix: 16))"
            }
        case 0xFF01: // Vendor Page
            self.description = "Vendor Usage 0x\(String(usage, radix: 16))"
        case 0x01: // Generic Desktop
            if usage == 0x38 {
                self.description = "Scroll Wheel"
            } else {
                self.description = "Generic Desktop 0x\(String(usage, radix: 16))"
            }
        default:
            self.description = "Page 0x\(String(usagePage, radix: 16)) Usage 0x\(String(usage, radix: 16))"
        }
    }
    
    public var isConsumerBackOrForward: Bool {
        usagePage == 0x0C && (usage == 0x224 || usage == 0x225)
    }
    
    public var isMouseButton: Bool {
        usagePage == 0x09
    }
    
    public var isPositiveControl: Bool {
        // Strictly Middle Click (Button 3 on Page 0x09) only.
        // Primary left click (usage 1) is never accepted as positive control.
        usagePage == 0x09 && usage == 0x03
    }
}

public enum CalibrationSessionState: Equatable {
    case idle
    case step1_positiveControl // Listening for Middle Click (Button 2) or any click
    case step2_frontButton     // Listening for Front Side Button
    case step3_rearButton      // Listening for Rear Side Button
    case completed(frontBtn: Int, rearBtn: Int)
    case timedOut(positiveControlPassed: Bool, frontSeen: Bool, rearSeen: Bool)
    
    public var title: String {
        switch self {
        case .idle:
            return "Calibration Idle"
        case .step1_positiveControl:
            return "Step 1/3: Pipeline Health Check"
        case .step2_frontButton:
            return "Step 2/3: Front Side Button"
        case .step3_rearButton:
            return "Step 3/3: Rear Side Button"
        case .completed:
            return "Calibration Complete"
        case .timedOut:
            return "Calibration Timed Out (30s)"
        }
    }
    
    public var instruction: String {
        switch self {
        case .idle:
            return "Click 'Start Guided Calibration' to test the event pipeline and attribute physical side buttons."
        case .step1_positiveControl:
            return "Positive Control Check: Click your Middle Button (Scroll Wheel Click) to verify event capture."
        case .step2_frontButton:
            return "Press and briefly hold the Front Side Button (closer to the scroll wheel), then release."
        case .step3_rearButton:
            return "Press and briefly hold the Rear Side Button (closer to your palm), then release."
        case .completed(let front, let rear):
            return "Verified Physical Buttons: Front Button is Quartz \(front), Rear Button is Quartz \(rear)."
        case .timedOut(let pos, let front, let rear):
            if !pos {
                return "No mouse events were detected. Check \(PermissionManager.permissionSectionName) permission in System Settings."
            } else if !front && !rear {
                return "Pipeline is healthy (positive control passed), but no side button events were received across the 2.4GHz receiver."
            } else {
                return "Partial capture: received some events before timeout."
            }
        }
    }
}

@MainActor
public final class DeviceManager: ObservableObject {
    @Published public var isReceiverConnected: Bool = false
    @Published public var deviceName: String = "Kreo Chimera V2"
    @Published public var transportType: String = "USB Wireless (2.4 GHz Receiver)"
    @Published public var vendorIdHex: String = "0x248a"
    @Published public var productIdHex: String = "0x5b4a"
    @Published public var liveEvents: [LiveEventLogItem] = []
    @Published public var lastPressedButton: Int? = nil
    
    // Calibration State
    @Published public var calibrationState: CalibrationSessionState = .idle
    @Published public var calibrationSecondsRemaining: Int = 30
    @Published public var positiveControlObservedButton: Int? = nil
    @Published public var detectedFrontButton: Int? = nil
    @Published public var detectedRearButton: Int? = nil
    
    // Multi-Interface HID Telemetry
    @Published public var observedHIDEvents: [ObservedHIDEvent] = []
    @Published public var lastObservedHIDEvent: ObservedHIDEvent? = nil
    @Published public var rawReportCount: Int = 0
    @Published public var lastRawReportHex: String = ""
    @Published public var isMouseInterfaceActive: Bool = false
    @Published public var isConsumerInterfaceActive: Bool = false
    @Published public var isVendorInterfaceActive: Bool = false
    @Published public var positiveControlObservedEvent: ObservedHIDEvent? = nil
    @Published public var detectedFrontHIDEvent: ObservedHIDEvent? = nil
    @Published public var detectedRearHIDEvent: ObservedHIDEvent? = nil
    
    /// Callback invoked when a mapped hardware button event is received via IOHID.
    /// Passes button number (e.g. 4 for front, 3 for rear) and isDown boolean.
    public var onHardwareButtonAction: ((_ buttonNumber: Int, _ isDown: Bool) -> Void)?
    
    private var connectionTimer: Timer?
    private var calibrationTimer: Timer?
    private var hidManager: IOHIDManager?
    private var reportBuffers: [UnsafeMutablePointer<UInt8>] = []
    
    public init() {
        startMultiInterfaceMonitoring()
        checkConnection()
        connectionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkConnection()
            }
        }
    }
    
    deinit {
        connectionTimer?.invalidate()
        calibrationTimer?.invalidate()
        if let mgr = hidManager {
            IOHIDManagerClose(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
            IOHIDManagerUnscheduleFromRunLoop(mgr, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        }
        for buf in reportBuffers {
            buf.deallocate()
        }
    }
    
    public func startMultiInterfaceMonitoring() {
        stopMultiInterfaceMonitoring()
        
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matchDict: [String: Any] = [
            kIOHIDVendorIDKey as String: 0x248a,
            kIOHIDProductIDKey as String: 0x5b4a
        ]
        IOHIDManagerSetDeviceMatching(manager, matchDict as CFDictionary)
        
        let context = Unmanaged.passUnretained(self).toOpaque()
        
        IOHIDManagerRegisterInputValueCallback(manager, { context, result, sender, value in
            guard let context = context else { return }
            let dm = Unmanaged<DeviceManager>.fromOpaque(context).takeUnretainedValue()
            let elem = IOHIDValueGetElement(value)
            let page = IOHIDElementGetUsagePage(elem)
            let usage = IOHIDElementGetUsage(elem)
            let intVal = IOHIDValueGetIntegerValue(value)
            
            // Filter out continuous mouse X/Y movement to prevent log flooding
            if page == 0x01 && (usage == 0x30 || usage == 0x31) { return }
            
            let dev = IOHIDElementGetDevice(elem)
            let primaryPage = IOHIDDeviceGetProperty(dev, kIOHIDPrimaryUsagePageKey as CFString) as? Int ?? 0
            let primaryUsage = IOHIDDeviceGetProperty(dev, kIOHIDPrimaryUsageKey as CFString) as? Int ?? 0
            
            let interfaceName: String
            if primaryPage == 0x01 && primaryUsage == 0x02 {
                interfaceName = "Mouse (0x02)"
            } else if primaryPage == 0x01 && primaryUsage == 0x06 {
                interfaceName = "Keyboard/Consumer (0x06)"
            } else if primaryPage == 0xFF01 {
                interfaceName = "Vendor (0xFF01)"
            } else {
                interfaceName = "Interface 0x\(String(primaryPage, radix: 16)):0x\(String(primaryUsage, radix: 16))"
            }
            
            DispatchQueue.main.async {
                dm.handleRawHIDValue(interfaceName: interfaceName, page: page, usage: usage, intVal: intVal)
            }
        }, context)
        
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        let openRes = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if openRes == kIOReturnSuccess {
            self.hidManager = manager
            
            if let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> {
                for dev in devices {
                    let page = IOHIDDeviceGetProperty(dev, kIOHIDPrimaryUsagePageKey as CFString) as? Int ?? 0
                    let usage = IOHIDDeviceGetProperty(dev, kIOHIDPrimaryUsageKey as CFString) as? Int ?? 0
                    
                    if page == 0x01 && usage == 0x02 { isMouseInterfaceActive = true }
                    if page == 0x01 && usage == 0x06 { isConsumerInterfaceActive = true }
                    if page == 0xFF01 { isVendorInterfaceActive = true }
                    
                    let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
                    reportBuffers.append(buf)
                    IOHIDDeviceRegisterInputReportCallback(dev, buf, 64, { context, result, sender, type, reportID, report, reportLength in
                        guard let context = context else { return }
                        let dm = Unmanaged<DeviceManager>.fromOpaque(context).takeUnretainedValue()
                        let bytes = Array(UnsafeBufferPointer(start: report, count: reportLength))
                        let hex = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
                        
                        DispatchQueue.main.async {
                            dm.handleRawReport(reportID: reportID, bytesHex: hex)
                        }
                    }, context)
                }
            }
        }
    }
    
    public func stopMultiInterfaceMonitoring() {
        if let mgr = hidManager {
            IOHIDManagerClose(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
            IOHIDManagerUnscheduleFromRunLoop(mgr, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
            hidManager = nil
        }
        for buf in reportBuffers {
            buf.deallocate()
        }
        reportBuffers.removeAll()
    }
    
    public func handleRawReport(reportID: UInt32, bytesHex: String) {
        rawReportCount += 1
        lastRawReportHex = "ID 0x\(String(reportID, radix: 16)): [\(bytesHex)]"
    }
    
    public func handleRawHIDValue(interfaceName: String, page: UInt32, usage: UInt32, intVal: Int) {
        let ev = ObservedHIDEvent(
            interfaceType: interfaceName,
            usagePage: page,
            usage: usage,
            value: intVal
        )
        observedHIDEvents.insert(ev, at: 0)
        if observedHIDEvents.count > 50 {
            observedHIDEvents.removeLast()
        }
        lastObservedHIDEvent = ev
        
        // Map to button press visual and dispatch action
        var mappedButton: Int? = nil
        if page == 0x09 {
            switch usage {
            case 1: mappedButton = 0
            case 2: mappedButton = 1
            case 3: mappedButton = 2
            case 4: mappedButton = 4 // Front side button
            case 5: mappedButton = 3 // Rear side button
            default: mappedButton = Int(usage)
            }
        } else if page == 0x0C {
            if usage == 0x224 {
                mappedButton = 3 // AC Back -> Rear side button
            } else if usage == 0x225 {
                mappedButton = 4 // AC Forward -> Front side button
            }
        }
        
        if let btn = mappedButton {
            let isDown = (intVal != 0)
            if isDown {
                lastPressedButton = btn
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    if self?.lastPressedButton == btn {
                        self?.lastPressedButton = nil
                    }
                }
            }
            // Trigger action for side buttons during normal operation
            if (btn == 3 || btn == 4) && calibrationState == .idle {
                onHardwareButtonAction?(btn, isDown)
            }
        }
        
        // Feed into calibration test if running
        switch calibrationState {
        case .step1_positiveControl:
            if ev.isPositiveControl && intVal != 0 {
                positiveControlObservedEvent = ev
                positiveControlObservedButton = 2
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self, self.calibrationState == .step1_positiveControl else { return }
                    self.calibrationState = .step2_frontButton
                }
            }
        case .step2_frontButton:
            // Strictly require an auxiliary / side button. Rejects Left (0), Right (1), Middle (2), and Scroll.
            let isSideButton = (ev.usagePage == 0x0C && (ev.usage == 0x224 || ev.usage == 0x225)) ||
                               (ev.usagePage == 0x09 && ev.usage >= 4)
            guard isSideButton else { break }
            
            if intVal != 0 {
                detectedFrontHIDEvent = ev
                if ev.usagePage == 0x09 {
                    detectedFrontButton = (ev.usage == 5) ? 3 : 4
                } else if ev.usagePage == 0x0C {
                    detectedFrontButton = (ev.usage == 0x224) ? 3 : 4
                }
            } else if intVal == 0 && detectedFrontHIDEvent != nil && detectedFrontButton != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self, self.calibrationState == .step2_frontButton else { return }
                    self.calibrationState = .step3_rearButton
                }
            }
        case .step3_rearButton:
            // Strictly require an auxiliary / side button.
            let isSideButton = (ev.usagePage == 0x0C && (ev.usage == 0x224 || ev.usage == 0x225)) ||
                               (ev.usagePage == 0x09 && ev.usage >= 4)
            guard isSideButton else { break }
            
            let btn: Int
            if ev.usagePage == 0x09 {
                btn = (ev.usage == 4) ? 4 : 3
            } else if ev.usagePage == 0x0C {
                btn = (ev.usage == 0x225) ? 4 : 3
            } else {
                btn = Int(ev.usage)
            }
            
            // Must NOT accept the identical button as front button
            guard let front = detectedFrontButton, front >= 3, btn != front else { break }
            
            if intVal != 0 {
                detectedRearHIDEvent = ev
                detectedRearButton = btn
            } else if intVal == 0 && detectedRearHIDEvent != nil && detectedRearButton == btn {
                calibrationState = .completed(frontBtn: front, rearBtn: btn)
            }
        default:
            break
        }
    }
    
    public func checkConnection() {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matchDict: [String: Any] = [
            kIOHIDVendorIDKey as String: 0x248a,
            kIOHIDProductIDKey as String: 0x5b4a
        ]
        IOHIDManagerSetDeviceMatching(manager, matchDict as CFDictionary)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        
        if let deviceSet = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>, !deviceSet.isEmpty {
            self.isReceiverConnected = true
        } else {
            self.isReceiverConnected = false
        }
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }
    
    public func recordEvent(
        source: String = "Quartz Global Tap",
        button: Int,
        phase: String,
        actionDesc: String,
        suppressed: Bool
    ) {
        let item = LiveEventLogItem(
            source: source,
            buttonNumber: button,
            eventPhase: phase,
            actionDescription: actionDesc,
            suppressed: suppressed
        )
        liveEvents.insert(item, at: 0)
        if liveEvents.count > 100 {
            liveEvents.removeLast()
        }
        if phase.contains("Down") {
            lastPressedButton = button
            // Auto clear press visual after 300ms
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                if self?.lastPressedButton == button {
                    self?.lastPressedButton = nil
                }
            }
        }
    }
    
    public func clearLog() {
        liveEvents.removeAll()
    }
    
    // MARK: - Guided Calibration Methods
    
    public func startCalibration(engine: InputEngine) {
        calibrationTimer?.invalidate()
        calibrationSecondsRemaining = 30
        positiveControlObservedButton = nil
        detectedFrontButton = nil
        detectedRearButton = nil
        positiveControlObservedEvent = nil
        detectedFrontHIDEvent = nil
        detectedRearHIDEvent = nil
        calibrationState = .step1_positiveControl
        engine.enterCalibrationMode()
        
        calibrationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.calibrationSecondsRemaining > 1 {
                    self.calibrationSecondsRemaining -= 1
                } else {
                    self.calibrationSecondsRemaining = 0
                    t.invalidate()
                    let posPassed = (self.positiveControlObservedButton == 2)
                    let frontSeen = (self.detectedFrontButton != nil && self.detectedFrontButton! >= 3)
                    let rearSeen = (self.detectedRearButton != nil && self.detectedRearButton! >= 3 && self.detectedRearButton != self.detectedFrontButton)
                    self.calibrationState = .timedOut(
                        positiveControlPassed: posPassed,
                        frontSeen: frontSeen,
                        rearSeen: rearSeen
                    )
                    self.stopCalibration(engine: engine)
                }
            }
        }
    }
    
    public func stopCalibration(engine: InputEngine) {
        calibrationTimer?.invalidate()
        calibrationTimer = nil
        engine.exitCalibrationMode()
    }
    
    public func cancelCalibration(engine: InputEngine) {
        stopCalibration(engine: engine)
        calibrationState = .idle
    }
    
    public func handleCalibrationEvent(button: Int, type: String, engine: InputEngine) {
        recordEvent(
            source: "Quartz Global Tap",
            button: button,
            phase: type,
            actionDesc: "Calibration Observation",
            suppressed: false
        )
        
        switch calibrationState {
        case .step1_positiveControl:
            // Strictly require Middle Click (Button 2) for positive control.
            // Left Click (0) and Right Click (1) are strictly rejected.
            guard button == 2 else { return }
            if type.contains("Down") {
                positiveControlObservedButton = button
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self, self.calibrationState == .step1_positiveControl else { return }
                    self.calibrationState = .step2_frontButton
                }
            }
        case .step2_frontButton:
            // Reject primary (0), secondary (1), and middle (2) mouse clicks
            guard button >= 3 else { return }
            if type.contains("Down") {
                detectedFrontButton = button
            } else if type.contains("Up") && detectedFrontButton == button {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self, self.calibrationState == .step2_frontButton else { return }
                    self.calibrationState = .step3_rearButton
                }
            }
        case .step3_rearButton:
            // Reject primary (0), secondary (1), and middle (2) mouse clicks
            guard button >= 3 else { return }
            // Must have a valid front button and rear button MUST be distinct from front button
            guard let front = detectedFrontButton, front >= 3, button != front else { return }
            if type.contains("Down") {
                detectedRearButton = button
            } else if type.contains("Up") && detectedRearButton == button {
                calibrationState = .completed(frontBtn: front, rearBtn: button)
                stopCalibration(engine: engine)
            }
        default:
            break
        }
    }
}
