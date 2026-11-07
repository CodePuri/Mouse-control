import SwiftUI
import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        
        let contentView = MainWindowView()
            .preferredColorScheme(.dark)
            .frame(minWidth: 1100, minHeight: 720)
        
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1440, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.minSize = NSSize(width: 1100, height: 720)
        win.title = "Kreo Chimera V2 Configurator"
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.isMovableByWindowBackground = true
        win.backgroundColor = NSColor(red: 11/255, green: 13/255, blue: 16/255, alpha: 1.0)
        win.contentView = NSHostingView(rootView: contentView)
        win.center()
        win.makeKeyAndOrderFront(nil)
        
        self.window = win
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
