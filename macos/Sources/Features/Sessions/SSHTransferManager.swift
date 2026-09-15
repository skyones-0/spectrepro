import SwiftUI
import AppKit

public struct FileTransferProgress: Identifiable, Equatable {
    public var id = UUID()
    public var fileName: String
    public var isUpload: Bool
    public var percentage: Double // 0.0 ... 1.0
    public var detailText: String

    public init(id: UUID = UUID(), fileName: String, isUpload: Bool, percentage: Double, detailText: String) {
        self.id = id
        self.fileName = fileName
        self.isUpload = isUpload
        self.percentage = percentage
        self.detailText = detailText
    }
}

public struct CompletedTransferToast: Identifiable, Equatable {
    public var id = UUID()
    public var fileName: String
    public var isUpload: Bool
    public var localURL: URL
    public var remotePath: String

    public init(id: UUID = UUID(), fileName: String, isUpload: Bool, localURL: URL, remotePath: String) {
        self.id = id
        self.fileName = fileName
        self.isUpload = isUpload
        self.localURL = localURL
        self.remotePath = remotePath
    }
}

public enum TransferStatus: String, Codable, Equatable, Sendable {
    case pending
    case inProgress
    case completed
    case failed
    case cancelled
}

public struct QueuedTransfer: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var fileName: String
    public var localPath: String
    public var remotePath: String
    public var isUpload: Bool
    public var priority: Int // Higher value = higher priority
    public var status: TransferStatus
    public var retryCount: Int
    public var maxRetries: Int
    public var errorMessage: String?
    public var createdAt: Date
    public var completedAt: Date?
    public var surfaceId: UUID?

    public init(
        id: UUID = UUID(),
        fileName: String,
        localPath: String,
        remotePath: String,
        isUpload: Bool,
        priority: Int = 0,
        status: TransferStatus = .pending,
        retryCount: Int = 0,
        maxRetries: Int = 3,
        errorMessage: String? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        surfaceId: UUID? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.localPath = localPath
        self.remotePath = remotePath
        self.isUpload = isUpload
        self.priority = priority
        self.status = status
        self.retryCount = retryCount
        self.maxRetries = maxRetries
        self.errorMessage = errorMessage
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.surfaceId = surfaceId
    }
}

public struct HostKeyAlert: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public var host: String
    public var message: String
    public var offendingLine: String?
    public var isMismatch: Bool

    public init(host: String, message: String, offendingLine: String? = nil, isMismatch: Bool = false) {
        self.host = host
        self.message = message
        self.offendingLine = offendingLine
        self.isMismatch = isMismatch
    }
}

public struct ActiveSSHContext: Equatable {
    public var host: String
    public var user: String?
    public var port: Int?
    public var identityFile: String?
    public var sshAuthentication: SSHAuthenticationMethod
    public var pkcs11Provider: String?
    public var sshExecutable: String
    public var jumpHost: String?
    public var controlPath: String

    public init(
        host: String,
        user: String? = nil,
        port: Int? = 22,
        identityFile: String? = nil,
        sshAuthentication: SSHAuthenticationMethod = .automatic,
        pkcs11Provider: String? = nil,
        jumpHost: String? = nil
    ) {
        self.host = host
        self.user = user
        self.port = port
        self.identityFile = identityFile
        self.sshAuthentication = sshAuthentication
        self.pkcs11Provider = pkcs11Provider
        self.sshExecutable = YubiKeyDetector.sshExecutable(for: sshAuthentication)
        self.jumpHost = jumpHost
        self.controlPath = "/tmp/spectre-ssh-%C.sock"
    }

    public var targetSpec: String {
        if let u = user, !u.isEmpty {
            return "\(u)@\(host)"
        }
        return host
    }

    public var scpExecutable: String {
        siblingExecutable(named: "scp")
    }

    public var sftpExecutable: String {
        siblingExecutable(named: "sftp")
    }

    private func siblingExecutable(named name: String) -> String {
        let sibling = URL(fileURLWithPath: sshExecutable).deletingLastPathComponent().appendingPathComponent(name).path
        return FileManager.default.isExecutableFile(atPath: sibling) ? sibling : "/usr/bin/\(name)"
    }

    public var connectionOptions: [String] {
        [
            "-o", "StrictHostKeyChecking=ask",
            "-o", "UserKnownHostsFile=\(("~/.ssh/known_hosts" as NSString).expandingTildeInPath)",
            "-o", "ServerAliveInterval=15",
            "-o", "ServerAliveCountMax=3",
            "-o", "ConnectionAttempts=3",
            "-o", "ConnectTimeout=10"
        ]
    }

    public func buildBaseSCPArguments() -> [String] {
        var args = connectionOptions + [
            "-o", "ControlMaster=auto",
            "-o", "ControlPath=\(controlPath)",
            "-o", "ControlPersist=10m"
        ]

        if let p = port, p != 22 {
            args += ["-P", "\(p)"]
        }
        if sshAuthentication == .yubikeyPIV, let provider = pkcs11Provider, !provider.isEmpty {
            args += ["-I", (provider as NSString).expandingTildeInPath]
        } else if let key = identityFile, !key.isEmpty {
            let expanded = (key as NSString).expandingTildeInPath
            args += ["-i", expanded]
        }
        if let jump = jumpHost, !jump.isEmpty {
            args += ["-J", jump]
        }
        return args
    }

    public func buildBaseSFTPArguments() -> [String] {
        var args = connectionOptions + [
            "-o", "ControlMaster=auto",
            "-o", "ControlPath=\(controlPath)",
            "-o", "ControlPersist=10m"
        ]
        if let p = port, p != 22 { args += ["-P", "\(p)"] }
        if sshAuthentication == .yubikeyPIV, let provider = pkcs11Provider, !provider.isEmpty {
            args += ["-I", (provider as NSString).expandingTildeInPath]
        } else if let key = identityFile, !key.isEmpty {
            args += ["-i", (key as NSString).expandingTildeInPath]
        }
        if let jump = jumpHost, !jump.isEmpty { args += ["-o", "ProxyJump=\(jump)"] }
        args.append(targetSpec)
        return args
    }

    public static func escapeRemotePath(_ path: String) -> String {
        // Escape spaces and quotes for remote shell parsing
        var escaped = path.replacingOccurrences(of: "\\", with: "\\\\")
        escaped = escaped.replacingOccurrences(of: "\"", with: "\\\"")
        escaped = escaped.replacingOccurrences(of: " ", with: "\\ ")
        return escaped
    }
}

private final class TransferDiagnosticBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ value: Data) {
        lock.lock()
        data.append(value)
        lock.unlock()
    }

    func string() -> String {
        lock.lock()
        defer { lock.unlock() }
        return String(decoding: data, as: UTF8.self)
    }
}

@MainActor
public final class SSHTransferManager: ObservableObject {
    public static let shared = SSHTransferManager()

    @Published public var activeTransfer: FileTransferProgress? = nil
    @Published public var completedToast: CompletedTransferToast? = nil
    @Published public var lastError: String?
    @Published public var lastHostKeyAlert: HostKeyAlert? = nil

    // Persistent Transfer Queue & History
    @Published public private(set) var queue: [QueuedTransfer] = []
    @Published public private(set) var history: [QueuedTransfer] = []

    // Active session contexts mapped by surface UUID
    private var contexts: [UUID: ActiveSSHContext] = [:]
    private var currentProcess: Process? = nil
    private let queueFileURL: URL

    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let baseDir = appSupport.appendingPathComponent("co.skyones.spectrepro", isDirectory: true)
        try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
        self.queueFileURL = baseDir.appendingPathComponent("transfers.json")
        loadQueue()
    }

    // MARK: - Queue & Persistence

    public func enqueue(_ transfer: QueuedTransfer) {
        queue.append(transfer)
        sortQueue()
        saveQueue()
    }

    public func cancelQueuedTransfer(id: UUID) {
        if let idx = queue.firstIndex(where: { $0.id == id }) {
            var item = queue.remove(at: idx)
            item.status = .cancelled
            history.insert(item, at: 0)
            saveQueue()
        }
    }

    public func retryTransfer(id: UUID) {
        if let idx = history.firstIndex(where: { $0.id == id }) {
            var item = history.remove(at: idx)
            item.status = .pending
            item.retryCount = 0
            item.errorMessage = nil
            queue.append(item)
            sortQueue()
            saveQueue()
        }
    }

    public func clearHistory() {
        history.removeAll()
        saveQueue()
    }

    private func sortQueue() {
        queue.sort { $0.priority > $1.priority }
    }

    private struct TransferStoreEnvelope: Codable {
        var queue: [QueuedTransfer]
        var history: [QueuedTransfer]
    }

    private func loadQueue() {
        guard let data = try? Data(contentsOf: queueFileURL),
              let env = try? JSONDecoder().decode(TransferStoreEnvelope.self, from: data) else { return }
        self.queue = env.queue
        self.history = env.history
    }

    private func saveQueue() {
        let env = TransferStoreEnvelope(queue: queue, history: history)
        if let data = try? JSONEncoder().encode(env) {
            try? data.write(to: queueFileURL, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: queueFileURL.path)
        }
    }

    // MARK: - Context Management

    public func reset(surfaceId: UUID) {
        if contexts.removeValue(forKey: surfaceId) != nil, currentProcess != nil {
            currentProcess?.terminate()
            currentProcess = nil
            activeTransfer = nil
            lastError = nil
        }
    }

    public func registerContext(for surfaceId: UUID, session: SavedSession) {
        let ctx = ActiveSSHContext(
            host: session.host,
            user: session.user,
            port: session.port,
            identityFile: session.identityFile,
            sshAuthentication: session.sshAuthentication,
            pkcs11Provider: session.pkcs11Provider,
            jumpHost: session.jumpHost
        )
        contexts[surfaceId] = ctx
    }

    public func hasActiveSSHContext(for surfaceId: UUID) -> Bool {
        return contexts[surfaceId] != nil
    }

    public func context(for surfaceId: UUID) -> ActiveSSHContext? {
        return contexts[surfaceId]
    }

    // MARK: - Upload

    func uploadFiles(_ urls: [URL], surface: SpectrePro.SurfaceView) {
        guard let ctx = contexts[surface.id] else {
            let paths = urls.map { $0.path }.joined(separator: " ")
            surface.surfaceModel?.sendText(paths)
            return
        }

        let validFiles = urls.filter { $0.isFileURL }
        guard !validFiles.isEmpty else { return }

        Task {
            for fileURL in validFiles {
                await performUpload(fileURL: fileURL, context: ctx, surface: surface)
            }
        }
    }

    private func performUpload(fileURL: URL, context: ActiveSSHContext, surface: SpectrePro.SurfaceView) async {
        let fileName = fileURL.lastPathComponent
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? 0
        let formattedSize = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)

        await MainActor.run {
            self.activeTransfer = FileTransferProgress(
                fileName: fileName,
                isUpload: true,
                percentage: 0.05,
                detailText: "Uploading \(fileName) (\(formattedSize))..."
            )
        }

        var scpArgs = context.buildBaseSCPArguments()
        scpArgs.append(fileURL.path)
        scpArgs.append("\(context.targetSpec):./")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: context.scpExecutable)
        process.arguments = scpArgs

        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = pipe
        let diagnosticBuffer = TransferDiagnosticBuffer()

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            diagnosticBuffer.append(data)

            if let text = String(data: data, encoding: .utf8) {
                // Parse real protocol progress percentage (e.g., "  45%  1024KB")
                if let pct = Self.parseProgressPercentage(from: text) {
                    Task { @MainActor [weak self] in
                        if var current = self?.activeTransfer {
                            current.percentage = pct
                            current.detailText = "Uploading \(fileName) (\(Int(pct * 100))%)..."
                            self?.activeTransfer = current
                        }
                    }
                }
            }
        }

        self.currentProcess = process

        do {
            try process.run()
            process.waitUntilExit()
            pipe.fileHandleForReading.readabilityHandler = nil
            diagnosticBuffer.append(pipe.fileHandleForReading.readDataToEndOfFile())
            let diagnostic = diagnosticBuffer.string()

            let success = process.terminationStatus == 0

            await MainActor.run {
                self.activeTransfer = nil
                self.currentProcess = nil

                self.checkForHostKeyAlert(diagnostic: diagnostic, host: context.host)

                if !success {
                    self.lastError = self.cleanedDiagnostic(diagnostic, fallback: "Upload failed with exit code \(process.terminationStatus).")
                    let failedRecord = QueuedTransfer(
                        fileName: fileName,
                        localPath: fileURL.path,
                        remotePath: "./\(fileName)",
                        isUpload: true,
                        status: .failed,
                        errorMessage: self.lastError,
                        completedAt: Date(),
                        surfaceId: surface.id
                    )
                    self.history.insert(failedRecord, at: 0)
                    self.saveQueue()
                }

                if success {
                    surface.surfaceModel?.sendText("./\(ActiveSSHContext.escapeRemotePath(fileName)) ")

                    self.completedToast = CompletedTransferToast(
                        fileName: fileName,
                        isUpload: true,
                        localURL: fileURL,
                        remotePath: "./\(fileName)"
                    )

                    let completedRecord = QueuedTransfer(
                        fileName: fileName,
                        localPath: fileURL.path,
                        remotePath: "./\(fileName)",
                        isUpload: true,
                        status: .completed,
                        completedAt: Date(),
                        surfaceId: surface.id
                    )
                    self.history.insert(completedRecord, at: 0)
                    self.saveQueue()

                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        if self.completedToast?.fileName == fileName {
                            self.completedToast = nil
                        }
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.activeTransfer = nil
                self.currentProcess = nil
                self.lastError = error.localizedDescription
            }
        }
    }

    // MARK: - Download

    func downloadFile(remotePath: String, surface: SpectrePro.SurfaceView) {
        guard let ctx = contexts[surface.id] else { return }

        let trimmedPath = remotePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else { return }

        let fileName = (trimmedPath as NSString).lastPathComponent
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let localDestURL = downloadsURL.appendingPathComponent(fileName)

        Task {
            await performDownload(remotePath: trimmedPath, fileName: fileName, localDestURL: localDestURL, context: ctx, surfaceId: surface.id)
        }
    }

    private func performDownload(remotePath: String, fileName: String, localDestURL: URL, context: ActiveSSHContext, surfaceId: UUID) async {
        await MainActor.run {
            self.activeTransfer = FileTransferProgress(
                fileName: fileName,
                isUpload: false,
                percentage: 0.05,
                detailText: "Downloading \(fileName)..."
            )
        }

        var scpArgs = context.buildBaseSCPArguments()
        // Escape spaces in remotePath to safely support paths with spaces
        let escapedPath = ActiveSSHContext.escapeRemotePath(remotePath)
        scpArgs.append("\(context.targetSpec):\(escapedPath)")
        scpArgs.append(localDestURL.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: context.scpExecutable)
        process.arguments = scpArgs

        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = pipe
        let diagnosticBuffer = TransferDiagnosticBuffer()

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            diagnosticBuffer.append(data)

            if let text = String(data: data, encoding: .utf8) {
                if let pct = Self.parseProgressPercentage(from: text) {
                    Task { @MainActor [weak self] in
                        if var current = self?.activeTransfer {
                            current.percentage = pct
                            current.detailText = "Downloading \(fileName) (\(Int(pct * 100))%)..."
                            self?.activeTransfer = current
                        }
                    }
                }
            }
        }

        self.currentProcess = process

        do {
            try process.run()
            process.waitUntilExit()
            pipe.fileHandleForReading.readabilityHandler = nil
            diagnosticBuffer.append(pipe.fileHandleForReading.readDataToEndOfFile())
            let diagnostic = diagnosticBuffer.string()

            let success = process.terminationStatus == 0

            await MainActor.run {
                self.activeTransfer = nil
                self.currentProcess = nil

                self.checkForHostKeyAlert(diagnostic: diagnostic, host: context.host)

                if !success {
                    self.lastError = self.cleanedDiagnostic(diagnostic, fallback: "Download failed with exit code \(process.terminationStatus).")
                    let failedRecord = QueuedTransfer(
                        fileName: fileName,
                        localPath: localDestURL.path,
                        remotePath: remotePath,
                        isUpload: false,
                        status: .failed,
                        errorMessage: self.lastError,
                        completedAt: Date(),
                        surfaceId: surfaceId
                    )
                    self.history.insert(failedRecord, at: 0)
                    self.saveQueue()
                }

                if success {
                    self.completedToast = CompletedTransferToast(
                        fileName: fileName,
                        isUpload: false,
                        localURL: localDestURL,
                        remotePath: remotePath
                    )

                    let completedRecord = QueuedTransfer(
                        fileName: fileName,
                        localPath: localDestURL.path,
                        remotePath: remotePath,
                        isUpload: false,
                        status: .completed,
                        completedAt: Date(),
                        surfaceId: surfaceId
                    )
                    self.history.insert(completedRecord, at: 0)
                    self.saveQueue()

                    DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                        if self.completedToast?.fileName == fileName {
                            self.completedToast = nil
                        }
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.activeTransfer = nil
                self.currentProcess = nil
                self.lastError = error.localizedDescription
            }
        }
    }

    public func cancelActiveTransfer() {
        currentProcess?.terminate()
        currentProcess = nil
        activeTransfer = nil
    }

    public func clearError() {
        lastError = nil
        lastHostKeyAlert = nil
    }

    nonisolated public static func parseProgressPercentage(from output: String) -> Double? {
        let pattern = #"(\d{1,3})%"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let matches = regex.matches(in: output, range: NSRange(location: 0, length: output.utf16.count))
        guard let lastMatch = matches.last,
              let range = Range(lastMatch.range(at: 1), in: output),
              let pct = Double(output[range]) else { return nil }
        return min(max(pct / 100.0, 0.0), 1.0)
    }

    private func checkForHostKeyAlert(diagnostic: String, host: String) {
        if diagnostic.contains("REMOTE HOST IDENTIFICATION HAS CHANGED") {
            let offendingLine = diagnostic.components(separatedBy: .newlines).first(where: { $0.contains("Offending") || $0.contains("known_hosts") })
            self.lastHostKeyAlert = HostKeyAlert(
                host: host,
                message: "Remote host key changed! Potential Man-in-the-Middle attack or server re-installation.",
                offendingLine: offendingLine,
                isMismatch: true
            )
        } else if diagnostic.contains("Host key verification failed") {
            self.lastHostKeyAlert = HostKeyAlert(
                host: host,
                message: "Host key verification failed for \(host).",
                isMismatch: true
            )
        }
    }

    private func cleanedDiagnostic(_ diagnostic: String, fallback: String) -> String {
        let lines = diagnostic
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lines.last ?? fallback
    }

    public func revealInFinder(url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    public func openFile(url: URL) {
        NSWorkspace.shared.open(url)
    }
}
