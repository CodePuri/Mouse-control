import Foundation
import CoreGraphics
import AppKit

var logFileHandle: FileHandle?

func myLog(_ msg: String) {
    let ts = ISO8601DateFormatter().string(from: Date())
    let line = "[\(ts)] \(msg)\n"
    if let data = line.data(using: .utf8) {
        logFileHandle?.write(data)
    }
    print(line, terminator: "")
    fflush(stdout)
}

let eventCallback: CGEventTapCallBack = { proxy, type, event, refcon in
    let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
    let clickState = event.getIntegerValueField(.mouseEventClickState)
    let flags = event.flags.rawValue
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    
    switch type {
    case .leftMouseDown:
        myLog("MOUSE_DOWN button=0 (left) clickState=\(clickState)")
    case .leftMouseUp:
        myLog("MOUSE_UP button=0 (left)")
    case .rightMouseDown:
        myLog("MOUSE_DOWN button=1 (right) clickState=\(clickState)")
    case .rightMouseUp:
        myLog("MOUSE_UP button=1 (right)")
    case .otherMouseDown:
        myLog("MOUSE_DOWN button=\(buttonNumber) (other) clickState=\(clickState)")
    case .otherMouseUp:
        myLog("MOUSE_UP button=\(buttonNumber) (other)")
    case .keyDown:
        myLog("KEY_DOWN keyCode=\(keyCode) flags=0x\(String(flags, radix: 16))")
    case .keyUp:
        myLog("KEY_UP keyCode=\(keyCode)")
    default:
        break
    }
    return Unmanaged.passRetained(event)
}

let logPath = "/tmp/kreo_button_log.txt"
FileManager.default.createFile(atPath: logPath, contents: nil)
logFileHandle = FileHandle(forWritingAtPath: logPath)

myLog("Button logger initialized. Listening for mouse and keyboard events...")

let mask = (1 << CGEventType.leftMouseDown.rawValue) |
           (1 << CGEventType.leftMouseUp.rawValue) |
           (1 << CGEventType.rightMouseDown.rawValue) |
           (1 << CGEventType.rightMouseUp.rawValue) |
           (1 << CGEventType.otherMouseDown.rawValue) |
           (1 << CGEventType.otherMouseUp.rawValue) |
           (1 << CGEventType.keyDown.rawValue) |
           (1 << CGEventType.keyUp.rawValue)

guard let tap = CGEvent.tapCreate(
    tap: .cghidEventTap,
    place: .headInsertEventTap,
    options: .listenOnly,
    eventsOfInterest: CGEventMask(mask),
    callback: eventCallback,
    userInfo: nil
) else {
    myLog("ERROR: Failed to create event tap!")
    exit(1)
}

let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)
CFRunLoopRun()
