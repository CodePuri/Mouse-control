import Foundation
import CoreGraphics
import ApplicationServices
import AppKit

/// Dynamic macOS version and permission manager.
/// Adapts terminology, deep links, recovery instructions, and multi-layer authorization
/// checks dynamically across macOS versions (e.g. macOS 27 Golden Gate "Device Control and Data Access"
/// vs legacy macOS "Accessibility").
public final class PermissionManager: ObservableObject {
    public static let shared = PermissionManager()
    
    // MARK: - OS Version Detection
    
    public static var osVersion: OperatingSystemVersion {
        ProcessInfo.processInfo.operatingSystemVersion
    }
    
    public static var isMacOS27OrNewer: Bool {
        osVersion.majorVersion >= 27
    }
    
    public static var osDisplayName: String {
        if isMacOS27OrNewer {
            return "macOS \(osVersion.majorVersion).\(osVersion.minorVersion) (Golden Gate)"
        } else {
            return "macOS \(osVersion.majorVersion).\(osVersion.minorVersion)"
        }
    }
    
    /// Permission section name in System Settings -> Privacy & Security.
    /// Renamed to "Device Control and Data Access" in macOS 27 Golden Gate.
    public static var permissionSectionName: String {
        if isMacOS27OrNewer {
            return "Device Control and Data Access"
        } else {
            return "Accessibility"
        }
    }
    
    /// Compact name for buttons and badges.
    public static var permissionSectionShortName: String {
        if isMacOS27OrNewer {
            return "Device Control"
        } else {
            return "Accessibility"
        }
    }
    
    /// Human-readable navigation path in System Settings.
    public static var settingsPathDescription: String {
        "System Settings → Privacy & Security → \(permissionSectionName)"
    }
    
    /// Recovery instructions when macOS marks the app with a prohibition icon (⃠).
    public static var recoveryInstructions: String {
        "If you see '⃠ Kreo Mouse Control' with a prohibition sign in \(settingsPathDescription), select it, click '—' to remove the broken entry, then toggle Kreo Mouse Control ON."
    }
    
    // MARK: - Settings Deep Links
    
    /// Primary URL for deep linking into the specific privacy pane.
    public static var primarySettingsURL: URL {
        if isMacOS27OrNewer {
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_DeviceControl") ??
                   URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") ??
                   URL(string: "x-apple.systempreferences:com.apple.preference.security")!
        } else {
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") ??
                   URL(string: "x-apple.systempreferences:com.apple.preference.security")!
        }
    }
    
    /// Fallback URLs in order of preference.
    public static var fallbackSettingsURLs: [URL] {
        [
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"),
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_DeviceControl"),
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"),
            URL(string: "x-apple.systempreferences:com.apple.preference.security")
        ].compactMap { $0 }
    }
    
    /// Safely opens System Settings directly to the appropriate permission pane.
    public static func openSystemSettingsPermissionPane() {
        let primary = primarySettingsURL
        if NSWorkspace.shared.open(primary) {
            return
        }
        for fallback in fallbackSettingsURLs {
            if NSWorkspace.shared.open(fallback) {
                return
            }
        }
    }
    
    // MARK: - Multi-Layer Authorization Verification (Not Assuming)
    
    @Published public var isFullyAuthorized: Bool = false
    @Published public var deviceControlTrusted: Bool = false
    @Published public var inputMonitoringAuthorized: Bool = false
    @Published public var eventPostingAuthorized: Bool = false
    @Published public var eventTapFunctional: Bool = false
    @Published public var lastCheckTime: Date = Date()
    
    public init() {
        refresh()
    }
    
    /// Refreshes all 4 authorization layers without assuming permission is granted.
    public func refresh(activeEngineRunning: Bool = false) {
        // Layer 1: Device Control / Accessibility trust
        let trusted = AXIsProcessTrusted()
        
        // Layer 2: Input Monitoring authorization (Listening to global events)
        let listenAccess = CGPreflightListenEventAccess()
        
        // Layer 3: Event Posting authorization (Posting synthetic keystrokes)
        let postAccess = CGPreflightPostEventAccess()
        
        // Layer 4: Real Event Tap functionality test
        let tapWorking: Bool
        if activeEngineRunning {
            tapWorking = true
        } else {
            tapWorking = PermissionManager.verifyEventTapCreation()
        }
        
        self.deviceControlTrusted = trusted
        self.inputMonitoringAuthorized = listenAccess
        self.eventPostingAuthorized = postAccess
        self.eventTapFunctional = tapWorking
        
        // Process is fully authorized only when all required layers pass
        self.isFullyAuthorized = trusted && listenAccess && postAccess && tapWorking
        self.lastCheckTime = Date()
    }
    
    /// Directly tests whether an actual CGEventTap can be created right now.
    /// Does not assume anything based on previous state or boolean flags.
    public static func verifyEventTapCreation() -> Bool {
        let mask: CGEventMask = (1 << CGEventType.otherMouseDown.rawValue)
        guard let _ = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, _, event, _ in Unmanaged.passUnretained(event) },
            userInfo: nil
        ) else {
            return false
        }
        return true
    }
    
    /// Prompts macOS for all required permissions dynamically.
    public func requestPermissions() {
        // Prompt for Device Control / Accessibility
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        
        // Request Input Monitoring access
        CGRequestListenEventAccess()
        
        // Request Event Posting access
        CGRequestPostEventAccess()
        
        // Re-check status after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.refresh()
        }
    }
}
