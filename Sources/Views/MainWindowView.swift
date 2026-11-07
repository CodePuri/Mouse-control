import SwiftUI
import AppKit

public enum MainTab: String, CaseIterable, Identifiable {
    case devices = "Devices"
    case checkMouse = "Check Mouse"
    case settings = "Settings"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .devices: return "computermouse.fill"
        case .checkMouse: return "checkmark.shield.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

public struct MainWindowView: View {
    @StateObject private var profileStore = ProfileStore()
    @StateObject private var deviceManager = DeviceManager()
    @State private var activeTab: MainTab = .devices
    @State private var selectedButton: PhysicalButton? = .frontSide
    @State private var viewMode: MouseViewMode = .side
    @State private var isRecordingShortcut: Bool = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Top Status Bar (60pt height)
            topBar
            
            Divider().background(Theme.borderSubtle)
            
            // Main 3-Column Body: Left Navigation Rail + Center / Right Content
            HStack(spacing: 0) {
                // Left Navigation Rail (76pt width)
                leftNavRail
                
                Divider().background(Theme.borderSubtle)
                
                // Tab Content
                switch activeTab {
                case .devices:
                    HStack(spacing: 0) {
                        // Center Stage (Dominant mouse view)
                        DeviceStageView(
                            profileStore: profileStore,
                            deviceManager: deviceManager,
                            selectedButton: $selectedButton,
                            viewMode: $viewMode,
                            isRecording: $isRecordingShortcut
                        )
                        
                        Divider().background(Theme.borderSubtle)
                        
                        // Right Contextual Editor Panel (340pt width)
                        ContextualEditorView(
                            profileStore: profileStore,
                            deviceManager: deviceManager,
                            button: selectedButton ?? .frontSide,
                            isRecording: $isRecordingShortcut
                        )
                    }
                case .checkMouse:
                    CheckMouseView(
                        profileStore: profileStore,
                        deviceManager: deviceManager
                    )
                case .settings:
                    SettingsView(
                        profileStore: profileStore,
                        deviceManager: deviceManager
                    )
                }
            }
        }
        .frame(minWidth: 1100, minHeight: 720)
        .background(Theme.bgCanvas)
        .onAppear {
            setupEngineBridge()
        }
    }
    
    // MARK: - Top Status Bar (60pt)
    
    private var topBar: some View {
        HStack(spacing: 16) {
            // Device Brand & Status
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Theme.bgCardElevated)
                        .frame(width: 36, height: 36)
                    Image(systemName: "computermouse.fill")
                        .foregroundColor(Theme.accentCyan)
                        .font(.system(size: 16))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kreo Chimera V2")
                        .font(Theme.fontHeader)
                        .foregroundColor(Theme.textPrimary)
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(deviceManager.isReceiverConnected ? Theme.statusGreen : Theme.statusOrange)
                            .frame(width: 7, height: 7)
                        Text(deviceManager.isReceiverConnected ? "Connected via 2.4GHz Receiver" : "Searching for Dongle...")
                            .font(Theme.fontSmall)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
            
            Spacer()
            
            // Profile Selector Dropdown
            HStack(spacing: 8) {
                Text("PROFILE:")
                    .font(Theme.fontBadge)
                    .foregroundColor(Theme.textMuted)
                
                Menu {
                    ForEach(profileStore.profiles) { p in
                        Button(action: {
                            profileStore.activeProfileId = p.id
                            profileStore.syncToEngine()
                        }) {
                            HStack {
                                Text(p.name)
                                if p.id == profileStore.activeProfileId {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    Divider()
                    Button("Wispr Flow Optimized") {
                        setWisprFlowOptimizedProfile()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(profileStore.activeProfile.name)
                            .font(Theme.fontHeader)
                            .foregroundColor(Theme.accentCyan)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.accentCyan)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Theme.bgCard)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.borderSubtle, lineWidth: 1))
                }
                .menuStyle(.borderlessButton)
            }
            
            // Remapping Pause/Resume Toggle
            Button(action: {
                withAnimation(.snappy(duration: 0.15)) {
                    profileStore.togglePause()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: profileStore.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 12))
                    Text(profileStore.isPaused ? "Resume Remapping" : "Pause Remapping")
                        .font(Theme.fontSmall)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(profileStore.isPaused ? Theme.statusOrange : Theme.bgCardElevated)
                .foregroundColor(profileStore.isPaused ? .black : Theme.textPrimary)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(profileStore.isPaused ? Theme.statusOrange : Theme.borderSubtle, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .frame(height: 60)
        .background(Theme.bgPanel)
    }
    
    // MARK: - Left Navigation Rail (76pt)
    
    private var leftNavRail: some View {
        VStack(spacing: 12) {
            ForEach(MainTab.allCases) { tab in
                Button(action: {
                    withAnimation(.snappy(duration: 0.15)) {
                        activeTab = tab
                    }
                }) {
                    VStack(spacing: 5) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 20))
                            .foregroundColor(activeTab == tab ? Theme.accentCyan : Theme.textMuted)
                        
                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: .semibold))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .foregroundColor(activeTab == tab ? Theme.accentCyan : Theme.textMuted)
                    }
                    .frame(width: 68, height: 56)
                    .background(activeTab == tab ? Theme.bgCardElevated : Color.clear)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(activeTab == tab ? Theme.accentCyan.opacity(0.4) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .help(tab.rawValue)
            }
            
            Spacer()
        }
        .padding(.top, 16)
        .frame(width: 76)
        .background(Theme.bgPanel)
    }
    
    // MARK: - Engine Bridge Setup
    
    private func setupEngineBridge() {
        // Connect InputEngine callbacks to DeviceManager telemetry
        profileStore.inputEngine.onButtonEventHandled = { [weak deviceManager] button, type, action in
            Task { @MainActor in
                let typeStr = (type == .otherMouseDown) ? "Down (Press)" : "Up (Release)"
                deviceManager?.recordEvent(
                    source: "Quartz Global Tap",
                    button: button,
                    phase: typeStr,
                    actionDesc: action?.description ?? "Passthrough",
                    suppressed: action?.isSuppressed ?? false
                )
            }
        }
        
        // Connect raw calibration event observer
        profileStore.inputEngine.onRawCalibrationEvent = { [weak deviceManager, weak profileStore] button, type, event in
            Task { @MainActor in
                guard let dm = deviceManager, let ps = profileStore else { return }
                let typeStr = (type == .otherMouseDown || type == .leftMouseDown || type == .rightMouseDown) ? "Down (Press)" : "Up (Release)"
                dm.handleCalibrationEvent(button: button, type: typeStr, engine: ps.inputEngine)
            }
        }
        
        // Start engine background listener
        _ = profileStore.inputEngine.start()
    }
    
    private func setWisprFlowOptimizedProfile() {
        var prof = DeviceProfile(name: "Wispr Flow Optimized")
        prof.assignments[PhysicalButton.frontSide.rawValue] = StoredAction(
            type: .wisprFlowPTT,
            keyCode: 61,
            customLabel: "Wispr Flow PTT (⌥)"
        )
        prof.assignments[PhysicalButton.rearSide.rawValue] = StoredAction(
            type: .undo,
            keyCode: 6,
            modifiers: CGEventFlags.maskCommand.rawValue,
            customLabel: "Undo (⌘Z)"
        )
        profileStore.profiles.append(prof)
        profileStore.activeProfileId = prof.id
        profileStore.syncToEngine()
    }
}
