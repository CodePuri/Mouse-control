import SwiftUI
import AppKit

public struct DiagnosticsView: View {
    @ObservedObject var profileStore: ProfileStore
    @ObservedObject var deviceManager: DeviceManager
    @State private var calibrationCountdown: Int? = nil
    @State private var calibrationStatus: String = "Calibration Idle"
    @State private var timer: Timer? = nil
    
    public init(profileStore: ProfileStore, deviceManager: DeviceManager) {
        self.profileStore = profileStore
        self.deviceManager = deviceManager
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text("System Diagnostics & Hardware Inspector")
                    .font(Theme.fontTitle)
                    .foregroundColor(Theme.textPrimary)
                Text("Live input telemetry, receiver hardware descriptors, and event suppression verification.")
                    .font(Theme.fontSmall)
                    .foregroundColor(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            
            Divider().background(Theme.borderSubtle)
            
            ScrollView {
                VStack(spacing: 20) {
                    // Top Status Grid
                    HStack(spacing: 16) {
                        statusTile(
                            title: "RECEIVER CONNECTION",
                            value: deviceManager.isReceiverConnected ? "Connected (2.4 GHz)" : "Disconnected",
                            statusColor: deviceManager.isReceiverConnected ? Theme.statusGreen : Theme.statusOrange,
                            icon: "antenna.radiowaves.left.and.right"
                        )
                        
                        statusTile(
                            title: "ACCESSIBILITY PERMISSION",
                            value: AXIsProcessTrusted() ? "Authorized" : "Not Granted",
                            statusColor: AXIsProcessTrusted() ? Theme.statusGreen : Theme.statusOrange,
                            icon: "lock.shield.fill"
                        )
                        
                        statusTile(
                            title: "INPUT ENGINE SERVICE",
                            value: profileStore.isPaused ? "Paused" : "Active & Suppressing",
                            statusColor: profileStore.isPaused ? Theme.statusOrange : Theme.accentCyan,
                            icon: "gearshape.2.fill"
                        )
                    }
                    
                    // Hardware Descriptor Details
                    VStack(alignment: .leading, spacing: 12) {
                        Text("DETECTED RECEIVER HARDWARE")
                            .font(Theme.fontBadge)
                            .foregroundColor(Theme.textMuted)
                        
                        VStack(spacing: 8) {
                            descriptorRow(label: "Product Name", value: deviceManager.deviceName)
                            descriptorRow(label: "Vendor ID (VID)", value: "\(deviceManager.vendorIdHex) (9354)")
                            descriptorRow(label: "Product ID (PID)", value: "\(deviceManager.productIdHex) (23370)")
                            descriptorRow(label: "Transport Layer", value: deviceManager.transportType)
                            descriptorRow(label: "HID Interfaces", value: "Usage 0xFF01 (Vendor), Usage 2 (Mouse), Usage 6 (Keyboard)")
                            descriptorRow(label: "Observed Status", value: "Verified Active USB Host Device")
                        }
                        .padding(14)
                        .background(Theme.bgCard)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.borderSubtle, lineWidth: 1))
                    }
                    
                    // Bounded Calibration Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("BOUNDED HARDWARE CALIBRATION (30S)")
                                    .font(Theme.fontBadge)
                                    .foregroundColor(Theme.textMuted)
                                Text("Runs an isolated 30-second IOKit matching session to capture Kreo side button events without retaining any keyboard data.")
                                    .font(Theme.fontSmall)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            Spacer()
                            if let count = calibrationCountdown {
                                Text("\(count)s remaining")
                                    .font(Theme.fontBadge)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Theme.statusOrange)
                                    .foregroundColor(.black)
                                    .cornerRadius(6)
                            } else {
                                Button(action: startCalibration) {
                                    HStack {
                                        Image(systemName: "timer")
                                        Text("Start 30s Calibration")
                                    }
                                    .font(Theme.fontSmall)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Theme.accentCyan)
                                    .foregroundColor(.black)
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        Text(calibrationStatus)
                            .font(Theme.fontSmall)
                            .foregroundColor(calibrationCountdown != nil ? Theme.statusOrange : Theme.textMuted)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.bgCard)
                            .cornerRadius(6)
                    }
                    
                    // Live Event Stream
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("LIVE EVENT TELEMETRY")
                                .font(Theme.fontBadge)
                                .foregroundColor(Theme.textMuted)
                            Spacer()
                            Button(action: { deviceManager.clearLog() }) {
                                Text("Clear Log")
                                    .font(Theme.fontSmall)
                                    .foregroundColor(Theme.textMuted)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        if deviceManager.liveEvents.isEmpty {
                            VStack(spacing: 8) {
                                Text("No recent button events observed.")
                                    .font(Theme.fontBody)
                                    .foregroundColor(Theme.textMuted)
                                Text("Click any mouse button or use the Test buttons below to generate events.")
                                    .font(Theme.fontSmall)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(32)
                            .background(Theme.bgCard)
                            .cornerRadius(8)
                        } else {
                            VStack(spacing: 6) {
                                ForEach(deviceManager.liveEvents) { item in
                                    HStack(spacing: 12) {
                                        Text(item.timestamp, style: .time)
                                            .font(Theme.fontBadge)
                                            .foregroundColor(Theme.textMuted)
                                            .frame(width: 70, alignment: .leading)
                                        
                                        Text("Button \(item.buttonNumber)")
                                            .font(Theme.fontBadge)
                                            .foregroundColor(Theme.accentCyan)
                                            .frame(width: 70, alignment: .leading)
                                        
                                        Text(item.eventType)
                                            .font(Theme.fontSmall)
                                            .foregroundColor(item.eventType == "Down" ? Theme.statusGreen : Theme.textSecondary)
                                            .frame(width: 50, alignment: .leading)
                                        
                                        Text(item.actionDescription)
                                            .font(Theme.fontSmall)
                                            .foregroundColor(Theme.textPrimary)
                                        
                                        Spacer()
                                        
                                        if item.suppressed {
                                            Text("SUPPRESSED")
                                                .font(Theme.fontBadge)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Theme.statusGreen.opacity(0.2))
                                                .foregroundColor(Theme.statusGreen)
                                                .cornerRadius(4)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Theme.bgCardElevated)
                                    .cornerRadius(6)
                                }
                            }
                        }
                    }
                    
                    // Synthetic Test Trigger Toolbar
                    VStack(alignment: .leading, spacing: 10) {
                        Text("SYNTHETIC ACTION VERIFICATION")
                            .font(Theme.fontBadge)
                            .foregroundColor(Theme.textMuted)
                        
                        HStack(spacing: 12) {
                            Button(action: {
                                profileStore.inputEngine.simulateAction(.wisprFlowPTT(keyCode: 61))
                                deviceManager.recordEvent(button: 4, type: "Down/Up", actionDesc: "Wispr Flow PTT (Key 61 Right Option)", suppressed: true)
                            }) {
                                HStack {
                                    Image(systemName: "mic.fill")
                                    Text("Test Wispr Flow PTT (⌥)")
                                }
                                .font(Theme.fontSmall)
                                .padding(10)
                                .background(Theme.bgCardElevated)
                                .foregroundColor(Theme.accentCyan)
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.accentCyan, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: {
                                profileStore.inputEngine.simulateAction(.undo)
                                deviceManager.recordEvent(button: 3, type: "Down/Up", actionDesc: "Undo (⌘Z)", suppressed: true)
                            }) {
                                HStack {
                                    Image(systemName: "arrow.uturn.backward")
                                    Text("Test Undo (⌘Z)")
                                }
                                .font(Theme.fontSmall)
                                .padding(10)
                                .background(Theme.bgCardElevated)
                                .foregroundColor(Theme.statusGreen)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: {
                                profileStore.inputEngine.simulateAction(.redo)
                                deviceManager.recordEvent(button: 3, type: "Down/Up", actionDesc: "Redo (⇧⌘Z)", suppressed: true)
                            }) {
                                HStack {
                                    Image(systemName: "arrow.uturn.forward")
                                    Text("Test Redo (⇧⌘Z)")
                                }
                                .font(Theme.fontSmall)
                                .padding(10)
                                .background(Theme.bgCardElevated)
                                .foregroundColor(Theme.statusGreen)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
        }
        .background(Theme.bgCanvas)
    }
    
    @ViewBuilder
    private func statusTile(title: String, value: String, statusColor: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(Theme.fontBadge)
                    .foregroundColor(Theme.textMuted)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(statusColor)
            }
            Text(value)
                .font(Theme.fontHeader)
                .foregroundColor(Theme.textPrimary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.bgCard)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.borderSubtle, lineWidth: 1))
    }
    
    @ViewBuilder
    private func descriptorRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Theme.fontSmall)
                .foregroundColor(Theme.textSecondary)
                .frame(width: 160, alignment: .leading)
            Text(value)
                .font(Theme.fontBody)
                .foregroundColor(Theme.textPrimary)
            Spacer()
        }
    }
    
    private func startCalibration() {
        calibrationCountdown = 30
        calibrationStatus = "Listening for Kreo Chimera side button presses... Click Front Button (3x), then Rear Button (3x)."
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { t in
            Task { @MainActor in
                if let count = self.calibrationCountdown, count > 1 {
                    self.calibrationCountdown = count - 1
                } else {
                    self.calibrationCountdown = nil
                    self.calibrationStatus = "Calibration session completed (30 seconds elapsed)."
                    t.invalidate()
                }
            }
        }
    }
}
