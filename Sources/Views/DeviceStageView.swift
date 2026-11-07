import SwiftUI
import AppKit

public enum MouseViewMode: String, CaseIterable, Identifiable {
    case side = "VIEW 2: SIDE"
    case top = "VIEW 1: TOP"
    public var id: String { rawValue }
}

public struct DeviceStageView: View {
    @ObservedObject var profileStore: ProfileStore
    @ObservedObject var deviceManager: DeviceManager
    @Binding var selectedButton: PhysicalButton?
    @Binding var viewMode: MouseViewMode
    
    public init(
        profileStore: ProfileStore,
        deviceManager: DeviceManager,
        selectedButton: Binding<PhysicalButton?>,
        viewMode: Binding<MouseViewMode>
    ) {
        self.profileStore = profileStore
        self.deviceManager = deviceManager
        self._selectedButton = selectedButton
        self._viewMode = viewMode
    }
    
    public var body: some View {
        GeometryReader { geo in
            ZStack {
                Theme.bgCanvas
                    .ignoresSafeArea()
                
                // Device Image Stage
                ZStack {
                    // Kreo Cutout Image anchored to content bounds
                    deviceImageView(stageSize: geo.size)
                    
                    // Interactive Callout Pins & Hotspots
                    if viewMode == .side {
                        sideViewOverlay(stageSize: geo.size)
                    } else {
                        topViewOverlay(stageSize: geo.size)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // View Switcher Pill at bottom (Matching R01 / G HUB)
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        ForEach(MouseViewMode.allCases) { mode in
                            Button(action: {
                                withAnimation(.snappy(duration: 0.2)) {
                                    viewMode = mode
                                }
                            }) {
                                Text(mode.rawValue)
                                    .font(Theme.fontBadge)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(viewMode == mode ? Theme.accentCyan : Theme.bgCard)
                                    .foregroundColor(viewMode == mode ? .black : Theme.textSecondary)
                                    .cornerRadius(14)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier(mode.rawValue)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
        }
    }
    
    // MARK: - Content Bounds Calculation
    
    private func imageContentBounds(stageSize: CGSize) -> CGRect {
        // Cutouts are 1:1 square aspect ratio (1920x1920)
        let maxSide = min(stageSize.height * 0.74, min(stageSize.width * 0.82, 540))
        let originX = (stageSize.width - maxSide) / 2
        let originY = (stageSize.height - maxSide) / 2 - 16
        return CGRect(x: originX, y: originY, width: maxSide, height: maxSide)
    }
    
    private func loadDeviceImage(baseName: String) -> NSImage? {
        if let bundlePath = Bundle.main.path(forResource: baseName, ofType: "png", inDirectory: "Resources") ??
                           Bundle.main.path(forResource: baseName, ofType: "png") {
            if let img = NSImage(contentsOfFile: bundlePath) { return img }
        }
        
        let directPaths = [
            "Resources/\(baseName).png",
            "/Users/totem/Desktop/Code/Mouse control/Resources/\(baseName).png"
        ]
        for p in directPaths {
            if let img = NSImage(contentsOfFile: p) {
                return img
            }
        }
        return nil
    }

    @ViewBuilder
    private func deviceImageView(stageSize: CGSize) -> some View {
        let baseName = (viewMode == .side) ? "kreo_side_cutout" : "kreo_top_cutout"
        let loadedImage = loadDeviceImage(baseName: baseName)
        let bounds = imageContentBounds(stageSize: stageSize)
        
        if let nsImage = loadedImage {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
                .frame(width: bounds.width, height: bounds.height)
                .position(x: bounds.midX, y: bounds.midY)
                .shadow(color: Color.black.opacity(0.6), radius: 25, x: 0, y: 15)
        } else {
            VStack {
                Image(systemName: "computermouse.fill")
                    .font(.system(size: 80))
                    .foregroundColor(Theme.textMuted)
                Text("Kreo Chimera V2 (\(viewMode.rawValue))")
                    .font(Theme.fontHeader)
                    .foregroundColor(Theme.textSecondary)
            }
            .position(x: bounds.midX, y: bounds.midY)
        }
    }
    
    // MARK: - Side View Overlay (Anchored to Image Bounds)
    
    @ViewBuilder
    private func sideViewOverlay(stageSize: CGSize) -> some View {
        let bounds = imageContentBounds(stageSize: stageSize)
        
        // Exact pixel centers inside the 1920x1920 cutout image:
        // Front purple button (closer to scroll wheel): (815, 940) -> (0.4245, 0.4896)
        // Rear purple button (closer to palm): (1050, 940) -> (0.5469, 0.4896)
        let frontBtnPos = CGPoint(
            x: bounds.minX + bounds.width * (815.0 / 1920.0),
            y: bounds.minY + bounds.height * (940.0 / 1920.0)
        )
        let rearBtnPos = CGPoint(
            x: bounds.minX + bounds.width * (1050.0 / 1920.0),
            y: bounds.minY + bounds.height * (940.0 / 1920.0)
        )
        
        // Callout card positions on the left side of the stage
        let frontCalloutPos = CGPoint(
            x: max(135, bounds.minX - 110),
            y: frontBtnPos.y - 48
        )
        let rearCalloutPos = CGPoint(
            x: max(135, bounds.minX - 110),
            y: rearBtnPos.y + 48
        )
        
        // Leader Lines connecting buttons to callout cards
        Path { path in
            path.move(to: frontBtnPos)
            path.addLine(to: CGPoint(x: frontCalloutPos.x + 105, y: frontCalloutPos.y))
            
            path.move(to: rearBtnPos)
            path.addLine(to: CGPoint(x: rearCalloutPos.x + 105, y: rearCalloutPos.y))
        }
        .stroke(Theme.borderSubtle, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
        
        // Hotspot 1: Front Side Button (Quartz Button 4)
        hotspotDot(
            pos: frontBtnPos,
            button: .frontSide,
            isPressed: (deviceManager.lastPressedButton == 4 || deviceManager.detectedFrontButton == 4)
        )
        
        // Callout 1: Front Side Button
        calloutCard(
            pos: frontCalloutPos,
            button: .frontSide,
            action: profileStore.activeProfile.assignments[PhysicalButton.frontSide.rawValue]
        )
        
        // Hotspot 2: Rear Side Button (Quartz Button 3)
        hotspotDot(
            pos: rearBtnPos,
            button: .rearSide,
            isPressed: (deviceManager.lastPressedButton == 3 || deviceManager.detectedRearButton == 3)
        )
        
        // Callout 2: Rear Side Button
        calloutCard(
            pos: rearCalloutPos,
            button: .rearSide,
            action: profileStore.activeProfile.assignments[PhysicalButton.rearSide.rawValue]
        )
    }
    
    // MARK: - Top View Overlay (Anchored to Image Bounds)
    
    @ViewBuilder
    private func topViewOverlay(stageSize: CGSize) -> some View {
        let bounds = imageContentBounds(stageSize: stageSize)
        
        // Scroll wheel center at (960, 540) -> (0.50, 0.28125)
        let wheelPos = CGPoint(
            x: bounds.minX + bounds.width * 0.50,
            y: bounds.minY + bounds.height * (540.0 / 1920.0)
        )
        let wheelCalloutPos = CGPoint(
            x: wheelPos.x,
            y: max(60, bounds.minY - 45)
        )
        
        Path { path in
            path.move(to: wheelPos)
            path.addLine(to: CGPoint(x: wheelCalloutPos.x, y: wheelCalloutPos.y + 25))
        }
        .stroke(Theme.borderSubtle, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
        
        hotspotDot(
            pos: wheelPos,
            button: .middle,
            isPressed: (deviceManager.lastPressedButton == 2 || deviceManager.positiveControlObservedButton == 2)
        )
        
        calloutCard(
            pos: wheelCalloutPos,
            button: .middle,
            action: profileStore.activeProfile.assignments[PhysicalButton.middle.rawValue]
        )
    }
    
    // MARK: - Hotspot Pin
    
    @ViewBuilder
    private func hotspotDot(pos: CGPoint, button: PhysicalButton, isPressed: Bool) -> some View {
        let isSelected = selectedButton == button
        
        ZStack {
            // Ripple glow on press or selection
            if isPressed || isSelected {
                Circle()
                    .stroke(isSelected ? Theme.accentCyan : Theme.accentPurple, lineWidth: 2)
                    .frame(width: 26, height: 26)
                    .scaleEffect(isPressed ? 1.3 : 1.0)
                    .animation(.snappy(duration: 0.15), value: isPressed)
            }
            
            Circle()
                .fill(isSelected ? Theme.accentCyan : (isPressed ? Theme.accentPurple : Color.white))
                .frame(width: 14, height: 14)
                .shadow(color: (isSelected ? Theme.accentCyan : Color.white).opacity(0.8), radius: 6)
            
            Circle()
                .fill(Color.black.opacity(0.2))
                .frame(width: 4, height: 4)
        }
        .frame(width: 40, height: 40)
        .contentShape(Rectangle())
        .position(pos)
        .help("Click to configure \(button.displayName)")
        .onTapGesture {
            withAnimation(.snappy(duration: 0.2)) {
                selectedButton = button
            }
        }
    }
    
    // MARK: - Callout Card (Readable, Non-Truncated)
    
    @ViewBuilder
    private func calloutCard(pos: CGPoint, button: PhysicalButton, action: StoredAction?) -> some View {
        let isSelected = selectedButton == button
        
        Button(action: {
            withAnimation(.snappy(duration: 0.2)) {
                selectedButton = button
            }
        }) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(button.displayName)
                        .font(Theme.fontSmall)
                        .foregroundColor(Theme.textSecondary)
                    
                    Spacer(minLength: 0)
                    
                    Text("BTN \(button.rawValue)")
                        .font(Theme.fontBadge)
                        .foregroundColor(Theme.textMuted)
                }
                
                HStack(spacing: 6) {
                    if let act = action {
                        Image(systemName: iconForAction(act))
                            .font(.system(size: 11))
                            .foregroundColor(iconColorForAction(act))
                        
                        Text(displayTitleForAction(act))
                            .font(Theme.fontHeader)
                            .foregroundColor(isSelected ? Theme.accentCyan : Theme.textPrimary)
                            .lineLimit(1)
                        
                        Spacer(minLength: 0)
                        
                        Text(badgeForAction(act))
                            .font(Theme.fontBadge)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.bgCanvas)
                            .foregroundColor(Theme.accentCyan)
                            .cornerRadius(4)
                    } else {
                        Text("Unassigned")
                            .font(Theme.fontSmall)
                            .foregroundColor(Theme.textMuted)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(width: 215)
            .fixedSize(horizontal: false, vertical: true)
            .background(isSelected ? Theme.bgCardElevated : Theme.bgCard)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Theme.accentCyan : Theme.borderSubtle, lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .position(pos)
        .help(action?.subtitle ?? "Click to configure \(button.displayName)")
    }
    
    private func displayTitleForAction(_ act: StoredAction) -> String {
        switch act.type {
        case .wisprFlowPTT: return "Wispr Flow"
        case .undo: return "Undo"
        case .redo: return "Redo"
        case .shortcut: return act.customLabel.isEmpty ? "Shortcut" : act.customLabel
        case .passthrough: return "Passthrough"
        case .disabled: return "Disabled"
        }
    }
    
    private func badgeForAction(_ act: StoredAction) -> String {
        switch act.type {
        case .wisprFlowPTT: return "⌥ PTT"
        case .undo: return "⌘Z"
        case .redo: return "⇧⌘Z"
        case .shortcut: return "Key"
        case .passthrough: return "Native"
        case .disabled: return "Off"
        }
    }
    
    private func iconForAction(_ act: StoredAction) -> String {
        switch act.type {
        case .wisprFlowPTT: return "mic.fill"
        case .undo: return "arrow.uturn.backward"
        case .redo: return "arrow.uturn.forward"
        case .shortcut: return "keyboard"
        case .passthrough: return "arrow.left.arrow.right"
        case .disabled: return "slash.circle"
        }
    }
    
    private func iconColorForAction(_ act: StoredAction) -> Color {
        switch act.type {
        case .wisprFlowPTT: return Theme.accentCyan
        case .undo, .redo: return Theme.statusGreen
        default: return Theme.textSecondary
        }
    }
}
