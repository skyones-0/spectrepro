import AppKit

extension AppDelegate {
    func terminate() -> NSApplication.TerminateReply {
        let controllersNeedConfirmation = NSApplication.shared.windows
            .compactMap { $0.windowController as? BaseTerminalController }
            .filter { !$0.windowCanBeClosedWithoutConfirmation() }

        guard !controllersNeedConfirmation.isEmpty else { return .terminateNow }

        if controllersNeedConfirmation.count == 1 {
            Task {
                let response = await controllersNeedConfirmation[0].confirmCloseAsync(
                    messageText: "Quit SpectrePro?",
                    informativeText: "The terminal still has a running process. If you quit, the process will be killed.",
                    confirmButtonTitle: "Terminate"
                )
                await NSApp.reply(toApplicationShouldTerminate: [.OK, .alertFirstButtonReturn].contains(response))
            }
            return .terminateLater
        }

        let alert = NSAlert.reviewWindowsAlert(
            messageText: "You have \(controllersNeedConfirmation.count) windows with running processes. Do you want to review these windows before quitting?"
        )
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            reviewWindows(controllersNeedConfirmation)
            return .terminateLater
        case .alertSecondButtonReturn:
            return .terminateNow
        default:
            return .terminateCancel
        }
    }

    private func reviewWindows(_ controllers: [BaseTerminalController]) {
        Task {
            for controller in controllers {
                let response = await controller.confirmCloseAsync(
                    messageText: "Quit SpectrePro?",
                    informativeText: "The terminal still has a running process. If you quit, the process will be killed.",
                    confirmButtonTitle: "Terminate"
                )
                guard [.OK, .alertFirstButtonReturn].contains(response) else {
                    await NSApp.reply(toApplicationShouldTerminate: false)
                    return
                }
                await controller.window?.close()
            }
            await NSApp.reply(toApplicationShouldTerminate: true)
        }
    }
}
