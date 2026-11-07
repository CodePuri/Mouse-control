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
            return "Positive Control Check: Click your Middle Button (Scroll Wheel Click) or Left Button to verify event capture."
        case .step2_frontButton:
            return "Press and briefly hold the Front Side Button (closer to the scroll wheel), then release."
        case .step3_rearButton:
            return "Press and briefly hold the Rear Side Button (closer to your palm), then release."
        case .completed(let front, let rear):
            return "Verified Physical Buttons: Front Button is Quartz \(front), Rear Button is Quartz \(rear)."
        case .timedOut(let pos, let front, let rear):
            if !pos {
                return "No mouse events were detected. Check Accessibility permission in System Settings."
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
    
    private var connectionTimer: Timer?
    private var calibrationTimer: Timer?
    
    public init() {
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
                    let posPassed = (self.positiveControlObservedButton != nil)
                    let frontSeen = (self.detectedFrontButton != nil)
                    let rearSeen = (self.detectedRearButton != nil)
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
            if type.contains("Down") {
                positiveControlObservedButton = button
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self, self.calibrationState == .step1_positiveControl else { return }
                    self.calibrationState = .step2_frontButton
                }
            }
        case .step2_frontButton:
            if type.contains("Down") {
                detectedFrontButton = button
            } else if type.contains("Up") && detectedFrontButton == button {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self, self.calibrationState == .step2_frontButton else { return }
                    self.calibrationState = .step3_rearButton
                }
            }
        case .step3_rearButton:
            if type.contains("Down") {
                detectedRearButton = button
            } else if type.contains("Up") && detectedRearButton == button {
                let front = detectedFrontButton ?? 4
                let rear = detectedRearButton ?? 3
                calibrationState = .completed(frontBtn: front, rearBtn: rear)
                stopCalibration(engine: engine)
            }
        default:
            break
        }
    }
}
