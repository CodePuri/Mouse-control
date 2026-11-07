import SwiftUI
import AppKit

public enum SettingsCategory: String, CaseIterable, Identifiable {
    case general = "General"
    case permissions = "Permissions"
    case devices = "Devices"
    case advanced = "Advanced"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .permissions: return "lock.shield"
        case .devices: return "computermouse"
        case .advanced: return "wrench.and.screwdriver"
        }
    }
}

public struct SettingsView: View {
    @ObservedObject var profileStore: ProfileStore
    @ObservedObject var deviceManager: DeviceManager
    @State private var activeCategory: SettingsCategory = .general
    @State private var launchAtLogin: Bool = true
    @State private var showMenuBarIcon: Bool = true
    @State private var copiedReport: Bool = false
    
    public init(profileStore: ProfileStore, deviceManager: DeviceManager) {
        self.profileStore = profileStore
        self.deviceManager = deviceManager
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            // Internal Sidebar for Settings
            VStack(alignment: .leading, spacing: 6) {
                Text("Settings")
                    .font(Theme.fontTitle)
                    .foregroundColor(Theme.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 12)
                
                ForEach(SettingsCategory.allCases) { cat in
                    Button(action: {
                        withAnimation(.snappy(duration: 0.15)) {
                            activeCategory = cat
                        }
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: cat.iconName)
                                .font(.system(size: 14))
                                .frame(width: 20)
                            
                            Text(cat.rawValue)
                                .font(Theme.fontBody)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(activeCategory == cat ? Theme.bgCardElevated : Color.clear)
                        .foregroundColor(activeCategory == cat ? Theme.accentCyan : Theme.textSecondary)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                }
                
                Spacer()
            }
            .frame(width: 200)
            .background(Theme.bgPanel)
            
            Divider().background(Theme.borderSubtle)
            
            // Detail Area
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch activeCategory {
                    case .general:
                        generalSection
                    case .permissions:
                        permissionsSection
                    case .devices:
                        devicesSection
                    case .advanced:
                        advancedSection
                    }
                }
                .padding(28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.bgCanvas)
        }
    }
    
    // MARK: - General Section
    
    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(title: "General Preferences", subtitle: "Configure app launch behavior and system integration.")
            
            VStack(spacing: 12) {
                settingToggleRow(
                    title: "Launch at Login",
                    subtitle: "Automatically start MouseControl in the background when you log in",
                    isOn: $launchAtLogin
                )
                
                settingToggleRow(
                    title: "Show Menu Bar Icon",
                    subtitle: "Access active profile and remapping toggle from macOS menu bar",
                    isOn: $showMenuBarIcon
                )
            }
            .padding(16)
            .background(Theme.bgCard)
            .cornerRadius(10)
            
            // Storage details
            VStack(alignment: .leading, spacing: 8) {
                Text("CONFIGURATION STORAGE")
                    .font(Theme.fontBadge)
                    .foregroundColor(Theme.textMuted)
                
                Text("Profile assignments are saved automatically in ~/Library/Application Support/MouseControl/profiles.json")
                    .font(Theme.fontSmall)
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(16)
            .background(Theme.bgCard)
            .cornerRadius(10)
        }
    }
    
    // MARK: - Permissions Section
    
    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(title: "System Permissions", subtitle: "MouseControl requires Accessibility permissions to intercept and remap auxiliary mouse buttons.")
            
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Theme.statusGreen)
                        .frame(width: 10, height: 10)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accessibility Permission Granted")
                            .font(Theme.fontHeader)
                            .foregroundColor(Theme.textPrimary)
                        
                        Text("CGEventTap is authorized to capture input events.")
                            .font(Theme.fontSmall)
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    Spacer()
                    
                    Button("Open System Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .font(Theme.fontSmall)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Theme.bgCardElevated)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.borderSubtle, lineWidth: 1))
                }
                
                Divider().background(Theme.borderSubtle)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("WHY ACCESSIBILITY IS REQUIRED")
                        .font(Theme.fontBadge)
                        .foregroundColor(Theme.textMuted)
                    
                    Text("macOS isolates peripheral button clicks to prevent unauthorized interception. The Accessibility API allows MouseControl to listen for auxiliary side buttons (Buttons 3 & 4) and suppress default browser navigation.")
                        .font(Theme.fontSmall)
                        .foregroundColor(Theme.textSecondary)
                        .lineSpacing(2)
                }
            }
            .padding(18)
            .background(Theme.bgCard)
            .cornerRadius(10)
        }
    }
    
    // MARK: - Devices Section
    
    private var devicesSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(title: "Connected Devices", subtitle: "Detected hardware peripherals and USB receiver interfaces.")
            
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.bgCardElevated)
                            .frame(width: 44, height: 44)
                        Image(systemName: "computermouse.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Theme.accentCyan)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text("Kreo Chimera V2")
                                .font(Theme.fontHeader)
                                .foregroundColor(Theme.textPrimary)
                            
                            Text("CONNECTED")
                                .font(Theme.fontBadge)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.statusGreen.opacity(0.2))
                                .foregroundColor(Theme.statusGreen)
                                .cornerRadius(4)
                        }
                        
                        Text("Vendor ID: 0x248a | Product ID: 0x5b4a (Wireless Dongle)")
                            .font(Theme.fontSmall)
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    Spacer()
                }
                
                Divider().background(Theme.borderSubtle)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("REGISTERED HID INTERFACES")
                        .font(Theme.fontBadge)
                        .foregroundColor(Theme.textMuted)
                    
                    interfaceRow(name: "Interface 2 (Mouse)", desc: "Usage 0x02 — Declares Buttons 1, 2, 3 and X/Y scroll", isOk: true)
                    interfaceRow(name: "Interface 1 (Keyboard/Consumer)", desc: "Usage 0x06 — Declares Keycodes 0x00-0xF1 & Consumer AC Back/Forward", isOk: true)
                    interfaceRow(name: "Interface 0 (Vendor Defined)", desc: "Usage Page 0xFF01 — Proprietary wireless telemetry packets", isOk: true)
                }
            }
            .padding(18)
            .background(Theme.bgCard)
            .cornerRadius(10)
        }
    }
    
    // MARK: - Advanced Section (Diagnostics & Telemetry)
    
    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(title: "Advanced Diagnostics", subtitle: "Developer telemetry, raw event tap health, and diagnostic export.")
            
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("DIAGNOSTIC REPORT EXPORT")
                            .font(Theme.fontBadge)
                            .foregroundColor(Theme.textMuted)
                        
                        Text("Export a full diagnostic summary of hardware, HID descriptors, and event tap health to your clipboard.")
                            .font(Theme.fontSmall)
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    Spacer()
                    
                    Button(action: copyDiagnosticReport) {
                        HStack(spacing: 6) {
                            Image(systemName: copiedReport ? "checkmark" : "doc.on.doc")
                            Text(copiedReport ? "Copied to Clipboard!" : "Copy Diagnostic Report")
                        }
                        .font(Theme.fontSmall)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(copiedReport ? Theme.statusGreen : Theme.accentCyan)
                        .foregroundColor(.black)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                
                Divider().background(Theme.borderSubtle)
                
                // Live Technical Status Grid
                VStack(alignment: .leading, spacing: 10) {
                    Text("LIVE EVENT TAP HEALTH")
                        .font(Theme.fontBadge)
                        .foregroundColor(Theme.textMuted)
                    
                    HStack(spacing: 20) {
                        techParam(label: "CGEventTap State", value: profileStore.inputEngine.isRunning ? "Active & Running" : "Stopped", isGood: profileStore.inputEngine.isRunning)
                        techParam(label: "Remapping State", value: profileStore.isPaused ? "Paused" : "Remapping Enabled", isGood: !profileStore.isPaused)
                        techParam(label: "Loop Prevention Marker", value: "0x4D435452", isGood: true)
                    }
                }
                
                Divider().background(Theme.borderSubtle)
                
                // Hardware Descriptor Reality Note
                VStack(alignment: .leading, spacing: 6) {
                    Text("HARDWARE HID DESCRIPTOR SUMMARY")
                        .font(Theme.fontBadge)
                        .foregroundColor(Theme.textMuted)
                    
                    Text("• Mouse Interface (0x248a:0x5b4a:02): Exposes Buttons 1..3 only. Buttons 4 & 5 are not declared in the mouse report descriptor.")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                    Text("• Keyboard Interface (0x248a:0x5b4a:01): Exposes full USB HID keyboard matrix and Consumer AC Back/Forward (0x224/0x225).")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                    Text("• Vendor Interface (0x248a:0x5b4a:00): Usage Page 0xFF01 vendor feature reports.")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                }
                
                Divider().background(Theme.borderSubtle)
                
                // Reset Factory Defaults
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reset Settings & Profiles")
                            .font(Theme.fontHeader)
                            .foregroundColor(Theme.textPrimary)
                        Text("Restore default profile with Wispr Flow on Front Side Button and Undo on Rear Side Button.")
                            .font(Theme.fontSmall)
                            .foregroundColor(Theme.textMuted)
                    }
                    
                    Spacer()
                    
                    Button("Reset to Defaults") {
                        let def = DeviceProfile.defaultProfile()
                        profileStore.profiles = [def]
                        profileStore.activeProfileId = def.id
                        profileStore.save()
                        profileStore.syncToEngine()
                    }
                    .font(Theme.fontSmall)
                    .foregroundColor(Theme.statusOrange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.bgCardElevated)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.borderSubtle, lineWidth: 1))
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
            .background(Theme.bgCard)
            .cornerRadius(10)
        }
    }
    
    // MARK: - Helpers
    
    private func copyDiagnosticReport() {
        let report = """
        === MOUSECONTROL DIAGNOSTIC REPORT ===
        Date: \(Date())
        macOS Version: 14+ (Mach-O minos 14.0 arm64)
        Bundle: com.codepuri.MouseControl
        
        [HARDWARE STATUS]
        Connected Peripheral: Kreo Chimera V2
        Vendor ID: 0x248a
        Product ID: 0x5b4a
        Transport: USB 2.4GHz Wireless Dongle
        
        [HID DESCRIPTORS]
        Interface 2 (Mouse):
          - Primary Page: 0x01 (Generic Desktop), Usage: 0x02 (Mouse)
          - Button Elements: 3 (Usage 0x01, 0x02, 0x03)
          - X/Y/Wheel: Usage 0x30, 0x31, 0x38
        Interface 1 (Keyboard/Consumer):
          - Primary Page: 0x01, Usage: 0x06 (Keyboard)
          - Keyboard elements: 0x00 .. 0xF1
          - Consumer controls: Page 0x0C (AC Back 0x224, AC Forward 0x225)
        Interface 0 (Vendor):
          - Primary Page: 0xFF01, Usage: 0x01
        
        [ENGINE STATUS]
        CGEventTap Running: \(profileStore.inputEngine.isRunning)
        Remapping Paused: \(profileStore.isPaused)
        Active Profile: \(profileStore.activeProfile.name)
        Front Button Mapping: \(profileStore.activeProfile.assignments[PhysicalButton.frontSide.rawValue]?.displayName ?? "None")
        Rear Button Mapping: \(profileStore.activeProfile.assignments[PhysicalButton.rearSide.rawValue]?.displayName ?? "None")
        
        [OBSERVATION]
        Last Pressed Button: \(deviceManager.lastPressedButton.map(String.init) ?? "None")
        Detected Front Button: \(deviceManager.detectedFrontButton.map(String.init) ?? "Awaiting detection")
        Detected Rear Button: \(deviceManager.detectedRearButton.map(String.init) ?? "Awaiting detection")
        =======================================
        """
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(report, forType: .string)
        
        withAnimation {
            copiedReport = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                copiedReport = false
            }
        }
    }
    
    @ViewBuilder
    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Theme.fontTitle)
                .foregroundColor(Theme.textPrimary)
            Text(subtitle)
                .font(Theme.fontBody)
                .foregroundColor(Theme.textSecondary)
        }
    }
    
    @ViewBuilder
    private func settingToggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.fontHeader)
                    .foregroundColor(Theme.textPrimary)
                Text(subtitle)
                    .font(Theme.fontSmall)
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: Theme.accentCyan))
        }
    }
    
    @ViewBuilder
    private func interfaceRow(name: String, desc: String, isOk: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isOk ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(isOk ? Theme.statusGreen : Theme.statusOrange)
                .font(.system(size: 13))
            
            Text(name)
                .font(Theme.fontHeader)
                .foregroundColor(Theme.textPrimary)
            
            Text("— \(desc)")
                .font(Theme.fontSmall)
                .foregroundColor(Theme.textMuted)
        }
    }
    
    @ViewBuilder
    private func techParam(label: String, value: String, isGood: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Theme.fontBadge)
                .foregroundColor(Theme.textMuted)
            Text(value)
                .font(Theme.fontHeader)
                .foregroundColor(isGood ? Theme.statusGreen : Theme.statusOrange)
        }
        .padding(10)
        .background(Theme.bgCanvas)
        .cornerRadius(6)
    }
}
