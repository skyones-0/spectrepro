import Combine
import Foundation

public struct SFTPDirectoryEntry: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let path: String
    public let isDirectory: Bool

    public init(name: String, path: String, isDirectory: Bool) {
        self.id = path
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
    }
}

public struct SFTPTransferProgress: Equatable, Sendable {
    public let fileName: String
    public let isUpload: Bool
    public var completedBytes: Int64
    public var totalBytes: Int64?
    public var bytesPerSecond: Double
    public var estimatedTimeRemaining: TimeInterval?
    public var fractionCompleted: Double?

    public var detailText: String {
        var details = [ByteCountFormatter.string(fromByteCount: completedBytes, countStyle: .file)]
        if let totalBytes {
            details.append("of (ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file))")
        }
        if bytesPerSecond > 0 {
            details.append("• (ByteCountFormatter.string(fromByteCount: Int64(bytesPerSecond), countStyle: .file))/s")
        }
        if let estimatedTimeRemaining {
            details.append("• (Self.formatDuration(estimatedTimeRemaining)) remaining")
        }
        return details.joined(separator: " ")
    }

    private static func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = max(0, Int(duration.rounded()))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

public enum SFTPClientError: Error, LocalizedError, Equatable {
    case processUnavailable
    case invalidPath
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .processUnavailable: return "The system SFTP client is unavailable."
        case .invalidPath: return "The remote path is invalid."
        case .failed(let message): return message
        }
    }
}

private final class SFTPOutputAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ data: Data) {
        lock.lock()
        self.data.append(data)
        lock.unlock()
    }

    func string() -> String {
        lock.lock()
        let snapshot = data
        lock.unlock()
        return String(data: snapshot, encoding: .utf8) ?? ""
    }
}

@MainActor
public final class SFTPClient: ObservableObject {
    @Published public private(set) var entries: [SFTPDirectoryEntry] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var error: SFTPClientError?
    @Published public private(set) var status: String?
    @Published public private(set) var progress: SFTPTransferProgress?

    private let context: ActiveSSHContext
    private var process: Process?

    public init(context: ActiveSSHContext) {
        self.context = context
    }

    public func list(remotePath: String = ".") {
        process?.terminate()
        let path = remotePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty, !path.contains("\n"), !path.contains("\r") else {
            error = .invalidPath
            return
        }

        isLoading = true
        error = nil
        let command = "ls -la \(Self.quote(path))"
        Task { [weak self] in
            do {
                let output = try await self?.runBatch([command]) ?? ""
                let parsed = Self.parseListing(output, basePath: path)
                await MainActor.run {
                    self?.entries = parsed
                    self?.isLoading = false
                    self?.process = nil
                }
            } catch let clientError as SFTPClientError {
                await MainActor.run {
                    self?.error = clientError
                    self?.isLoading = false
                    self?.process = nil
                }
            } catch {
                await MainActor.run {
                    self?.error = .failed(error.localizedDescription)
                    self?.isLoading = false
                    self?.process = nil
                }
            }
        }
    }

    public func cancel() {
        process?.terminate()
        process = nil
        isLoading = false
        status = nil
        progress = nil
    }

    public func upload(localURL: URL, remotePath: String) {
        guard localURL.isFileURL, FileManager.default.fileExists(atPath: localURL.path) else {
            error = .failed("The local file does not exist.")
            return
        }
        guard Self.isValidPath(remotePath) else {
            error = .invalidPath
            return
        }
        let totalBytes = (try? FileManager.default.attributesOfItem(atPath: localURL.path)[.size] as? Int64) ?? 0
        runTransfer(
            command: "put \(Self.quote(localURL.path)) \(Self.quote(remotePath))",
            fileName: localURL.lastPathComponent,
            isUpload: true,
            totalBytes: totalBytes,
            status: "Uploading (localURL.lastPathComponent)…"
        )
    }

    public func download(remotePath: String, localURL: URL) {
        guard Self.isValidPath(remotePath), localURL.isFileURL else {
            error = .invalidPath
            return
        }
        runTransfer(
            command: "get \(Self.quote(remotePath)) \(Self.quote(localURL.path))",
            fileName: localURL.lastPathComponent,
            isUpload: false,
            totalBytes: nil,
            status: "Downloading (localURL.lastPathComponent)…"
        )
    }

    private func runTransfer(command: String, fileName: String, isUpload: Bool, totalBytes: Int64?, status: String) {
        process?.terminate()
        isLoading = true
        error = nil
        self.status = status
        progress = SFTPTransferProgress(
            fileName: fileName,
            isUpload: isUpload,
            completedBytes: 0,
            totalBytes: totalBytes,
            bytesPerSecond: 0,
            estimatedTimeRemaining: nil,
            fractionCompleted: totalBytes == 0 ? nil : 0
        )
        let startedAt = Date()
        Task { [weak self] in
            do {
                _ = try await self?.runBatch([command]) { [weak self] output in
                    guard let parsed = Self.parseTransferProgress(output) else { return }
                    Task { @MainActor in
                        self?.applyProgress(parsed, startedAt: startedAt)
                    }
                }
                await MainActor.run {
                    self?.isLoading = false
                    self?.status = "Transfer complete"
                    if var progress = self?.progress {
                        progress.fractionCompleted = 1
                        if let totalBytes {
                            progress.completedBytes = totalBytes
                        }
                        self?.progress = progress
                    }
                    self?.process = nil
                }
            } catch let clientError as SFTPClientError {
                await MainActor.run {
                    self?.error = clientError
                    self?.isLoading = false
                    self?.status = nil
                    self?.progress = nil
                    self?.process = nil
                }
            } catch {
                await MainActor.run {
                    self?.error = .failed(error.localizedDescription)
                    self?.isLoading = false
                    self?.status = nil
                    self?.progress = nil
                    self?.process = nil
                }
            }
        }
    }

    private func runBatch(_ commands: [String], onOutput: ((String) -> Void)? = nil) async throws -> String {
        guard FileManager.default.isExecutableFile(atPath: context.sftpExecutable) else {
            throw SFTPClientError.processUnavailable
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: context.sftpExecutable)
        process.arguments = ["-b", "-"] + context.buildBaseSFTPArguments()
        let input = Pipe()
        let output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = output

        self.process = process

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let outputBuffer = SFTPOutputAccumulator()

                output.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty else { return }
                    outputBuffer.append(data)
                    if let text = String(data: data, encoding: .utf8) {
                        onOutput?(text)
                    }
                }

                process.terminationHandler = { [weak self] process in
                    output.fileHandleForReading.readabilityHandler = nil
                    let remainingData = output.fileHandleForReading.readDataToEndOfFile()
                    outputBuffer.append(remainingData)
                    let result = outputBuffer.string()

                    let outcome: Result<String, Error>
                    if process.terminationStatus == 0 {
                        outcome = .success(result)
                    } else {
                        outcome = .failure(SFTPClientError.failed(Self.lastDiagnostic(in: result)))
                    }

                    Task { @MainActor in
                        if self?.process === process {
                            self?.process = nil
                        }
                    }
                    continuation.resume(with: outcome)
                }

                do {
                    try process.run()
                    let data = Data(commands.joined(separator: "\n").appending("\n").utf8)
                    input.fileHandleForWriting.write(data)
                    try input.fileHandleForWriting.close()
                } catch {
                    output.fileHandleForReading.readabilityHandler = nil
                    process.terminationHandler = nil
                    process.terminate()
                    self.process = nil
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            process.terminate()
        }
    }

    private static func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func applyProgress(_ parsed: ParsedTransferProgress, startedAt: Date) {
        guard var progress else { return }
        let elapsed = max(Date().timeIntervalSince(startedAt), 0.001)
        let completedBytes: Int64
        if let fraction = parsed.fraction, let totalBytes = progress.totalBytes {
            completedBytes = Int64(Double(totalBytes) * fraction)
        } else {
            completedBytes = progress.completedBytes
        }
        progress.completedBytes = max(progress.completedBytes, completedBytes)
        progress.fractionCompleted = parsed.fraction ?? progress.fractionCompleted
        progress.bytesPerSecond = parsed.bytesPerSecond ?? (Double(progress.completedBytes) / elapsed)
        if let totalBytes = progress.totalBytes, progress.bytesPerSecond > 0 {
            progress.estimatedTimeRemaining = Double(max(0, totalBytes - progress.completedBytes)) / progress.bytesPerSecond
        } else {
            progress.estimatedTimeRemaining = parsed.eta
        }
        self.progress = progress
    }

    private struct ParsedTransferProgress {
        let fraction: Double?
        let bytesPerSecond: Double?
        let eta: TimeInterval?
    }

    nonisolated private static func parseTransferProgress(_ output: String) -> ParsedTransferProgress? {
        guard let percentString = captures(pattern: #"(\d{1,3})%"#, in: output)?.first,
              let percent = Double(percentString), percent <= 100 else {
            return nil
        }
        let speed: Double?
        if let values = captures(pattern: #"([0-9]+(?:\.[0-9]+)?)\s*([KMG]?B)/s"#, in: output),
           let value = Double(values[0]) {
            let multiplier: Double
            switch values[1] {
            case "KB": multiplier = 1_024
            case "MB": multiplier = 1_048_576
            case "GB": multiplier = 1_073_741_824
            default: multiplier = 1
            }
            speed = value * multiplier
        } else {
            speed = nil
        }
        let eta: TimeInterval?
        if let values = captures(pattern: #"(\d+):(\d+)\s*ETA"#, in: output),
           let minutes = Double(values[0]), let seconds = Double(values[1]) {
            eta = minutes * 60 + seconds
        } else {
            eta = nil
        }
        return ParsedTransferProgress(fraction: percent / 100, bytesPerSecond: speed, eta: eta)
    }

    nonisolated private static func captures(pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        return (1..<match.numberOfRanges).compactMap { index in
            let captureRange = match.range(at: index)
            guard let range = Range(captureRange, in: text) else { return nil }
            return String(text[range])
        }
    }

    private static func isValidPath(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !value.contains("\n") && !value.contains("\r") && !value.contains("\0")
    }

    nonisolated private static func lastDiagnostic(in output: String) -> String {
        output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .last ?? "SFTP command failed."
    }

    private static func parseListing(_ output: String, basePath: String) -> [SFTPDirectoryEntry] {
        output.components(separatedBy: .newlines).compactMap { line in
            let fields = line.split(maxSplits: 8, whereSeparator: { $0 == " " || $0 == "\t" })
            guard fields.count == 9, fields[0].first == "d" || fields[0].first == "-" else { return nil }
            let name = String(fields[8])
            guard name != ".", name != ".." else { return nil }
            let separator = basePath == "." || basePath.hasSuffix("/") ? "" : "/"
            return SFTPDirectoryEntry(
                name: name,
                path: "\(basePath)\(separator)\(name)",
                isDirectory: fields[0].first == "d"
            )
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
