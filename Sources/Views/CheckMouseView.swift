import SwiftUI
import AppKit

public struct CheckMouseView: View {
    @ObservedObject var profileStore: ProfileStore
    @ObservedObject var deviceManager: DeviceManager
    
    public init(profileStore: ProfileStore, deviceManager: DeviceManager) {
        self.profileStore = profileStore
        self.deviceManager = deviceManager
    }
    
    private var isConnected: Bool {
        deviceManager.isReceiverConnected
    }
    
    private var hasPressedAnyButton: Bool {
        deviceManager.lastPressedButton != nil
    }
    
    private var detectedSideButtonName: String? {
        if deviceManager.detectedFrontButton == 4 || deviceManager.lastPressedButton == 4 {
            return "Front Side Button (Button 4)"
        }
        if deviceManager.detectedRearButton == 3 || deviceManager.lastPressedButton == 3 {
            return "Rear Side Button (Button 3)"
        }
        if let btn = deviceManager.lastPressedButton {
            return "Mouse Button \(btn)"
        }
        return nil
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Check My Mouse")
                        .font(Theme.fontTitle)
                        .foregroundColor(Theme.textPrimary)
                    
                    Text("Follow the 3-step checklist below to verify your Kreo Chimera V2 hardware connection and side button inputs.")
                        .font(Theme.fontBody)
                        .foregroundColor(Theme.textSecondary)
                }
                
                // 3-Step Verification Checklist Cards
                VStack(spacing: 16) {
                    // Step 1: Mouse Connected
                    checklistCard(
                        stepNumber: "1",
                        title: "Mouse Connected",
                        statusText: isConnected ? "Connected via 2.4GHz Wireless Dongle" : "Searching for Kreo Receiver...",
                        isPassed: isConnected,
                        detail: "Hardware ID: 0x248a:0x5b4a (Kreo Chimera V2 Wireless Receiver)",
                        icon: "antenna.radiowaves.left.and.right"
                    )
                    
                    // Step 2: Press a Side Button
                    step2PressCard
                    
                    // Step 3: Button Ready
                    checklistCard(
                        stepNumber: "3",
                        title: "Button Ready & Remapped",
                        statusText: step3StatusText,
                        isPassed: (deviceManager.detectedFrontButton != nil || deviceManager.detectedRearButton != nil),
                        detail: step3DetailText,
                        icon: "bolt.fill"
                    )
                }
                
                // Troubleshooting Card
                troubleshootingCard
            }
            .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bgCanvas)
    }
    
    // MARK: - Step 2 Card (Interactive Button Press)
    
    private var step2PressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(hasPressedAnyButton ? Theme.statusGreen.opacity(0.2) : Theme.bgCardElevated)
                        .frame(width: 36, height: 36)
                    
                    if hasPressedAnyButton {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Theme.statusGreen)
                    } else {
                        Text("2")
                            .font(Theme.fontHeader)
                            .foregroundColor(Theme.accentCyan)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Press a Side Button")
                        .font(Theme.fontHeader)
                        .foregroundColor(Theme.textPrimary)
                    
                    Text("Click the front or rear purple side button on your mouse to verify macOS receives the click.")
                        .font(Theme.fontSmall)
                        .foregroundColor(Theme.textSecondary)
                }
                
                Spacer()
                
                // Live Input Beacon
                HStack(spacing: 8) {
                    Circle()
                        .fill(hasPressedAnyButton ? Theme.accentCyan : Theme.borderSubtle)
                        .frame(width: 10, height: 10)
                        .scaleEffect(hasPressedAnyButton ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: hasPressedAnyButton)
                    
                    Text(hasPressedAnyButton ? "SIGNAL DETECTED" : "LISTENING...")
                        .font(Theme.fontBadge)
                        .foregroundColor(hasPressedAnyButton ? Theme.accentCyan : Theme.textMuted)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Theme.bgCanvas)
                .cornerRadius(6)
            }
            
            // Real-time button report strip
            HStack(spacing: 12) {
                if let name = detectedSideButtonName {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.accentCyan)
                        Text("Last received: \(name)")
                            .font(Theme.fontSmall)
                            .foregroundColor(Theme.textPrimary)
                    }
                } else {
                    Text("Awaiting first physical button click from your mouse...")
                        .font(Theme.fontSmall)
                        .foregroundColor(Theme.textMuted)
                }
                
                Spacer()
                
                if let btn = deviceManager.lastPressedButton {
                    Text("Raw Button ID: \(btn)")
                        .font(Theme.fontBadge)
                        .foregroundColor(Theme.textMuted)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.bgCanvas)
            .cornerRadius(6)
        }
        .padding(18)
        .background(Theme.bgCard)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(hasPressedAnyButton ? Theme.accentCyan.opacity(0.4) : Theme.borderSubtle, lineWidth: 1)
        )
    }
    
    // MARK: - Step 3 Status Strings
    
    private var step3StatusText: String {
        if let front = deviceManager.detectedFrontButton, let rear = deviceManager.detectedRearButton {
            return "Both Side Buttons (Btn \(front) & Btn \(rear)) physically calibrated!"
        } else if let front = deviceManager.detectedFrontButton {
            return "Front button (Btn \(front)) verified. Press rear button next."
        } else if let rear = deviceManager.detectedRearButton {
            return "Rear button (Btn \(rear)) verified. Press front button next."
        } else {
            return "Awaiting side button verification"
        }
    }
    
    private var step3DetailText: String {
        let frontAction = profileStore.activeProfile.assignments[PhysicalButton.frontSide.rawValue]?.displayName ?? "Wispr Flow PTT"
        let rearAction = profileStore.activeProfile.assignments[PhysicalButton.rearSide.rawValue]?.displayName ?? "Undo"
        return "Configured mappings: Front -> \(frontAction) | Rear -> \(rearAction)"
    }
    
    // MARK: - Generic Checklist Card
    
    @ViewBuilder
    private func checklistCard(
        stepNumber: String,
        title: String,
        statusText: String,
        isPassed: Bool,
        detail: String,
        icon: String
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(isPassed ? Theme.statusGreen.opacity(0.2) : Theme.bgCardElevated)
                    .frame(width: 36, height: 36)
                
                if isPassed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Theme.statusGreen)
                } else {
                    Text(stepNumber)
                        .font(Theme.fontHeader)
                        .foregroundColor(Theme.accentCyan)
                }
            }
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(Theme.fontHeader)
                        .foregroundColor(Theme.textPrimary)
                    
                    if isPassed {
                        Text("ACTIVE")
                            .font(Theme.fontBadge)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.statusGreen.opacity(0.2))
                            .foregroundColor(Theme.statusGreen)
                            .cornerRadius(4)
                    }
                }
                
                Text(statusText)
                    .font(Theme.fontBody)
                    .foregroundColor(isPassed ? Theme.textPrimary : Theme.textSecondary)
                
                Text(detail)
                    .font(Theme.fontSmall)
                    .foregroundColor(Theme.textMuted)
            }
            
            Spacer()
            
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(isPassed ? Theme.statusGreen : Theme.textMuted)
                .padding(.trailing, 8)
        }
        .padding(18)
        .background(Theme.bgCard)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isPassed ? Theme.statusGreen.opacity(0.3) : Theme.borderSubtle, lineWidth: 1)
        )
    }
    
    // MARK: - Troubleshooting Card (Actionable & Honest)
    
    private var troubleshootingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Theme.statusOrange)
                
                Text("Side Buttons Not Registering?")
                    .font(Theme.fontHeader)
                    .foregroundColor(Theme.textPrimary)
                
                Spacer()
                
                Text("HARDWARE DIAGNOSTIC")
                    .font(Theme.fontBadge)
                    .foregroundColor(Theme.statusOrange)
            }
            
            Text("Your Kreo USB receiver is detected, but macOS has not yet observed auxiliary button events across the 2.4GHz wireless link. The receiver's mouse HID interface exposes 3 buttons (Left, Right, Scroll Click). Follow these steps:")
                .font(Theme.fontSmall)
                .foregroundColor(Theme.textSecondary)
                .lineSpacing(3)
            
            VStack(alignment: .leading, spacing: 8) {
                diagnosticTip(
                    num: "1",
                    title: "Check Mouse Power & Wireless Switch",
                    body: "Flip the mouse over and ensure the switch is set to 2.4GHz wireless mode (not Bluetooth or OFF)."
                )
                
                diagnosticTip(
                    num: "2",
                    title: "Test with USB-C Cable (Wired Mode)",
                    body: "Connect the Kreo mouse directly via its USB-C cable. Many gaming mice only transmit auxiliary buttons 4 and 5 in wired mode until onboard memory is configured."
                )
                
                diagnosticTip(
                    num: "3",
                    title: "Bring Mouse Closer to Receiver",
                    body: "Ensure the mouse is within 1 meter of the USB receiver to prevent 2.4GHz packet drop."
                )
                
                diagnosticTip(
                    num: "4",
                    title: "Check Accessibility Permissions",
                    body: "Ensure MouseControl is granted Accessibility permissions in System Settings -> Privacy & Security -> Accessibility."
                )
            }
            
            HStack {
                Spacer()
                Text("For raw telemetry, HID report descriptors, and logs, visit Settings -> Advanced.")
                    .font(Theme.fontSmall)
                    .foregroundColor(Theme.textMuted)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .background(Theme.bgCardElevated)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.statusOrange.opacity(0.3), lineWidth: 1))
    }
    
    @ViewBuilder
    private func diagnosticTip(num: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(num)
                .font(Theme.fontBadge)
                .foregroundColor(Theme.accentCyan)
                .frame(width: 18, height: 18)
                .background(Theme.bgCard)
                .cornerRadius(9)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.fontHeader)
                    .foregroundColor(Theme.textPrimary)
                
                Text(body)
                    .font(Theme.fontSmall)
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }
}
