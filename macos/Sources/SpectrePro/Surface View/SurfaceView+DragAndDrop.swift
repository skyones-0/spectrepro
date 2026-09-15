import AppKit

extension SpectrePro.SurfaceView {
    @objc func openSFTPBrowser(_ sender: Any?) {
        NotificationCenter.default.post(
            name: .spectreproOpenSFTPBrowser,
            object: self,
            userInfo: ["surfaceUUID": id]
        )
    }

    static let dropTypes: Set<NSPasteboard.PasteboardType> = [.string, .fileURL]

    private var sessionTransferManager: SSHTransferManager {
        SessionRuntimeRegistry.shared.runtime(for: id).transfers
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard let types = sender.draggingPasteboard.types,
              !Set(types).isDisjoint(with: Self.dropTypes) else { return [] }
        return .copy
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        if sessionTransferManager.hasActiveSSHContext(for: id),
           let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           !fileURLs.isEmpty,
           fileURLs.contains(where: \.isFileURL) {
            sessionTransferManager.uploadFiles(fileURLs, surface: self)
            return true
        }

        guard let content = pasteboard.getOpinionatedStringContents() else { return false }
        DispatchQueue.main.async {
            self.surfaceModel?.sendText(content)
        }
        return true
    }

    @objc func uploadFileToSSH(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Upload to Server"
        panel.message = "Choose files to upload to the active SSH session"

        if let window {
            panel.beginSheetModal(for: window) { [weak self] response in
                guard let self, response == .OK else { return }
                sessionTransferManager.uploadFiles(panel.urls, surface: self)
            }
        } else if panel.runModal() == .OK {
            sessionTransferManager.uploadFiles(panel.urls, surface: self)
        }
    }

    @objc func downloadSelectedFileFromSSH(_ sender: Any?) {
        guard let path = accessibilitySelectedText()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else { return }
        sessionTransferManager.downloadFile(remotePath: path, surface: self)
    }

    public func readVisibleText() -> String {
        cachedVisibleContents.get()
    }

    public func readScreenText() -> String {
        cachedScreenContents.get()
    }
}
