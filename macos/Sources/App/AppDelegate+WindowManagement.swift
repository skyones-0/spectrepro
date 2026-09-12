import AppKit

extension AppDelegate {
    func syncFloatOnTopMenu(_ window: NSWindow?) {
        guard let window = (window ?? NSApp.keyWindow) as? TerminalWindow else {
            floatingMenuItem?.state = .off
            return
        }

        floatingMenuItem?.state = window.level == .floating ? .on : .off
    }

    @IBAction func floatOnTop(_ menuItem: NSMenuItem) {
        menuItem.state = menuItem.state == .on ? .off : .on
        guard let window = NSApp.keyWindow else { return }
        window.level = menuItem.state == .on ? .floating : .normal
    }

    @IBAction func useAsDefault(_ sender: NSMenuItem) {
        let userDefaults = UserDefaults.spectrepro
        let key = TerminalWindow.defaultLevelKey
        if floatingMenuItem?.state == .on {
            userDefaults.set(NSWindow.Level.floating, forKey: key)
        } else {
            userDefaults.removeObject(forKey: key)
        }
    }

    @IBAction func setAsDefaultTerminal(_ sender: NSMenuItem) {
        NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpen: .unixExecutable) { error in
            guard let error else { return }
            Task { @MainActor in
                let alert = NSAlert()
                alert.messageText = "Failed to Set Default Terminal"
                alert.informativeText = """
                SpectrePro could not be set as the default terminal application.

                Error: \(error.localizedDescription)
                """
                alert.alertStyle = .warning
                alert.runModal()
            }
        }
    }
}
