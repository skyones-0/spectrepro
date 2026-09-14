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

@MainActor
public final class SFTPClient: ObservableObject {
    @Published public private(set) var entries: [SFTPDirectoryEntry] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var error: SFTPClientError?
    @Published public private(set) var status: String?

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
        let task = Task { [weak self] in
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
        Task { _ = await task.value }
    }

    public func cancel() {
        process?.terminate()
        process = nil
        isLoading = false
    }

    public func upload(localURL: URL, remotePath: String) {
        guard localURL.isFileURL, FileManager.default.fileExists(atPath: localURL.path) else {
            error = .failed("The local file does not exist.")
            return
        }
        runTransfer(command: "put \(Self.quote(localURL.path)) \(Self.quote(remotePath))", status: "Uploading \(localURL.lastPathComponent)…")
    }

    public func download(remotePath: String, localURL: URL) {
        guard !remotePath.contains("\n"), !remotePath.contains("\r") else {
            error = .invalidPath
            return
        }
        runTransfer(command: "get \(Self.quote(remotePath)) \(Self.quote(localURL.path))", status: "Downloading \(localURL.lastPathComponent)…")
    }

    private func runTransfer(command: String, status: String) {
        process?.terminate()
        isLoading = true
        error = nil
        self.status = status
        Task { [weak self] in
            do {
                _ = try await self?.runBatch([command])
                await MainActor.run {
                    self?.isLoading = false
                    self?.status = "Transfer complete"
                    self?.process = nil
                }
            } catch let clientError as SFTPClientError {
                await MainActor.run {
                    self?.error = clientError
                    self?.isLoading = false
                    self?.status = nil
                    self?.process = nil
                }
            } catch {
                await MainActor.run {
                    self?.error = .failed(error.localizedDescription)
                    self?.isLoading = false
                    self?.status = nil
                    self?.process = nil
                }
            }
        }
    }

    private func runBatch(_ commands: [String]) async throws -> String {
        guard FileManager.default.isExecutableFile(atPath: "/usr/bin/sftp") else {
            throw SFTPClientError.processUnavailable
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sftp")
        process.arguments = ["-b", "-"] + context.buildBaseSFTPArguments()
        let input = Pipe()
        let output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = output

        await MainActor.run { self.process = process }
        try process.run()
        let data = commands.joined(separator: "\n").appending("\n").data(using: .utf8)!
        input.fileHandleForWriting.write(data)
        try? input.fileHandleForWriting.close()
        process.waitUntilExit()

        let result = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        guard process.terminationStatus == 0 else {
            throw SFTPClientError.failed(Self.lastDiagnostic(in: result))
        }
        return result
    }

    private static func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func lastDiagnostic(in output: String) -> String {
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
