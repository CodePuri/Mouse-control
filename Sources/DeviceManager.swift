import Foundation
import IOKit
import IOKit.hid
import Combine

public struct LiveEventLogItem: Identifiable, Sendable {
    public let id = UUID()
    public let timestamp: Date
    public let buttonNumber: Int
    public let eventType: String
    public let actionDescription: String
    public let suppressed: Bool
    
    public init(buttonNumber: Int, eventType: String, actionDescription: String, suppressed: Bool) {
        self.timestamp = Date()
        self.buttonNumber = buttonNumber
        self.eventType = eventType
        self.actionDescription = actionDescription
        self.suppressed = suppressed
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
    
    private var timer: Timer?
    
    public init() {
        checkConnection()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkConnection()
            }
        }
    }
    
    deinit {
        timer?.invalidate()
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
    
    public func recordEvent(button: Int, type: String, actionDesc: String, suppressed: Bool) {
        let item = LiveEventLogItem(
            buttonNumber: button,
            eventType: type,
            actionDescription: actionDesc,
            suppressed: suppressed
        )
        liveEvents.insert(item, at: 0)
        if liveEvents.count > 100 {
            liveEvents.removeLast()
        }
        if type == "Down" {
            lastPressedButton = button
            // Auto clear press state after 200ms
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                if self?.lastPressedButton == button {
                    self?.lastPressedButton = nil
                }
            }
        }
    }
    
    public func clearLog() {
        liveEvents.removeAll()
    }
}
