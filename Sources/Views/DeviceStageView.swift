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
                VStack(spacing: 0) {
                    Spacer()
                    
                    ZStack {
                        // Kreo Cutout Image
                        deviceImageView(stageSize: geo.size)
                        
                        // Interactive Callout Pins & Hotspots
                        if viewMode == .side {
                            sideViewOverlay(stageSize: geo.size)
                        } else {
                            topViewOverlay(stageSize: geo.size)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    Spacer()
                    
                    // View Switcher Pill (Matching R01 / G HUB)
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
        
        if let nsImage = loadedImage {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: min(stageSize.height * 0.78, 560))
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
        }
    }
    
    @ViewBuilder
    private func sideViewOverlay(stageSize: CGSize) -> some View {
        // Calibrated coordinates directly landing on Kreo Chimera V2 purple side buttons:
        // Front purple button (pointing left, closer to wheel)
        let frontBtnPos = CGPoint(x: stageSize.width * 0.495, y: stageSize.height * 0.445)
        // Rear purple button (pointing left, closer to palm)
        let rearBtnPos = CGPoint(x: stageSize.width * 0.535, y: stageSize.height * 0.445)
        
        // Callout card positions on the left side of the stage
        let frontCalloutPos = CGPoint(x: max(120, stageSize.width * 0.18), y: frontBtnPos.y - 45)
        let rearCalloutPos = CGPoint(x: max(120, stageSize.width * 0.18), y: rearBtnPos.y + 45)
        
        // Leader Lines connecting buttons to callout cards
        Path { path in
            path.move(to: frontBtnPos)
            path.addLine(to: CGPoint(x: frontCalloutPos.x + 105, y: frontCalloutPos.y))
            
            path.move(to: rearBtnPos)
            path.addLine(to: CGPoint(x: rearCalloutPos.x + 105, y: rearCalloutPos.y))
        }
        .stroke(Theme.borderSubtle, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
        
        // Hotspot 1: Front Side Button (Button 4)
        hotspotDot(
            pos: frontBtnPos,
            button: .frontSide,
            isPressed: deviceManager.lastPressedButton == 4
        )
        
        // Callout 1: Front Side Button
        calloutCard(
            pos: frontCalloutPos,
            button: .frontSide,
            action: profileStore.activeProfile.assignments[PhysicalButton.frontSide.rawValue]
        )
        
        // Hotspot 2: Rear Side Button (Button 3)
        hotspotDot(
            pos: rearBtnPos,
            button: .rearSide,
            isPressed: deviceManager.lastPressedButton == 3
        )
        
        // Callout 2: Rear Side Button
        calloutCard(
            pos: rearCalloutPos,
            button: .rearSide,
            action: profileStore.activeProfile.assignments[PhysicalButton.rearSide.rawValue]
        )
    }
    
    @ViewBuilder
    private func topViewOverlay(stageSize: CGSize) -> some View {
        // Top View hot spots
        let wheelPos = CGPoint(x: stageSize.width * 0.50, y: stageSize.height * 0.35)
        let wheelCalloutPos = CGPoint(x: stageSize.width * 0.50, y: stageSize.height * 0.16)
        
        Path { path in
            path.move(to: wheelPos)
            path.addLine(to: CGPoint(x: wheelCalloutPos.x, y: wheelCalloutPos.y + 25))
        }
        .stroke(Theme.borderSubtle, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
        
        hotspotDot(pos: wheelPos, button: .middle, isPressed: deviceManager.lastPressedButton == 2)
        
        calloutCard(
            pos: wheelCalloutPos,
            button: .middle,
            action: profileStore.activeProfile.assignments[PhysicalButton.middle.rawValue]
        )
    }
    
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
                .frame(width: 12, height: 12)
                .shadow(color: (isSelected ? Theme.accentCyan : Color.white).opacity(0.8), radius: 6)
        }
        .position(pos)
        .onTapGesture {
            withAnimation(.snappy(duration: 0.2)) {
                selectedButton = button
            }
        }
    }
    
    @ViewBuilder
    private func calloutCard(pos: CGPoint, button: PhysicalButton, action: StoredAction?) -> some View {
        let isSelected = selectedButton == button
        let actionTitle = action?.displayName ?? "Unassigned"
        
        Button(action: {
            withAnimation(.snappy(duration: 0.2)) {
                selectedButton = button
            }
        }) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(button.displayName)
                        .font(Theme.fontSmall)
                        .foregroundColor(Theme.textSecondary)
                    
                    Spacer(minLength: 0)
                    
                    if button == .frontSide {
                        Text("BTN 4")
                            .font(Theme.fontBadge)
                            .foregroundColor(Theme.textMuted)
                    } else if button == .rearSide {
                        Text("BTN 3")
                            .font(Theme.fontBadge)
                            .foregroundColor(Theme.textMuted)
                    } else if button == .middle {
                        Text("BTN 2")
                            .font(Theme.fontBadge)
                            .foregroundColor(Theme.textMuted)
                    }
                }
                
                HStack(spacing: 6) {
                    if action?.type == .wisprFlowPTT {
                        Image(systemName: "mic.fill")
                            .foregroundColor(Theme.accentCyan)
                            .font(.system(size: 11))
                    } else if action?.type == .undo {
                        Image(systemName: "arrow.uturn.backward")
                            .foregroundColor(Theme.statusGreen)
                            .font(.system(size: 11))
                    } else if action?.type == .redo {
                        Image(systemName: "arrow.uturn.forward")
                            .foregroundColor(Theme.statusGreen)
                            .font(.system(size: 11))
                    }
                    
                    Text(actionTitle)
                        .font(Theme.fontHeader)
                        .foregroundColor(isSelected ? Theme.accentCyan : Theme.textPrimary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(width: 210)
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
    }
}
