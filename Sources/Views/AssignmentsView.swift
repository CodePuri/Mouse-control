import SwiftUI
import AppKit
import CoreGraphics

public struct AssignmentsView: View {
    @ObservedObject var profileStore: ProfileStore
    @ObservedObject var deviceManager: DeviceManager
    @Binding var selectedButton: PhysicalButton?
    
    @State private var searchText: String = ""
    @State private var isRecordingShortcut: Bool = false
    @State private var recordedKeyCode: UInt16 = 0
    @State private var recordedModifiers: UInt64 = 0
    @State private var recordedLabel: String = ""
    @State private var localFeedback: String? = nil
    
    public init(profileStore: ProfileStore, deviceManager: DeviceManager, selectedButton: Binding<PhysicalButton?>) {
        self.profileStore = profileStore
        self.deviceManager = deviceManager
        self._selectedButton = selectedButton
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Panel Header
            VStack(alignment: .leading, spacing: 6) {
                Text("Assignments")
                    .font(Theme.fontTitle)
                    .foregroundColor(Theme.textPrimary)
                
                Text(selectedButton == nil ? "Select a physical button on the mouse to assign actions." : "\(selectedButton!.displayName) is selected.")
                    .font(Theme.fontSmall)
                    .foregroundColor(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            
            Divider()
                .background(Theme.borderSubtle)
            
            ScrollView {
                VStack(spacing: 16) {
                    if let btn = selectedButton {
                        selectedButtonEditor(button: btn)
                    } else {
                        noButtonSelectedHint
                    }
                }
                .padding(16)
            }
            
            // Bottom Status / Scope notice
            VStack(spacing: 4) {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(Theme.textMuted)
                        .font(.system(size: 11))
                    Text(profileStore.activeProfile.deviceScope == "kreoOnly" ? "Scope: Kreo Chimera V2" : "Scope: All Connected Mice (Global)")
                        .font(Theme.fontSmall)
                        .foregroundColor(Theme.textMuted)
                    Spacer()
                }
                if let feedback = localFeedback {
                    Text(feedback)
                        .font(Theme.fontSmall)
                        .foregroundColor(Theme.accentCyan)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(12)
            .background(Theme.bgCard)
        }
        .frame(width: 320)
        .background(Theme.bgPanel)
    }
    
    @ViewBuilder
    private var noButtonSelectedHint: some View {
        VStack(spacing: 16) {
            Image(systemName: "cursorarrow.click.2")
                .font(.system(size: 40))
                .foregroundColor(Theme.accentCyan.opacity(0.8))
                .padding(.top, 40)
            
            Text("Click a Button Hotspot")
                .font(Theme.fontHeader)
                .foregroundColor(Theme.textPrimary)
            
            Text("Click the Front Side Button (Button 4) or Rear Side Button (Button 3) callout pins on the mouse stage to configure their actions.")
                .font(Theme.fontBody)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 8) {
                Button(action: { selectedButton = .frontSide }) {
                    HStack {
                        Text("Configure Front Side Button (Btn 4)")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(Theme.fontSmall)
                    .padding(10)
                    .background(Theme.bgCard)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Button(action: { selectedButton = .rearSide }) {
                    HStack {
                        Text("Configure Rear Side Button (Btn 3)")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(Theme.fontSmall)
                    .padding(10)
                    .background(Theme.bgCard)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 12)
        }
    }
    
    @ViewBuilder
    private func selectedButtonEditor(button: PhysicalButton) -> some View {
        let currentAction = profileStore.activeProfile.assignments[button.rawValue]
        
        VStack(alignment: .leading, spacing: 14) {
            // Button Info Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(button.displayName)
                        .font(Theme.fontHeader)
                        .foregroundColor(Theme.accentCyan)
                    Text(button.physicalDescription)
                        .font(Theme.fontSmall)
                        .foregroundColor(Theme.textMuted)
                }
                Spacer()
                Button(action: { selectedButton = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(Theme.bgCardElevated)
            .cornerRadius(8)
            
            // Available Actions List
            Text("RECOMMENDED ACTIONS")
                .font(Theme.fontBadge)
                .foregroundColor(Theme.textMuted)
            
            // Action 1: Wispr Flow PTT
            actionCard(
                title: "Wispr Flow Dictation",
                subtitle: "Push-To-Talk: Hold to speak, release to type",
                icon: "mic.fill",
                iconColor: Theme.accentCyan,
                isSelected: currentAction?.type == .wisprFlowPTT
            ) {
                profileStore.setAssignment(
                    button: button,
                    action: StoredAction(type: .wisprFlowPTT, keyCode: 61, customLabel: "Wispr Flow PTT")
                )
                showFeedback("Mapped to Wispr Flow PTT (Right Option)")
            }
            
            // Action 2: Undo
            actionCard(
                title: "Undo (⌘Z)",
                subtitle: "Standard application undo shortcut",
                icon: "arrow.uturn.backward",
                iconColor: Theme.statusGreen,
                isSelected: currentAction?.type == .undo
            ) {
                profileStore.setAssignment(
                    button: button,
                    action: StoredAction(type: .undo, keyCode: 6, modifiers: CGEventFlags.maskCommand.rawValue, customLabel: "Undo")
                )
                showFeedback("Mapped to Undo (⌘Z)")
            }
            
            // Action 3: Redo
            actionCard(
                title: "Redo (⇧⌘Z)",
                subtitle: "Standard application redo shortcut",
                icon: "arrow.uturn.forward",
                iconColor: Theme.statusGreen,
                isSelected: currentAction?.type == .redo
            ) {
                profileStore.setAssignment(
                    button: button,
                    action: StoredAction(type: .redo, keyCode: 6, modifiers: (CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue), customLabel: "Redo")
                )
                showFeedback("Mapped to Redo (⇧⌘Z)")
            }
            
            // Action 4: Custom Shortcut Recorder
            VStack(alignment: .leading, spacing: 8) {
                Text("CUSTOM SHORTCUT")
                    .font(Theme.fontBadge)
                    .foregroundColor(Theme.textMuted)
                    .padding(.top, 6)
                
                HStack {
                    if isRecordingShortcut {
                        Text("Press keys to record...")
                            .font(Theme.fontBody)
                            .foregroundColor(Theme.statusOrange)
                    } else if currentAction?.type == .shortcut {
                        Text(currentAction?.customLabel ?? "Custom Shortcut")
                            .font(Theme.fontHeader)
                            .foregroundColor(Theme.accentCyan)
                    } else {
                        Text("No custom shortcut set")
                            .font(Theme.fontBody)
                            .foregroundColor(Theme.textMuted)
                    }
                    Spacer()
                    
                    Button(action: {
                        toggleRecordingShortcut(button: button)
                    }) {
                        Text(isRecordingShortcut ? "Stop" : "Record")
                            .font(Theme.fontSmall)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(isRecordingShortcut ? Theme.statusOrange : Theme.accentCyan)
                            .foregroundColor(.black)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(Theme.bgCard)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isRecordingShortcut ? Theme.statusOrange : Theme.borderSubtle, lineWidth: 1)
                )
            }
            
            // Action 5: Passthrough & Disable
            VStack(alignment: .leading, spacing: 8) {
                Text("SYSTEM BEHAVIOR")
                    .font(Theme.fontBadge)
                    .foregroundColor(Theme.textMuted)
                    .padding(.top, 6)
                
                actionCard(
                    title: "Passthrough (Default)",
                    subtitle: "Preserves native macOS browser back/forward",
                    icon: "arrow.left.arrow.right",
                    iconColor: Theme.textSecondary,
                    isSelected: currentAction?.type == .passthrough
                ) {
                    profileStore.setAssignment(
                        button: button,
                        action: StoredAction(type: .passthrough, customLabel: "Passthrough")
                    )
                    showFeedback("Set to Passthrough")
                }
                
                actionCard(
                    title: "Disable Button",
                    subtitle: "Suppresses button click entirely",
                    icon: "slash.circle",
                    iconColor: Theme.textMuted,
                    isSelected: currentAction?.type == .disabled
                ) {
                    profileStore.setAssignment(
                        button: button,
                        action: StoredAction(type: .disabled, customLabel: "Disabled")
                    )
                    showFeedback("Disabled button")
                }
            }
            
            // Action Buttons: Test Action / Clear
            HStack(spacing: 10) {
                Button(action: {
                    testAction(action: currentAction)
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Test Action")
                    }
                    .font(Theme.fontSmall)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Theme.bgCardElevated)
                    .foregroundColor(Theme.textPrimary)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    profileStore.clearAssignment(button: button)
                    showFeedback("Reset button assignment")
                }) {
                    Text("Clear")
                        .font(Theme.fontSmall)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Theme.bgCard)
                        .foregroundColor(Theme.textMuted)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 10)
        }
    }
    
    @ViewBuilder
    private func actionCard(
        title: String,
        subtitle: String,
        icon: String,
        iconColor: Color,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.fontHeader)
                        .foregroundColor(isSelected ? Theme.accentCyan : Theme.textPrimary)
                    Text(subtitle)
                        .font(Theme.fontSmall)
                        .foregroundColor(Theme.textSecondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.accentCyan)
                }
            }
            .padding(12)
            .background(isSelected ? Theme.bgCardElevated : Theme.bgCard)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Theme.accentCyan : Theme.borderSubtle, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func toggleRecordingShortcut(button: PhysicalButton) {
        isRecordingShortcut.toggle()
        if isRecordingShortcut {
            showFeedback("Listening for shortcut... (e.g. ⌘+Shift+D)")
            // NSEvent local monitor for shortcut recording
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                guard self.isRecordingShortcut else { return event }
                
                let keyCode = event.keyCode
                let flags = event.modifierFlags.intersection([.command, .shift, .control, .option])
                var descParts: [String] = []
                if flags.contains(.control) { descParts.append("⌃") }
                if flags.contains(.option) { descParts.append("⌥") }
                if flags.contains(.shift) { descParts.append("⇧") }
                if flags.contains(.command) { descParts.append("⌘") }
                
                let chars = event.charactersIgnoringModifiers?.uppercased() ?? "Key \(keyCode)"
                descParts.append(chars)
                let fullLabel = descParts.joined()
                
                Task { @MainActor in
                    self.profileStore.setAssignment(
                        button: button,
                        action: StoredAction(
                            type: .shortcut,
                            keyCode: keyCode,
                            modifiers: UInt64(flags.rawValue),
                            customLabel: fullLabel
                        )
                    )
                    self.isRecordingShortcut = false
                    self.showFeedback("Recorded \(fullLabel)")
                }
                return nil
            }
        }
    }
    
    private func testAction(action: StoredAction?) {
        guard let act = action else {
            showFeedback("No action assigned to test")
            return
        }
        showFeedback("Testing action: \(act.displayName)...")
        // Post synthetic test event
        let inputAct = act.toInputAction()
        profileStore.inputEngine.simulateAction(inputAct)
    }
    
    private func showFeedback(_ text: String) {
        localFeedback = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if self.localFeedback == text {
                self.localFeedback = nil
            }
        }
    }
}
