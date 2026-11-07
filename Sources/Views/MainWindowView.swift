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
    @ObservedObject private var permissionManager = PermissionManager.shared
    @State private var activeTab: MainTab = .devices
    @State private var selectedButton: PhysicalButton? = .frontSide
    @State private var viewMode: MouseViewMode = .side
    @State private var isRecordingShortcut: Bool = false
    @State private var showAssignmentsPalette: Bool = true
    @State private var searchCommandText: String = ""
    @State private var paletteSubtab: String = "COMMANDS"
    
    private let permCheckTimer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Top Status Bar (60pt height)
            topBar
            
            // Multi-Layer Permission & Authorization Warning Banner
            if !permissionManager.isFullyAuthorized {
                permissionWarningBanner
            }
            
            Divider().background(Theme.borderSubtle)
            
            // Main Body: Left Navigation Rail + Content
            HStack(spacing: 0) {
                // Left Navigation Rail (68pt width)
                leftNavRail
                
                Divider().background(Theme.borderSubtle)
                
                // Tab Content
                switch activeTab {
                case .devices:
                    HStack(spacing: 0) {
                        // G HUB Style Commands Palette (280pt)
                        if showAssignmentsPalette {
                            gHubAssignmentsPalette
                            Divider().background(Theme.borderSubtle)
                        }
                        
                        // Center Stage (Dominant mouse view)
                        DeviceStageView(
                            profileStore: profileStore,
                            deviceManager: deviceManager,
                            selectedButton: $selectedButton,
                            viewMode: $viewMode,
                            isRecording: $isRecordingShortcut
                        )
                        
                        Divider().background(Theme.borderSubtle)
                        
                        // Right Contextual Editor Panel (320pt width)
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
            checkPermissions()
        }
        .onReceive(permCheckTimer) { _ in
            checkPermissions()
        }
    }
    
    // MARK: - Multi-Layer Permission Verification & Dynamic Banner
    
    private func checkPermissions() {
        permissionManager.refresh(activeEngineRunning: profileStore.inputEngine.isRunning)
        if permissionManager.isFullyAuthorized && !profileStore.inputEngine.isRunning {
            _ = profileStore.inputEngine.start()
        }
    }
    
    private var permissionWarningBanner: some View {
        HStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundColor(Theme.statusOrange)
            
            VStack(alignment: .leading, spacing: 3) {
                Text("\(PermissionManager.permissionSectionName) Required (\(PermissionManager.osDisplayName))")
                    .font(Theme.fontHeader)
                    .foregroundColor(Theme.textPrimary)
                
                Text(PermissionManager.recoveryInstructions)
                    .font(Theme.fontSmall)
                    .foregroundColor(Theme.textSecondary)
                
                // Verified Multi-Layer Badges
                HStack(spacing: 8) {
                    layerBadge(name: PermissionManager.permissionSectionShortName, ok: permissionManager.deviceControlTrusted)
                    layerBadge(name: "Input Monitoring", ok: permissionManager.inputMonitoringAuthorized)
                    layerBadge(name: "Event Posting", ok: permissionManager.eventPostingAuthorized)
                    layerBadge(name: "Event Tap", ok: permissionManager.eventTapFunctional)
                }
                .padding(.top, 2)
            }
            
            Spacer()
            
            Button("Grant Permission") {
                permissionManager.requestPermissions()
            }
            .buttonStyle(.plain)
            .font(Theme.fontSmall)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.accentCyan)
            .foregroundColor(.black)
            .cornerRadius(6)
            
            Button("Open Settings") {
                PermissionManager.openSystemSettingsPermissionPane()
            }
            .buttonStyle(.plain)
            .font(Theme.fontSmall)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.bgCardElevated)
            .foregroundColor(Theme.textPrimary)
            .cornerRadius(6)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Theme.statusOrange.opacity(0.15))
        .overlay(Rectangle().frame(height: 1).foregroundColor(Theme.statusOrange.opacity(0.4)), alignment: .bottom)
    }
    
    @ViewBuilder
    private func layerBadge(name: String, ok: Bool) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(ok ? Theme.statusGreen : Theme.statusOrange)
                .frame(width: 5, height: 5)
            Text("\(name): \(ok ? "Verified" : "Pending")")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(ok ? Theme.statusGreen : Theme.statusOrange)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Theme.bgCanvas.opacity(0.6))
        .cornerRadius(4)
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
                .accessibilityIdentifier("Tab_\(tab.rawValue)")
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
        
        // Connect multi-interface hardware actions from IOHIDManager
        deviceManager.onHardwareButtonAction = { [weak profileStore] button, isDown in
            profileStore?.inputEngine.triggerAction(forButton: button, isDown: isDown)
        }
        
        // Start engine background listener
        _ = profileStore.inputEngine.start()
    }
    
    // MARK: - G HUB Style Assignments Palette (Image 2)
    
    private var gHubAssignmentsPalette: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Assignments")
                    .font(Theme.fontTitle)
                    .foregroundColor(Theme.textPrimary)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.snappy(duration: 0.2)) {
                        showAssignmentsPalette.toggle()
                    }
                }) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Toggle assignments palette")
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 10)
            
            // Subtabs: COMMANDS, KEYS, ACTIONS, SYSTEM (G HUB Image 2)
            HStack(spacing: 2) {
                ForEach(["COMMANDS", "KEYS", "ACTIONS", "SYSTEM"], id: \.self) { tab in
                    Button(action: {
                        paletteSubtab = tab
                    }) {
                        Text(tab)
                            .font(.system(size: 9, weight: .bold))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .foregroundColor(paletteSubtab == tab ? Theme.accentCyan : Theme.textMuted)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 5)
                            .overlay(
                                Rectangle()
                                    .frame(height: 2)
                                    .foregroundColor(paletteSubtab == tab ? Theme.accentCyan : Color.clear),
                                alignment: .bottom
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
            
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Theme.textMuted)
                    .font(.system(size: 12))
                TextField("Search for a command...", text: $searchCommandText)
                    .textFieldStyle(.plain)
                    .font(Theme.fontSmall)
                    .foregroundColor(Theme.textPrimary)
                if !searchCommandText.isEmpty {
                    Button(action: { searchCommandText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.textMuted)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Theme.bgCardElevated)
            .cornerRadius(6)
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
            
            Divider().background(Theme.borderSubtle)
            
            // Commands List
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if paletteSubtab == "COMMANDS" || paletteSubtab == "ACTIONS" {
                        // Voice & AI Group
                        commandGroup(title: "Voice & AI Dictation") {
                            commandRow(
                                glyph: "⌥",
                                title: "Wispr Flow PTT",
                                subtitle: "Right Option (KeyCode 61)",
                                action: StoredAction(type: .wisprFlowPTT, keyCode: 61, customLabel: "Wispr Flow PTT (⌥)")
                            )
                            commandRow(
                                glyph: "W",
                                title: "Willow Voice",
                                subtitle: "Dictation shortcut",
                                action: StoredAction(type: .shortcut, keyCode: 49, modifiers: CGEventFlags.maskAlternate.rawValue, customLabel: "Willow Voice (⌥Space)")
                            )
                        }
                        
                        // Editing Group (G HUB Image 2)
                        commandGroup(title: "Editing") {
                            commandRow(
                                glyph: "⌘Z",
                                title: "Undo",
                                subtitle: "Revert last action",
                                action: StoredAction(type: .undo, keyCode: 6, modifiers: CGEventFlags.maskCommand.rawValue, customLabel: "Undo (⌘Z)")
                            )
                            commandRow(
                                glyph: "⇧⌘Z",
                                title: "Redo",
                                subtitle: "Reapply action",
                                action: StoredAction(type: .redo, keyCode: 6, modifiers: CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue, customLabel: "Redo (⇧⌘Z)")
                            )
                            commandRow(
                                glyph: "⌘X",
                                title: "Cut",
                                subtitle: "Cut to clipboard",
                                action: StoredAction(type: .shortcut, keyCode: 7, modifiers: CGEventFlags.maskCommand.rawValue, customLabel: "Cut (⌘X)")
                            )
                            commandRow(
                                glyph: "⌘C",
                                title: "Copy",
                                subtitle: "Copy to clipboard",
                                action: StoredAction(type: .copy, keyCode: 8, modifiers: CGEventFlags.maskCommand.rawValue, customLabel: "Copy (⌘C)")
                            )
                            commandRow(
                                glyph: "⌘V",
                                title: "Paste",
                                subtitle: "Paste from clipboard",
                                action: StoredAction(type: .paste, keyCode: 9, modifiers: CGEventFlags.maskCommand.rawValue, customLabel: "Paste (⌘V)")
                            )
                            commandRow(
                                glyph: "⌘A",
                                title: "Select All",
                                subtitle: "Select all items",
                                action: StoredAction(type: .shortcut, keyCode: 0, modifiers: CGEventFlags.maskCommand.rawValue, customLabel: "Select All (⌘A)")
                            )
                            commandRow(
                                glyph: "⌘S",
                                title: "Save",
                                subtitle: "Save active document",
                                action: StoredAction(type: .shortcut, keyCode: 1, modifiers: CGEventFlags.maskCommand.rawValue, customLabel: "Save (⌘S)")
                            )
                            commandRow(
                                glyph: "⌘W",
                                title: "Close Tab",
                                subtitle: "Close window/tab",
                                action: StoredAction(type: .shortcut, keyCode: 13, modifiers: CGEventFlags.maskCommand.rawValue, customLabel: "Close Tab (⌘W)")
                            )
                            commandRow(
                                glyph: "⌘T",
                                title: "New Tab",
                                subtitle: "Open new browser tab",
                                action: StoredAction(type: .shortcut, keyCode: 17, modifiers: CGEventFlags.maskCommand.rawValue, customLabel: "New Tab (⌘T)")
                            )
                        }
                    } else if paletteSubtab == "SYSTEM" {
                        commandGroup(title: "macOS System Controls") {
                            commandRow(
                                glyph: "⌃↑",
                                title: "Mission Control",
                                subtitle: "Show all windows",
                                action: StoredAction(type: .shortcut, keyCode: 126, modifiers: CGEventFlags.maskControl.rawValue, customLabel: "Mission Control")
                            )
                            commandRow(
                                glyph: "F11",
                                title: "Show Desktop",
                                subtitle: "Reveal desktop",
                                action: StoredAction(type: .shortcut, keyCode: 103, customLabel: "Show Desktop")
                            )
                            commandRow(
                                glyph: "⌘⇥",
                                title: "App Switcher",
                                subtitle: "Cycle applications",
                                action: StoredAction(type: .shortcut, keyCode: 48, modifiers: CGEventFlags.maskCommand.rawValue, customLabel: "App Switcher")
                            )
                        }
                    } else { // KEYS
                        commandGroup(title: "Standard Navigation Keys") {
                            commandRow(
                                glyph: "⌫",
                                title: "Backspace / Back",
                                subtitle: "Navigate back",
                                action: StoredAction(type: .shortcut, keyCode: 51, customLabel: "Delete / Back")
                            )
                            commandRow(
                                glyph: "⎋",
                                title: "Escape",
                                subtitle: "Cancel / exit",
                                action: StoredAction(type: .shortcut, keyCode: 53, customLabel: "Escape")
                            )
                            commandRow(
                                glyph: "⇥",
                                title: "Tab",
                                subtitle: "Next focus element",
                                action: StoredAction(type: .shortcut, keyCode: 48, customLabel: "Tab")
                            )
                        }
                    }
                }
                .padding(14)
            }
        }
        .frame(width: 280)
        .background(Theme.bgPanel)
    }
    
    @ViewBuilder
    private func commandGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(Theme.fontBadge)
                .foregroundColor(Theme.textMuted)
                .padding(.leading, 4)
            
            VStack(spacing: 4) {
                content()
            }
        }
    }
    
    @ViewBuilder
    private func commandRow(glyph: String, title: String, subtitle: String, action: StoredAction) -> some View {
        let isMatch = searchCommandText.isEmpty ||
                     title.localizedCaseInsensitiveContains(searchCommandText) ||
                     subtitle.localizedCaseInsensitiveContains(searchCommandText)
        
        if isMatch {
            Button(action: {
                assignCommandToSelectedButton(action)
            }) {
                HStack(spacing: 10) {
                    Text(glyph)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .frame(width: 32, height: 24)
                        .background(Theme.bgCard)
                        .foregroundColor(Theme.accentCyan)
                        .cornerRadius(4)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(Theme.fontHeader)
                            .foregroundColor(Theme.textPrimary)
                        Text(subtitle)
                            .font(.system(size: 9))
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "plus.circle")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textMuted)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Theme.bgCardElevated)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
    }
    
    private func assignCommandToSelectedButton(_ action: StoredAction) {
        let targetBtn = selectedButton ?? .frontSide
        profileStore.setAssignment(button: targetBtn, action: action)
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
