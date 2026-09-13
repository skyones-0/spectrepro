import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    func show(appDelegate: AppDelegate) {
        if window == nil {
            let contentView = NSHostingView(
                rootView: SettingsView().environmentObject(appDelegate)
            )
            let settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 760, height: 580),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow.title = "Spectre Pro Settings"
            settingsWindow.contentView = contentView
            settingsWindow.minSize = NSSize(width: 680, height: 500)
            settingsWindow.center()
            window = settingsWindow
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
