import AppKit

extension SpectrePro.SurfaceView {
    static let dropTypes: Set<NSPasteboard.PasteboardType> = [.string, .fileURL]

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard let types = sender.draggingPasteboard.types,
              !Set(types).isDisjoint(with: Self.dropTypes) else { return [] }
        return .copy
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        if SSHTransferManager.shared.hasActiveSSHContext(for: id),
           let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           !fileURLs.isEmpty,
           fileURLs.contains(where: \.isFileURL) {
            SSHTransferManager.shared.uploadFiles(fileURLs, surface: self)
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
                SSHTransferManager.shared.uploadFiles(panel.urls, surface: self)
            }
        } else if panel.runModal() == .OK {
            SSHTransferManager.shared.uploadFiles(panel.urls, surface: self)
        }
    }

    @objc func downloadSelectedFileFromSSH(_ sender: Any?) {
        guard let path = accessibilitySelectedText()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else { return }
        SSHTransferManager.shared.downloadFile(remotePath: path, surface: self)
    }

    public func readVisibleText() -> String {
        cachedVisibleContents.get()
    }

    public func readScreenText() -> String {
        cachedScreenContents.get()
    }
}
