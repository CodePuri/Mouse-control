import Foundation
import CoreGraphics
import Combine

/// Specific physical button on the mouse
public enum PhysicalButton: Int, Codable, CaseIterable, Identifiable {
    case rearSide = 3     // Standard Mac otherMouse button 3 (Back)
    case frontSide = 4    // Standard Mac otherMouse button 4 (Forward)
    case middle = 2       // Scroll wheel click
    
    public var id: Int { rawValue }
    
    public var displayName: String {
        switch self {
        case .frontSide: return "Front Side Button"
        case .rearSide: return "Rear Side Button"
        case .middle: return "Middle Click"
        }
    }
    
    public var physicalDescription: String {
        switch self {
        case .frontSide: return "Thumb Button 4 (Closer to wheel)"
        case .rearSide: return "Thumb Button 3 (Closer to palm)"
        case .middle: return "Scroll Wheel Click (Button 2)"
        }
    }
}

/// Serializable representation of an input action
public struct StoredAction: Codable, Equatable, Hashable {
    public enum ActionType: String, Codable {
        case wisprFlowPTT
        case shortcut
        case undo
        case redo
        case copy
        case paste
        case passthrough
        case disabled
    }
    
    public var type: ActionType
    public var keyCode: UInt16
    public var modifiers: UInt64
    public var customLabel: String
    public var isPhysicallyVerified: Bool
    
    enum CodingKeys: String, CodingKey {
        case type, keyCode, modifiers, customLabel, isPhysicallyVerified
    }
    
    public init(
        type: ActionType,
        keyCode: UInt16 = 0,
        modifiers: UInt64 = 0,
        customLabel: String = "",
        isPhysicallyVerified: Bool = false
    ) {
        self.type = type
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.customLabel = customLabel
        self.isPhysicallyVerified = isPhysicallyVerified
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(ActionType.self, forKey: .type)
        self.keyCode = try container.decodeIfPresent(UInt16.self, forKey: .keyCode) ?? 0
        self.modifiers = try container.decodeIfPresent(UInt64.self, forKey: .modifiers) ?? 0
        self.customLabel = try container.decodeIfPresent(String.self, forKey: .customLabel) ?? ""
        self.isPhysicallyVerified = try container.decodeIfPresent(Bool.self, forKey: .isPhysicallyVerified) ?? false
    }
    
    public var displayName: String {
        switch type {
        case .wisprFlowPTT:
            return "Wispr Flow PTT (⌥)"
        case .undo:
            return "Undo (⌘Z)"
        case .redo:
            return "Redo (⇧⌘Z)"
        case .copy:
            return "Copy (⌘C)"
        case .paste:
            return "Paste (⌘V)"
        case .shortcut:
            return customLabel.isEmpty ? "Shortcut (\(keyCode))" : customLabel
        case .passthrough:
            return "Passthrough (Original)"
        case .disabled:
            return "Disabled"
        }
    }
    
    public var subtitle: String {
        switch type {
        case .wisprFlowPTT:
            return "Hold to speak, release to type"
        case .undo:
            return "Triggers Command+Z"
        case .redo:
            return "Triggers Shift+Command+Z"
        case .copy:
            return "Triggers Command+C"
        case .paste:
            return "Triggers Command+V"
        case .shortcut:
            return "Simulates recorded keypress"
        case .passthrough:
            return "Default macOS browser navigation"
        case .disabled:
            return "Suppresses button click entirely"
        }
    }
    
    public func toInputAction() -> InputAction {
        switch type {
        case .wisprFlowPTT:
            return .wisprFlowPTT(keyCode: CGKeyCode(keyCode == 0 ? 61 : keyCode))
        case .undo:
            return .undo
        case .redo:
            return .redo
        case .copy:
            return .shortcut(keyCode: 8, flags: .maskCommand)
        case .paste:
            return .shortcut(keyCode: 9, flags: .maskCommand)
        case .shortcut:
            return .shortcut(keyCode: CGKeyCode(keyCode), flags: CGEventFlags(rawValue: modifiers))
        case .passthrough:
            return .passthrough
        case .disabled:
            return .disabled
        }
    }
}

/// Application profile for Kreo peripheral
public struct DeviceProfile: Codable, Identifiable, Equatable {
    public var id: UUID
    public var name: String
    public var appBundleId: String? // nil = Global Default
    public var assignments: [Int: StoredAction]
    public var deviceScope: String   // "kreoOnly" or "allMice"
    public var isDefault: Bool
    
    public init(
        id: UUID = UUID(),
        name: String,
        appBundleId: String? = nil,
        assignments: [Int: StoredAction] = [:],
        deviceScope: String = "kreoOnly",
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.appBundleId = appBundleId
        self.assignments = assignments
        self.deviceScope = deviceScope
        self.isDefault = isDefault
    }
    
    public static func defaultProfile() -> DeviceProfile {
        var assignments: [Int: StoredAction] = [:]
        // Front Side Button -> Wispr Flow PTT (Keycode 61 Right Option)
        assignments[PhysicalButton.frontSide.rawValue] = StoredAction(
            type: .wisprFlowPTT,
            keyCode: 61,
            customLabel: "Wispr Flow PTT"
        )
        // Rear Side Button -> Undo (Command+Z)
        assignments[PhysicalButton.rearSide.rawValue] = StoredAction(
            type: .undo,
            keyCode: 6,
            modifiers: CGEventFlags.maskCommand.rawValue,
            customLabel: "Undo"
        )
        return DeviceProfile(
            name: "Desktop: Default",
            assignments: assignments,
            isDefault: true
        )
    }
}

/// Central profile storage and engine synchronization
@MainActor
public final class ProfileStore: ObservableObject {
    @Published public var profiles: [DeviceProfile] = []
    @Published public var activeProfileId: UUID
    @Published public var isPaused: Bool = false
    @Published public var statusMessage: String = "Ready"
    
    public let inputEngine: InputEngine
    private let storageURL: URL
    private var undoHistory: [DeviceProfile] = []
    
    public var canUndo: Bool {
        !undoHistory.isEmpty
    }
    
    public init(inputEngine: InputEngine = InputEngine()) {
        self.inputEngine = inputEngine
        
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("MouseControl", isDirectory: true)
        try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
        self.storageURL = appDir.appendingPathComponent("profiles.json")
        
        let defaultProf = DeviceProfile.defaultProfile()
        self.activeProfileId = defaultProf.id
        
        load()
        syncToEngine()
    }
    
    public var activeProfile: DeviceProfile {
        get {
            profiles.first(where: { $0.id == activeProfileId }) ?? profiles.first ?? DeviceProfile.defaultProfile()
        }
        set {
            if let idx = profiles.firstIndex(where: { $0.id == newValue.id }) {
                profiles[idx] = newValue
                save()
                syncToEngine()
            }
        }
    }
    
    public func setAssignment(button: PhysicalButton, action: StoredAction) {
        undoHistory.append(activeProfile)
        var current = activeProfile
        current.assignments[button.rawValue] = action
        activeProfile = current
        statusMessage = "Updated \(button.displayName) -> \(action.displayName)"
    }
    
    public func clearAssignment(button: PhysicalButton) {
        undoHistory.append(activeProfile)
        var current = activeProfile
        current.assignments.removeValue(forKey: button.rawValue)
        activeProfile = current
        statusMessage = "Cleared \(button.displayName)"
    }
    
    public func restoreDefaultAssignment(button: PhysicalButton) {
        undoHistory.append(activeProfile)
        let def = DeviceProfile.defaultProfile()
        var current = activeProfile
        if let defaultAction = def.assignments[button.rawValue] {
            current.assignments[button.rawValue] = defaultAction
        } else {
            current.assignments.removeValue(forKey: button.rawValue)
        }
        activeProfile = current
        statusMessage = "Restored default for \(button.displayName)"
    }
    
    public func undoLastAssignment() {
        guard let previous = undoHistory.popLast() else { return }
        objectWillChange.send()
        activeProfile = previous
        statusMessage = "Reverted last change"
    }
    
    public func togglePause() {
        isPaused.toggle()
        if isPaused {
            inputEngine.pause()
            statusMessage = "Remapping Paused — Native mouse behavior restored"
        } else {
            inputEngine.resume()
            statusMessage = "Remapping Active"
        }
    }
    
    public func syncToEngine() {
        var engineMappings: [Int: InputAction] = [:]
        for (buttonNum, stored) in activeProfile.assignments {
            engineMappings[buttonNum] = stored.toInputAction()
        }
        inputEngine.setMappings(engineMappings)
    }
    
    public func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(profiles)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            print("Failed to save profiles: \(error)")
        }
    }
    
    public func load() {
        if FileManager.default.fileExists(atPath: storageURL.path) {
            do {
                let data = try Data(contentsOf: storageURL)
                let decoded = try JSONDecoder().decode([DeviceProfile].self, from: data)
                if !decoded.isEmpty {
                    self.profiles = decoded
                    if let defaultP = decoded.first(where: { $0.isDefault }) ?? decoded.first {
                        self.activeProfileId = defaultP.id
                    }
                    return
                }
            } catch {
                print("Failed to load profiles, initializing defaults: \(error)")
            }
        }
        // Initialize default profiles
        let defaultP = DeviceProfile.defaultProfile()
        var productivityP = DeviceProfile(name: "Productivity: Undo / Redo")
        productivityP.assignments[PhysicalButton.frontSide.rawValue] = StoredAction(type: .redo)
        productivityP.assignments[PhysicalButton.rearSide.rawValue] = StoredAction(type: .undo)
        
        self.profiles = [defaultP, productivityP]
        self.activeProfileId = defaultP.id
        save()
    }
}
