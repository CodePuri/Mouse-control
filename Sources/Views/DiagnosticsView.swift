import SwiftUI
import AppKit

public struct DiagnosticsView: View {
    @ObservedObject var profileStore: ProfileStore
    @ObservedObject var deviceManager: DeviceManager
    
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
                Text("Live input telemetry, receiver hardware descriptors, and guided physical calibration.")
                    .font(Theme.fontSmall)
                    .foregroundColor(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            
            Divider().background(Theme.borderSubtle)
            
            ScrollView {
                VStack(spacing: 20) {
                    // Top Status Grid (4 Tiles)
                    HStack(spacing: 12) {
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
                        
                        statusTile(
                            title: "HARDWARE ACCEPTANCE",
                            value: "Physical Pending",
                            statusColor: Theme.accentPurple,
                            icon: "hand.raised.fill"
                        )
                    }
                    
                    // Hardware Descriptors & Numbering Schemes
                    VStack(alignment: .leading, spacing: 12) {
                        Text("DETECTED RECEIVER HARDWARE & INTERFACES")
                            .font(Theme.fontBadge)
                            .foregroundColor(Theme.textMuted)
                        
                        VStack(spacing: 8) {
                            descriptorRow(label: "Product Name", value: deviceManager.deviceName)
                            descriptorRow(label: "Vendor ID (VID)", value: "\(deviceManager.vendorIdHex) (9354)")
                            descriptorRow(label: "Product ID (PID)", value: "\(deviceManager.productIdHex) (23370)")
                            descriptorRow(label: "Transport Layer", value: deviceManager.transportType)
                            descriptorRow(label: "HID Interfaces", value: "Usage 0xFF01 (Vendor), Usage 2 (Mouse), Usage 6 (Keyboard)")
                            descriptorRow(label: "Observed Status", value: "Verified Active USB Host Device")
                            
                            Divider().background(Theme.borderSubtle).padding(.vertical, 4)
                            
                            descriptorRow(
                                label: "Quartz Numbering",
                                value: "0 = Left, 1 = Right, 2 = Middle, 3 = Rear Side (Back), 4 = Front Side (Forward)"
                            )
                            descriptorRow(
                                label: "HID Usages (Page 0x09)",
                                value: "Usage 0x01 = Btn 1, Usage 0x03 = Btn 3, Usage 0x04 = Btn 4, Usage 0x05 = Btn 5"
                            )
                        }
                        .padding(14)
                        .background(Theme.bgCard)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.borderSubtle, lineWidth: 1))
                    }
                    
                    // Guided Hardware Calibration Section
                    guidedCalibrationSection
                    
                    // Live Event Telemetry Stream
                    liveTelemetrySection
                    
                    // Synthetic Test Trigger Toolbar
                    syntheticPreviewsSection
                }
                .padding(20)
            }
        }
        .background(Theme.bgCanvas)
    }
    
    // MARK: - Guided Calibration Section
    
    private var guidedCalibrationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("GUIDED HARDWARE CALIBRATION (30-SECOND SESSION)")
                        .font(Theme.fontBadge)
                        .foregroundColor(Theme.textMuted)
                    Text("Suspends remapping to record pure physical clicks with positive control verification.")
                        .font(Theme.fontSmall)
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
                
                if deviceManager.calibrationState != .idle {
                    HStack(spacing: 8) {
                        Text("\(deviceManager.calibrationSecondsRemaining)s remaining")
                            .font(Theme.fontBadge)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Theme.statusOrange)
                            .foregroundColor(.black)
                            .cornerRadius(6)
                        
                        Button(action: {
                            deviceManager.cancelCalibration(engine: profileStore.inputEngine)
                        }) {
                            Text("Cancel")
                                .font(Theme.fontSmall)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Theme.bgCardElevated)
                                .foregroundColor(Theme.textMuted)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Button(action: {
                        deviceManager.startCalibration(engine: profileStore.inputEngine)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.circle.fill")
                            Text("Start Guided Calibration")
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
            
            // Calibration Status & Instruction Card
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(calibrationStateColor)
                        .frame(width: 8, height: 8)
                    Text(deviceManager.calibrationState.title)
                        .font(Theme.fontHeader)
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                }
                
                Text(deviceManager.calibrationState.instruction)
                    .font(Theme.fontBody)
                    .foregroundColor(Theme.textSecondary)
                
                // Step Progress Checklist
                if deviceManager.calibrationState != .idle {
                    HStack(spacing: 16) {
                        stepIndicator(
                            number: 1,
                            name: "Positive Control (Middle Click)",
                            isDone: deviceManager.positiveControlObservedButton != nil,
                            isCurrent: deviceManager.calibrationState == .step1_positiveControl
                        )
                        stepIndicator(
                            number: 2,
                            name: "Front Button",
                            isDone: deviceManager.detectedFrontButton != nil,
                            isCurrent: deviceManager.calibrationState == .step2_frontButton
                        )
                        stepIndicator(
                            number: 3,
                            name: "Rear Button",
                            isDone: deviceManager.detectedRearButton != nil,
                            isCurrent: deviceManager.calibrationState == .step3_rearButton
                        )
                    }
                    .padding(.top, 4)
                }
                
                // Completed action options
                if case .completed = deviceManager.calibrationState {
                    HStack(spacing: 10) {
                        Button("Apply Calibrated IDs to Profile") {
                            // Map front and rear buttons in profile
                            profileStore.syncToEngine()
                            deviceManager.calibrationState = .idle
                        }
                        .font(Theme.fontSmall)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.statusGreen)
                        .foregroundColor(.black)
                        .cornerRadius(6)
                        
                        Button("Dismiss") {
                            deviceManager.calibrationState = .idle
                        }
                        .font(Theme.fontSmall)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.bgCardElevated)
                        .foregroundColor(Theme.textSecondary)
                        .cornerRadius(6)
                    }
                    .padding(.top, 6)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.bgCard)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(calibrationStateColor.opacity(0.5), lineWidth: 1)
            )
        }
    }
    
    private var calibrationStateColor: Color {
        switch deviceManager.calibrationState {
        case .idle: return Theme.textMuted
        case .step1_positiveControl, .step2_frontButton, .step3_rearButton: return Theme.statusOrange
        case .completed: return Theme.statusGreen
        case .timedOut: return Theme.statusOrange
        }
    }
    
    @ViewBuilder
    private func stepIndicator(number: Int, name: String, isDone: Bool, isCurrent: Bool) -> some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isDone ? Theme.statusGreen : (isCurrent ? Theme.statusOrange : Theme.bgCardElevated))
                    .frame(width: 20, height: 20)
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.black)
                } else {
                    Text("\(number)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(isCurrent ? .black : Theme.textMuted)
                }
            }
            Text(name)
                .font(Theme.fontSmall)
                .foregroundColor(isDone ? Theme.statusGreen : (isCurrent ? Theme.textPrimary : Theme.textMuted))
        }
    }
    
    // MARK: - Live Telemetry Section
    
    private var liveTelemetrySection: some View {
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
                    Text("Click any mouse button, use Guided Calibration, or preview actions below.")
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
                                .frame(width: 65, alignment: .leading)
                            
                            Text(item.source)
                                .font(Theme.fontBadge)
                                .foregroundColor(item.source.contains("Synthetic") ? Theme.statusOrange : Theme.textSecondary)
                                .frame(width: 110, alignment: .leading)
                            
                            Text(item.buttonName)
                                .font(Theme.fontBadge)
                                .foregroundColor(Theme.accentCyan)
                                .frame(width: 140, alignment: .leading)
                            
                            Text(item.hidEquivalent)
                                .font(Theme.fontBadge)
                                .foregroundColor(Theme.textMuted)
                                .frame(width: 150, alignment: .leading)
                            
                            Text(item.eventPhase)
                                .font(Theme.fontSmall)
                                .foregroundColor(item.eventPhase.contains("Down") ? Theme.statusGreen : Theme.textSecondary)
                                .frame(width: 90, alignment: .leading)
                            
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
    }
    
    // MARK: - Synthetic Previews Section
    
    private var syntheticPreviewsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("SYNTHETIC ACTION PREVIEWS (SIMULATED)")
                    .font(Theme.fontBadge)
                    .foregroundColor(Theme.textMuted)
                Text("— Dispatches simulated keycode sequence for previewing only")
                    .font(Theme.fontSmall)
                    .foregroundColor(Theme.textMuted)
            }
            
            HStack(spacing: 12) {
                Button(action: {
                    profileStore.inputEngine.simulateAction(.wisprFlowPTT(keyCode: 61))
                    deviceManager.recordEvent(
                        source: "Synthetic Preview",
                        button: 4,
                        phase: "Down/Up",
                        actionDesc: "Wispr Flow PTT (Keycode 61 Right Option)",
                        suppressed: true
                    )
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "mic.fill")
                        Text("Preview Wispr Flow PTT (⌥)")
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
                    deviceManager.recordEvent(
                        source: "Synthetic Preview",
                        button: 3,
                        phase: "Down/Up",
                        actionDesc: "Undo (⌘Z)",
                        suppressed: true
                    )
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward")
                        Text("Preview Undo (⌘Z)")
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
                    deviceManager.recordEvent(
                        source: "Synthetic Preview",
                        button: 4,
                        phase: "Down/Up",
                        actionDesc: "Redo (⇧⌘Z)",
                        suppressed: true
                    )
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.forward")
                        Text("Preview Redo (⇧⌘Z)")
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
    
    // MARK: - Helpers
    
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
                .frame(width: 170, alignment: .leading)
            Text(value)
                .font(Theme.fontBody)
                .foregroundColor(Theme.textPrimary)
            Spacer()
        }
    }
}
