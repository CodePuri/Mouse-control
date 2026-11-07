import SwiftUI
import AppKit

public struct ContextualEditorView: View {
    @ObservedObject var profileStore: ProfileStore
    @ObservedObject var deviceManager: DeviceManager
    let button: PhysicalButton
    @Binding var isRecording: Bool
    var onDismiss: (() -> Void)? = nil
    
    public init(
        profileStore: ProfileStore,
        deviceManager: DeviceManager,
        button: PhysicalButton,
        isRecording: Binding<Bool> = .constant(false),
        onDismiss: (() -> Void)? = nil
    ) {
        self.profileStore = profileStore
        self.deviceManager = deviceManager
        self.button = button
        self._isRecording = isRecording
        self.onDismiss = onDismiss
    }
    
    private var currentAssignment: StoredAction? {
        profileStore.activeProfile.assignments[button.rawValue]
    }
    
    private var isPhysicallyObserved: Bool {
        if button == .frontSide && (deviceManager.detectedFrontButton == 4 || deviceManager.positiveControlObservedButton == 4) {
            return true
        }
        if button == .rearSide && (deviceManager.detectedRearButton == 3 || deviceManager.positiveControlObservedButton == 3) {
            return true
        }
        if button == .middle && (deviceManager.positiveControlObservedButton == 2 || deviceManager.lastPressedButton == 2) {
            return true
        }
        return false
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(button.displayName)
                        .font(Theme.fontTitle)
                        .foregroundColor(Theme.textPrimary)
                    
                    Text(button.physicalDescription)
                        .font(Theme.fontSmall)
                        .foregroundColor(Theme.textSecondary)
                }
                
                Spacer()
                
                if let dismiss = onDismiss {
                    Button(action: dismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Theme.textMuted)
                    }
                    .buttonStyle(.plain)
                    .help("Close editor")
                }
            }
            .padding(16)
            .background(Theme.bgPanel)
            
            Divider().background(Theme.borderSubtle)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Physical Status Badge (Honest)
                    HStack(spacing: 8) {
                        Circle()
                            .fill(isPhysicallyObserved ? Theme.statusGreen : Theme.statusOrange)
                            .frame(width: 8, height: 8)
                        
                        Text(isPhysicallyObserved ? "Physical Signal Verified" : "Assigned — Awaiting button detection")
                            .font(Theme.fontSmall)
                            .foregroundColor(isPhysicallyObserved ? Theme.statusGreen : Theme.statusOrange)
                        
                        Spacer()
                        
                        Text("BTN \(button.rawValue)")
                            .font(Theme.fontBadge)
                            .foregroundColor(Theme.textMuted)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Theme.bgCard)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.borderSubtle, lineWidth: 1))
                    
                    // Immediate Shortcut Recorder
                    ShortcutRecorderView(
                        button: button,
                        profileStore: profileStore,
                        isRecordingExternal: $isRecording
                    )
                    
                    Divider().background(Theme.borderSubtle)
                    
                    // Quick Action Presets
                    VStack(alignment: .leading, spacing: 6) {
                        Text("QUICK ACTION PRESETS")
                            .font(Theme.fontBadge)
                            .foregroundColor(Theme.textMuted)
                        
                        presetRow(
                            icon: "mic.fill",
                            color: Theme.accentCyan,
                            title: "Wispr Flow (Right Option PTT)",
                            subtitle: "Hold to dictate, release to type",
                            actionType: .wisprFlowPTT,
                            action: StoredAction(type: .wisprFlowPTT, keyCode: 61, customLabel: "Wispr Flow PTT (⌥)")
                        )
                        
                        presetRow(
                            icon: "arrow.uturn.backward",
                            color: Theme.statusGreen,
                            title: "Undo (⌘Z)",
                            subtitle: "Revert the last action",
                            actionType: .undo,
                            action: StoredAction(type: .undo, keyCode: 6, modifiers: CGEventFlags.maskCommand.rawValue, customLabel: "Undo (⌘Z)")
                        )
                        
                        presetRow(
                            icon: "arrow.uturn.forward",
                            color: Theme.statusGreen,
                            title: "Redo (⇧⌘Z)",
                            subtitle: "Reapply the undone action",
                            actionType: .redo,
                            action: StoredAction(type: .redo, keyCode: 6, modifiers: CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue, customLabel: "Redo (⇧⌘Z)")
                        )
                        
                        presetRow(
                            icon: "doc.on.doc",
                            color: Theme.accentPurple,
                            title: "Copy (⌘C)",
                            subtitle: "Copy selected content to clipboard",
                            actionType: .copy,
                            action: StoredAction(type: .copy, keyCode: 8, modifiers: CGEventFlags.maskCommand.rawValue, customLabel: "Copy (⌘C)")
                        )
                        
                        presetRow(
                            icon: "doc.on.clipboard",
                            color: Theme.accentPurple,
                            title: "Paste (⌘V)",
                            subtitle: "Paste content from clipboard",
                            actionType: .paste,
                            action: StoredAction(type: .paste, keyCode: 9, modifiers: CGEventFlags.maskCommand.rawValue, customLabel: "Paste (⌘V)")
                        )
                        
                        presetRow(
                            icon: "macwindow.on.rectangle",
                            color: Theme.accentCyan,
                            title: "Mission Control",
                            subtitle: "Show all open windows",
                            actionType: .shortcut,
                            action: StoredAction(type: .shortcut, keyCode: 126, modifiers: CGEventFlags.maskControl.rawValue, customLabel: "Mission Control (⌃↑)")
                        )
                        
                        presetRow(
                            icon: "rectangle.inset.filled.and.person.filled",
                            color: Theme.statusGreen,
                            title: "Show Desktop (F11)",
                            subtitle: "Instantly reveal desktop",
                            actionType: .shortcut,
                            action: StoredAction(type: .shortcut, keyCode: 103, customLabel: "Show Desktop (F11)")
                        )
                        
                        presetRow(
                            icon: "arrow.left.arrow.right",
                            color: Theme.textSecondary,
                            title: "Passthrough (Browser Nav)",
                            subtitle: "Standard macOS Back/Forward navigation",
                            actionType: .passthrough,
                            action: StoredAction(type: .passthrough)
                        )
                        
                        presetRow(
                            icon: "slash.circle",
                            color: Theme.textMuted,
                            title: "Disabled",
                            subtitle: "Block button clicks completely",
                            actionType: .disabled,
                            action: StoredAction(type: .disabled)
                        )
                    }
                    
                    Divider().background(Theme.borderSubtle)
                    
                    // Maintenance Controls (Undo, Restore Default, Clear)
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Button(action: {
                                withAnimation(.snappy(duration: 0.15)) {
                                    profileStore.restoreDefaultAssignment(button: button)
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("Restore Default")
                                }
                                .font(Theme.fontSmall)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(Theme.bgCard)
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.borderSubtle, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: {
                                withAnimation(.snappy(duration: 0.15)) {
                                    profileStore.undoLastAssignment()
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.uturn.backward")
                                    Text("Undo")
                                }
                                .font(Theme.fontSmall)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(Theme.bgCard)
                                .foregroundColor(profileStore.canUndo ? Theme.textPrimary : Theme.textMuted)
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.borderSubtle, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .disabled(!profileStore.canUndo)
                        }
                        
                        Button(action: {
                            withAnimation(.snappy(duration: 0.15)) {
                                profileStore.clearAssignment(button: button)
                            }
                        }) {
                            Text("Clear Assignment")
                                .font(Theme.fontSmall)
                                .foregroundColor(Theme.statusOrange)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color.clear)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
            }
        }
        .frame(width: 340)
        .background(Theme.bgPanel)
    }
    
    @ViewBuilder
    private func presetRow(
        icon: String,
        color: Color,
        title: String,
        subtitle: String,
        actionType: StoredAction.ActionType,
        action: StoredAction
    ) -> some View {
        let isSelected = currentAssignment?.type == actionType
        
        Button(action: {
            withAnimation(.snappy(duration: 0.15)) {
                profileStore.setAssignment(button: button, action: action)
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(color)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(Theme.fontBody)
                        .foregroundColor(isSelected ? Theme.accentCyan : Theme.textPrimary)
                    
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textMuted)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.accentCyan)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Theme.bgCardElevated : Theme.bgCard)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Theme.accentCyan : Theme.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
