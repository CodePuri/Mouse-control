import SwiftUI

public enum MainTab: String, CaseIterable, Identifiable {
    case assignments = "Assignments"
    case diagnostics = "Diagnostics"
    case settings = "Settings"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .assignments: return "slider.horizontal.3"
        case .diagnostics: return "waveform.path.ecg"
        case .settings: return "gearshape.fill"
        }
    }
}

public struct MainWindowView: View {
    @StateObject private var profileStore = ProfileStore()
    @StateObject private var deviceManager = DeviceManager()
    @State private var activeTab: MainTab = .assignments
    @State private var selectedButton: PhysicalButton? = .frontSide
    @State private var viewMode: MouseViewMode = .side
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Top Toolbar (64pt height)
            topToolbar
            
            Divider().background(Theme.borderSubtle)
            
            // Main Body: Feature Rail + Context Area
            HStack(spacing: 0) {
                // Feature Rail (68pt width)
                featureRail
                
                Divider().background(Theme.borderSubtle)
                
                // Tab Content
                switch activeTab {
                case .assignments:
                    HStack(spacing: 0) {
                        AssignmentsView(
                            profileStore: profileStore,
                            deviceManager: deviceManager,
                            selectedButton: $selectedButton
                        )
                        
                        Divider().background(Theme.borderSubtle)
                        
                        DeviceStageView(
                            profileStore: profileStore,
                            deviceManager: deviceManager,
                            selectedButton: $selectedButton,
                            viewMode: $viewMode
                        )
                    }
                case .diagnostics:
                    DiagnosticsView(
                        profileStore: profileStore,
                        deviceManager: deviceManager
                    )
                case .settings:
                    settingsPanel
                }
            }
        }
        .frame(minWidth: 1100, minHeight: 720)
        .background(Theme.bgCanvas)
        .onAppear {
            setupEngineBridge()
        }
    }
    
    // MARK: - Top Toolbar (64pt)
    
    private var topToolbar: some View {
        HStack(spacing: 16) {
            // Device Brand & Name
            HStack(spacing: 10) {
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
                        Text(deviceManager.isReceiverConnected ? "2.4GHz Dongle Connected" : "Dongle Searching")
                            .font(Theme.fontSmall)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
            
            Spacer()
            
            // Profile Selector
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
            
            // View Switcher Segment
            HStack(spacing: 4) {
                Button(action: {
                    withAnimation(.snappy(duration: 0.15)) { viewMode = .side }
                }) {
                    Text("Side View")
                        .font(Theme.fontBadge)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(viewMode == .side ? Theme.accentCyan : Theme.bgCard)
                        .foregroundColor(viewMode == .side ? .black : Theme.textSecondary)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    withAnimation(.snappy(duration: 0.15)) { viewMode = .top }
                }) {
                    Text("Top View")
                        .font(Theme.fontBadge)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(viewMode == .top ? Theme.accentCyan : Theme.bgCard)
                        .foregroundColor(viewMode == .top ? .black : Theme.textSecondary)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, 8)
            
            // Pause Remapping Button
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
                .padding(.vertical, 8)
                .background(profileStore.isPaused ? Theme.statusOrange : Theme.bgCardElevated)
                .foregroundColor(profileStore.isPaused ? .black : Theme.textPrimary)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(profileStore.isPaused ? Theme.statusOrange : Theme.borderSubtle, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .frame(height: 64)
        .background(Theme.bgPanel)
    }
    
    // MARK: - Feature Rail (64pt)
    
    private var featureRail: some View {
        VStack(spacing: 14) {
            ForEach(MainTab.allCases) { tab in
                Button(action: {
                    withAnimation(.snappy(duration: 0.15)) {
                        activeTab = tab
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 20))
                            .foregroundColor(activeTab == tab ? Theme.accentCyan : Theme.textMuted)
                        
                        Text(tab.rawValue)
                            .font(.system(size: 8, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundColor(activeTab == tab ? Theme.accentCyan : Theme.textMuted)
                    }
                    .frame(width: 58, height: 54)
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
        .frame(width: 68)
        .background(Theme.bgPanel)
    }
    
    // MARK: - Settings Panel
    
    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Application Settings")
                .font(Theme.fontTitle)
                .foregroundColor(Theme.textPrimary)
            
            VStack(alignment: .leading, spacing: 14) {
                Text("PERIPHERAL CONFIGURATION PERSISTENCE")
                    .font(Theme.fontBadge)
                    .foregroundColor(Theme.textMuted)
                
                Text("Profiles are stored in local Application Support directory: ~/Library/Application Support/MouseControl/profiles.json")
                    .font(Theme.fontSmall)
                    .foregroundColor(Theme.textSecondary)
                
                HStack(spacing: 12) {
                    Button("Restore All Factory Defaults") {
                        profileStore.load()
                    }
                    .font(Theme.fontSmall)
                    .padding(8)
                    .background(Theme.bgCard)
                    .cornerRadius(6)
                    
                    Button("Save All Profiles Now") {
                        profileStore.save()
                    }
                    .font(Theme.fontSmall)
                    .padding(8)
                    .background(Theme.accentCyan)
                    .foregroundColor(.black)
                    .cornerRadius(6)
                }
            }
            .padding(16)
            .background(Theme.bgCard)
            .cornerRadius(8)
            
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.bgCanvas)
    }
    
    // MARK: - Engine Bridge Setup
    
    private func setupEngineBridge() {
        // Connect InputEngine callbacks to DeviceManager telemetry
        profileStore.inputEngine.onButtonEventHandled = { [weak deviceManager] button, type, action in
            Task { @MainActor in
                let typeStr = (type == .otherMouseDown) ? "Down" : "Up"
                deviceManager?.recordEvent(
                    button: button,
                    type: typeStr,
                    actionDesc: action?.description ?? "Passthrough",
                    suppressed: action?.isSuppressed ?? false
                )
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
