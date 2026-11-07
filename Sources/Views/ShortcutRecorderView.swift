import SwiftUI
import AppKit
import CoreGraphics

public enum KeyCodeHelper {
    public static func stringForKeyCode(_ keyCode: UInt16, modifiers: UInt64 = 0) -> String {
        // Standalone modifier keys
        switch keyCode {
        case 61: return "Right Option (⌥)"
        case 58: return "Left Option (⌥)"
        case 55: return "Left Command (⌘)"
        case 54: return "Right Command (⌘)"
        case 56: return "Left Shift (⇧)"
        case 60: return "Right Shift (⇧)"
        case 59: return "Left Control (⌃)"
        case 62: return "Right Control (⌃)"
        default: break
        }
        
        var parts: [String] = []
        let flags = CGEventFlags(rawValue: modifiers)
        if flags.contains(.maskControl) { parts.append("⌃") }
        if flags.contains(.maskAlternate) { parts.append("⌥") }
        if flags.contains(.maskShift) { parts.append("⇧") }
        if flags.contains(.maskCommand) { parts.append("⌘") }
        
        let keyName: String
        switch keyCode {
        case 0: keyName = "A"
        case 1: keyName = "S"
        case 2: keyName = "D"
        case 3: keyName = "F"
        case 4: keyName = "H"
        case 5: keyName = "G"
        case 6: keyName = "Z"
        case 7: keyName = "X"
        case 8: keyName = "C"
        case 9: keyName = "V"
        case 11: keyName = "B"
        case 12: keyName = "Q"
        case 13: keyName = "W"
        case 14: keyName = "E"
        case 15: keyName = "R"
        case 16: keyName = "Y"
        case 17: keyName = "T"
        case 18: keyName = "1"
        case 19: keyName = "2"
        case 20: keyName = "3"
        case 21: keyName = "4"
        case 22: keyName = "6"
        case 23: keyName = "5"
        case 24: keyName = "="
        case 25: keyName = "9"
        case 26: keyName = "7"
        case 27: keyName = "-"
        case 28: keyName = "8"
        case 29: keyName = "0"
        case 30: keyName = "]"
        case 31: keyName = "O"
        case 32: keyName = "U"
        case 33: keyName = "["
        case 34: keyName = "I"
        case 35: keyName = "P"
        case 36: keyName = "↩"
        case 37: keyName = "L"
        case 38: keyName = "J"
        case 39: keyName = "'"
        case 40: keyName = "K"
        case 41: keyName = ";"
        case 42: keyName = "\\"
        case 43: keyName = ","
        case 44: keyName = "/"
        case 45: keyName = "N"
        case 46: keyName = "M"
        case 47: keyName = "."
        case 48: keyName = "⇥"
        case 49: keyName = "Space"
        case 50: keyName = "`"
        case 51: keyName = "⌫"
        case 53: keyName = "⎋"
        case 96: keyName = "F5"
        case 97: keyName = "F6"
        case 98: keyName = "F7"
        case 99: keyName = "F3"
        case 100: keyName = "F8"
        case 101: keyName = "F9"
        case 109: keyName = "F10"
        case 111: keyName = "F12"
        case 118: keyName = "F4"
        case 120: keyName = "F2"
        case 122: keyName = "F1"
        case 123: keyName = "←"
        case 124: keyName = "→"
        case 125: keyName = "↓"
        case 126: keyName = "↑"
        default:
            keyName = "Key(\(keyCode))"
        }
        
        parts.append(keyName)
        return parts.joined(separator: " + ")
    }
}

public struct ShortcutRecorderView: View {
    let button: PhysicalButton
    @ObservedObject var profileStore: ProfileStore
    var onAutoRecorded: (() -> Void)? = nil
    
    public enum RecorderState {
        case idle
        case recording
        case captured(String)
    }
    
    @State private var state: RecorderState = .idle
    @State private var localMonitor: Any? = nil
    @State private var pendingModifierKeyCode: UInt16? = nil
    @State private var isPulsing: Bool = false
    
    public init(
        button: PhysicalButton,
        profileStore: ProfileStore,
        onAutoRecorded: (() -> Void)? = nil
    ) {
        self.button = button
        self.profileStore = profileStore
        self.onAutoRecorded = onAutoRecorded
    }
    
    private var currentAssignment: StoredAction? {
        profileStore.activeProfile.assignments[button.rawValue]
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ASSIGNMENT RECORDER")
                    .font(Theme.fontBadge)
                    .foregroundColor(Theme.textMuted)
                
                Spacer()
                
                if case .recording = state {
                    Button(action: cancelRecording) {
                        Text("Cancel")
                            .font(Theme.fontSmall)
                            .foregroundColor(Theme.accentCyan)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Theme.bgCardElevated)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Primary interactive recorder box
            Button(action: {
                if case .recording = state {
                    cancelRecording()
                } else {
                    startRecording()
                }
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(boxBackgroundColor)
                    
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(boxBorderColor, lineWidth: isRecording ? 2 : 1)
                        .scaleEffect(isPulsing ? 1.02 : 1.0)
                    
                    HStack(spacing: 12) {
                        Image(systemName: boxIconName)
                            .font(.system(size: 18))
                            .foregroundColor(boxIconColor)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(boxMainText)
                                .font(Theme.fontHeader)
                                .foregroundColor(boxTextColor)
                            
                            Text(boxSubText)
                                .font(Theme.fontSmall)
                                .foregroundColor(Theme.textMuted)
                        }
                        
                        Spacer()
                        
                        if case .idle = state {
                            Text("Click to edit")
                                .font(Theme.fontBadge)
                                .foregroundColor(Theme.textMuted)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Theme.bgCanvas)
                                .cornerRadius(4)
                        } else if case .recording = state {
                            ProgressView()
                                .controlSize(.small)
                                .colorInvert()
                        } else if case .captured = state {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Theme.statusGreen)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
            }
            .buttonStyle(.plain)
            .help("Click to record a new keyboard shortcut for \(button.displayName)")
            
            // Helpful micro-instruction
            Text(isRecording ? "Press any key, modifier combo, or hold Right Option for Wispr Flow." : "Click box above to assign any key or shortcut automatically.")
                .font(.system(size: 11))
                .foregroundColor(isRecording ? Theme.accentCyan : Theme.textMuted)
        }
        .onDisappear {
            stopMonitoring()
        }
    }
    
    private var isRecording: Bool {
        if case .recording = state { return true }
        return false
    }
    
    private var boxBackgroundColor: Color {
        switch state {
        case .idle:
            return Theme.bgCard
        case .recording:
            return Theme.bgCardElevated
        case .captured:
            return Color(red: 20/255, green: 50/255, blue: 30/255)
        }
    }
    
    private var boxBorderColor: Color {
        switch state {
        case .idle:
            return Theme.borderSubtle
        case .recording:
            return Theme.accentCyan
        case .captured:
            return Theme.statusGreen
        }
    }
    
    private var boxIconName: String {
        switch state {
        case .idle:
            if let act = currentAssignment {
                switch act.type {
                case .wisprFlowPTT: return "mic.fill"
                case .undo: return "arrow.uturn.backward"
                case .redo: return "arrow.uturn.forward"
                case .copy: return "doc.on.doc"
                case .paste: return "doc.on.clipboard"
                case .shortcut: return "keyboard"
                case .passthrough: return "arrow.left.arrow.right"
                case .disabled: return "slash.circle"
                }
            }
            return "keyboard"
        case .recording:
            return "record.circle"
        case .captured:
            return "checkmark.circle.fill"
        }
    }
    
    private var boxIconColor: Color {
        switch state {
        case .idle:
            return currentAssignment != nil ? Theme.accentCyan : Theme.textMuted
        case .recording:
            return Theme.accentCyan
        case .captured:
            return Theme.statusGreen
        }
    }
    
    private var boxMainText: String {
        switch state {
        case .idle:
            if let act = currentAssignment {
                return act.displayName
            }
            return "No Shortcut Assigned"
        case .recording:
            return "Press any key or shortcut..."
        case .captured(let desc):
            return "Saved: \(desc)"
        }
    }
    
    private var boxSubText: String {
        switch state {
        case .idle:
            if let act = currentAssignment {
                return act.subtitle
            }
            return "Press to record input"
        case .recording:
            return "Ordinary keys, modifiers, or Right Option"
        case .captured:
            return "Mapping active and ready"
        }
    }
    
    private var boxTextColor: Color {
        switch state {
        case .idle:
            return currentAssignment != nil ? Theme.textPrimary : Theme.textSecondary
        case .recording:
            return Theme.accentCyan
        case .captured:
            return Theme.statusGreen
        }
    }
    
    // MARK: - Event Monitoring & Capture
    
    public func startRecording() {
        state = .recording
        isPulsing = true
        pendingModifierKeyCode = nil
        
        stopMonitoring()
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            DispatchQueue.main.async {
                self.handleKeyEvent(event)
            }
            return nil // Consume event while recording
        }
    }
    
    public func cancelRecording() {
        stopMonitoring()
        withAnimation(.snappy(duration: 0.2)) {
            state = .idle
            isPulsing = false
            pendingModifierKeyCode = nil
        }
    }
    
    private func stopMonitoring() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        guard case .recording = state else { return }
        
        if event.type == .flagsChanged {
            let keyCode = event.keyCode
            let currentFlags = event.modifierFlags
            
            // Check if this is a modifier key press or release
            let isDown: Bool
            switch keyCode {
            case 61, 58: // Option keys
                isDown = currentFlags.contains(.option)
            case 55, 54: // Command keys
                isDown = currentFlags.contains(.command)
            case 56, 60: // Shift keys
                isDown = currentFlags.contains(.shift)
            case 59, 62: // Control keys
                isDown = currentFlags.contains(.control)
            default:
                isDown = false
            }
            
            if isDown {
                // Modifier pressed down, wait to see if an ordinary key follows
                pendingModifierKeyCode = keyCode
            } else {
                // Modifier released!
                if let pressedCode = pendingModifierKeyCode, pressedCode == keyCode {
                    // Standalone modifier was pressed and released without another key
                    commitStandaloneModifier(keyCode: keyCode)
                }
                pendingModifierKeyCode = nil
            }
            return
        }
        
        if event.type == .keyDown {
            let keyCode = event.keyCode
            let flags = event.modifierFlags
            
            // Cancel on lone Escape
            if keyCode == 53 && flags.intersection([.command, .option, .control, .shift]).isEmpty {
                cancelRecording()
                return
            }
            
            // Build modifier mask
            var mask: CGEventFlags = []
            if flags.contains(.command) { mask.insert(.maskCommand) }
            if flags.contains(.option) { mask.insert(.maskAlternate) }
            if flags.contains(.control) { mask.insert(.maskControl) }
            if flags.contains(.shift) { mask.insert(.maskShift) }
            
            let label = KeyCodeHelper.stringForKeyCode(keyCode, modifiers: mask.rawValue)
            
            let action: StoredAction
            if mask.contains(.maskCommand) && keyCode == 6 {
                action = StoredAction(type: .undo, keyCode: keyCode, modifiers: mask.rawValue, customLabel: "Undo (⌘Z)")
            } else if mask.contains(.maskCommand) && mask.contains(.maskShift) && keyCode == 6 {
                action = StoredAction(type: .redo, keyCode: keyCode, modifiers: mask.rawValue, customLabel: "Redo (⇧⌘Z)")
            } else if mask.contains(.maskCommand) && keyCode == 8 {
                action = StoredAction(type: .copy, keyCode: keyCode, modifiers: mask.rawValue, customLabel: "Copy (⌘C)")
            } else if mask.contains(.maskCommand) && keyCode == 9 {
                action = StoredAction(type: .paste, keyCode: keyCode, modifiers: mask.rawValue, customLabel: "Paste (⌘V)")
            } else {
                action = StoredAction(type: .shortcut, keyCode: keyCode, modifiers: mask.rawValue, customLabel: label)
            }
            
            commitAction(action, display: label)
        }
    }
    
    private func commitStandaloneModifier(keyCode: UInt16) {
        if keyCode == 61 {
            // Right Option -> Wispr Flow PTT!
            let action = StoredAction(type: .wisprFlowPTT, keyCode: 61, customLabel: "Wispr Flow PTT (⌥)")
            commitAction(action, display: "Wispr Flow PTT (Right Option)")
        } else {
            let label = KeyCodeHelper.stringForKeyCode(keyCode)
            let action = StoredAction(type: .shortcut, keyCode: keyCode, modifiers: 0, customLabel: label)
            commitAction(action, display: label)
        }
    }
    
    private func commitAction(_ action: StoredAction, display: String) {
        stopMonitoring()
        profileStore.setAssignment(button: button, action: action)
        
        withAnimation(.snappy(duration: 0.2)) {
            state = .captured(display)
            isPulsing = false
        }
        
        onAutoRecorded?()
        
        // Return to idle after a brief moment
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.snappy(duration: 0.2)) {
                if case .captured = self.state {
                    self.state = .idle
                }
            }
        }
    }
}
