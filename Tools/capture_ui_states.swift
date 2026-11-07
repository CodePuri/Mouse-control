import Foundation
import CoreGraphics
import AppKit

func postClick(at point: CGPoint) {
    let source = CGEventSource(stateID: .combinedSessionState)
    let move = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)
    move?.post(tap: .cghidEventTap)
    usleep(100_000)
    
    let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
    down?.post(tap: .cghidEventTap)
    usleep(150_000)
    
    let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
    up?.post(tap: .cghidEventTap)
    usleep(300_000)
}

func captureWindow(wid: Int, path: String) {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    task.arguments = ["-l\(wid)", path]
    try? task.run()
    task.waitUntilExit()
}

// Window origin is X: 36, Y: 46 (Window height 900, width 1440)
let winX: CGFloat = 36
let winY: CGFloat = 46
let wid = 9943

print("1. Clicking Check Mouse tab...")
postClick(at: CGPoint(x: winX + 38, y: winY + 60 + 20 + 68)) // Check Mouse
captureWindow(wid: wid, path: "ui_evidence/02_check_mouse.png")

print("2. Clicking Settings tab...")
postClick(at: CGPoint(x: winX + 38, y: winY + 60 + 20 + 68 + 68)) // Settings
captureWindow(wid: wid, path: "ui_evidence/03_settings_redesigned.png")

print("3. Clicking Devices tab...")
postClick(at: CGPoint(x: winX + 38, y: winY + 60 + 20 + 20)) // Devices
usleep(300_000)

print("4. Clicking VIEW 1: TOP...")
// Center of stage is winX + 76 + (1440 - 76 - 340)/2 = 36 + 76 + 512 = 624
postClick(at: CGPoint(x: 670, y: winY + 900 - 35))
captureWindow(wid: wid, path: "ui_evidence/04_top_view.png")

print("5. Clicking VIEW 2: SIDE...")
postClick(at: CGPoint(x: 600, y: winY + 900 - 35))
usleep(300_000)

print("6. Clicking Recorder Box to show recording state...")
// Right panel center: winX + 1440 - 170 = 1306
postClick(at: CGPoint(x: 1306, y: winY + 60 + 195))
captureWindow(wid: wid, path: "ui_evidence/05_recording_state.png")

print("Done capturing states.")
