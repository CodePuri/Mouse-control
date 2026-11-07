import Foundation
import CoreGraphics
import ApplicationServices

// Simple test harness
private var totalTests = 0
private var passedTests = 0
private var failedTests = 0

private func expect(_ condition: Bool, _ testName: String, file: String = #file, line: Int = #line) {
    totalTests += 1
    if condition {
        passedTests += 1
        print("  \u{001B}[32m✓\u{001B}[0m [PASS] \(testName)")
    } else {
        failedTests += 1
        print("  \u{001B}[31m✗\u{001B}[0m [FAIL] \(testName) (at \(file):\(line))")
    }
}

private func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ testName: String, file: String = #file, line: Int = #line) {
    totalTests += 1
    if actual == expected {
        passedTests += 1
        print("  \u{001B}[32m✓\u{001B}[0m [PASS] \(testName)")
    } else {
        failedTests += 1
        print("  \u{001B}[31m✗\u{001B}[0m [FAIL] \(testName): expected '\(expected)', got '\(actual)' (at \(file):\(line))")
    }
}

@main
struct TestPermissionManagerRunner {
    static func main() {
        print("=========================================================")
        print("Running PermissionManager Test Suite (macOS 27 Golden Gate)")
        print("=========================================================")
        
        testDynamicVersionDetection()
        testDynamicTerminology()
        testDeepLinkGeneration()
        testMultiLayerVerification()
        
        print("\n=========================================================")
        print("Test Results: \(passedTests) passed, \(failedTests) failed out of \(totalTests) assertions")
        print("=========================================================")
        if failedTests > 0 {
            exit(1)
        } else {
            print("\u{001B}[32mALL PERMISSION MANAGER TESTS PASSED SUCCESSFULLY!\u{001B}[0m")
            exit(0)
        }
    }
    
    static func testDynamicVersionDetection() {
        print("\n--- Test Suite 1: Dynamic macOS Version Detection ---")
        
        let os = PermissionManager.osVersion
        print("  Detected OS Version: \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)")
        expect(os.majorVersion >= 14, "Supported OS major version >= 14")
        
        if os.majorVersion >= 27 {
            expect(PermissionManager.isMacOS27OrNewer, "Correctly identified as macOS 27 Golden Gate or newer")
            expect(PermissionManager.osDisplayName.contains("Golden Gate"), "OS display name mentions Golden Gate")
        } else {
            expect(!PermissionManager.isMacOS27OrNewer, "Correctly identified as pre-macOS 27")
        }
    }
    
    static func testDynamicTerminology() {
        print("\n--- Test Suite 2: Dynamic Terminology & Settings Path ---")
        
        if PermissionManager.isMacOS27OrNewer {
            expectEqual(PermissionManager.permissionSectionName, "Device Control and Data Access", "Section name is 'Device Control and Data Access' on macOS 27+")
            expectEqual(PermissionManager.permissionSectionShortName, "Device Control", "Short name is 'Device Control'")
            expect(PermissionManager.settingsPathDescription.contains("Device Control and Data Access"), "Settings path contains 'Device Control and Data Access'")
            expect(PermissionManager.recoveryInstructions.contains("Device Control and Data Access"), "Recovery instructions refer to 'Device Control and Data Access'")
        } else {
            expectEqual(PermissionManager.permissionSectionName, "Accessibility", "Section name is 'Accessibility' on older macOS")
            expect(PermissionManager.settingsPathDescription.contains("Accessibility"), "Settings path contains 'Accessibility'")
        }
    }
    
    static func testDeepLinkGeneration() {
        print("\n--- Test Suite 3: Deep Link URLs ---")
        
        let primary = PermissionManager.primarySettingsURL
        print("  Primary Settings Deep Link URL: \(primary.absoluteString)")
        expect(primary.scheme == "x-apple.systempreferences", "URL scheme is x-apple.systempreferences")
        
        let fallbacks = PermissionManager.fallbackSettingsURLs
        expect(!fallbacks.isEmpty, "Fallback URLs list is not empty")
        expect(fallbacks.contains { $0.absoluteString.contains("Privacy_Accessibility") }, "Fallbacks include Privacy_Accessibility")
    }
    
    static func testMultiLayerVerification() {
        print("\n--- Test Suite 4: Multi-Layer Verification (Not Assuming) ---")
        
        let pm = PermissionManager()
        pm.refresh()
        
        print("  Layer 1 (Device Control Trusted): \(pm.deviceControlTrusted)")
        print("  Layer 2 (Input Monitoring Authorized): \(pm.inputMonitoringAuthorized)")
        print("  Layer 3 (Event Posting Authorized): \(pm.eventPostingAuthorized)")
        print("  Layer 4 (Event Tap Functional): \(pm.eventTapFunctional)")
        print("  Combined isFullyAuthorized: \(pm.isFullyAuthorized)")
        
        // Verify layer evaluation logic
        let calculated = pm.deviceControlTrusted && pm.inputMonitoringAuthorized && pm.eventPostingAuthorized && pm.eventTapFunctional
        expectEqual(pm.isFullyAuthorized, calculated, "isFullyAuthorized requires all 4 layers to pass")
        
        // Direct event tap probe
        let probeResult = PermissionManager.verifyEventTapCreation()
        expectEqual(probeResult, pm.eventTapFunctional, "Direct event tap probe matches layer 4 state")
    }
}
