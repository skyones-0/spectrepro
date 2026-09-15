import SwiftUI
import AppKit

@MainActor
public final class SessionLogger: ObservableObject {
    public static let shared = SessionLogger()

    @Published public private(set) var isRecording: Bool = false
    @Published public private(set) var currentSessionName: String = ""
    @Published public private(set) var currentLogURL: URL? = nil
    @Published public private(set) var recordedBytes: Int = 0
    @Published public private(set) var elapsedTimeFormatted: String = "00:00"
    @Published public private(set) var lastError: String?

    // Configuration options
    @Published public var prependTimestamps: Bool = true
    @Published public var stripANSI: Bool = true
    @Published public var sanitizeSensitiveData: Bool = true

    private var fileHandle: FileHandle? = nil
    private var timer: Timer? = nil
    private var startTime: Date? = nil
    private var lastScreenLines: [String] = []
    private let dateFormatter: DateFormatter
    private let timestampFormatter: DateFormatter

    public init() {
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"

        self.timestampFormatter = DateFormatter()
        self.timestampFormatter.dateFormat = "[yyyy-MM-dd HH:mm:ss.SSS] "
    }

    public var logsDirectoryURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
        let spectreLogs = docs.appendingPathComponent("Spectre Pro Logs", isDirectory: true)
        return spectreLogs
    }

    public func startRecording(sessionName: String) {
        if isRecording {
            _ = stopRecording()
        }

        let cleanName = sessionName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let filename = "\(dateFormatter.string(from: Date()))_\(cleanName.isEmpty ? "session" : cleanName).log"
        let logURL = logsDirectoryURL.appendingPathComponent(filename)

        do {
            try FileManager.default.createDirectory(at: logsDirectoryURL, withIntermediateDirectories: true)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: logsDirectoryURL.path)
            guard FileManager.default.createFile(atPath: logURL.path, contents: nil) else {
                throw CocoaError(.fileWriteUnknown)
            }
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: logURL.path)
        } catch {
            lastError = "Could not create session log: \(error.localizedDescription)"
            return
        }

        guard let handle = try? FileHandle(forWritingTo: logURL) else {
            lastError = "Could not open session log for writing."
            return
        }

        self.fileHandle = handle
        self.currentSessionName = cleanName.isEmpty ? "Terminal Session" : cleanName
        self.currentLogURL = logURL
        self.recordedBytes = 0
        self.lastError = nil
        self.isRecording = true
        self.startTime = Date()
        self.lastScreenLines = []
        self.elapsedTimeFormatted = "00:00"

        // Initial Header
        let header = "=== Spectre Pro Session Log: \(currentSessionName) ===\n=== Started: \(Date()) ===\n\n"
        if let data = header.data(using: .utf8) {
            handle.write(data)
            recordedBytes += data.count
        }

        // Duration timer
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let start = self.startTime else { return }
                let elapsed = Int(Date().timeIntervalSince(start))
                let minutes = elapsed / 60
                let seconds = elapsed % 60
                self.elapsedTimeFormatted = String(format: "%02d:%02d", minutes, seconds)
            }
        }
    }

    public func log(text: String) {
        guard isRecording, let handle = fileHandle, !text.isEmpty else { return }

        var output = text
        if stripANSI {
            output = cleanANSIEscapeSequences(from: output)
        }

        if sanitizeSensitiveData {
            output = sanitize(output)
        }

        if prependTimestamps {
            let ts = timestampFormatter.string(from: Date())
            let lines = output.components(separatedBy: .newlines)
            output = lines.map { "\(ts)\($0)" }.joined(separator: "\n")
        }

        if let data = output.data(using: .utf8) {
            handle.write(data)
            recordedBytes += data.count
        }
    }

    /// Ingests full-screen terminal text and records only newly added lines
    /// to avoid duplicating screen snapshots.
    public func ingestScreenText(_ text: String) {
        guard isRecording, !text.isEmpty else { return }
        let currentLines = text.components(separatedBy: .newlines)

        if lastScreenLines.isEmpty {
            lastScreenLines = currentLines
            let initialOutput = currentLines.joined(separator: "\n")
            if !initialOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                log(text: initialOutput + "\n")
            }
            return
        }

        // Find maximal suffix of lastScreenLines matching a prefix of currentLines
        var matchLen: Int? = nil
        let maxLookback = min(lastScreenLines.count, currentLines.count)
        for len in stride(from: maxLookback, through: 1, by: -1) {
            let lastSlice = lastScreenLines.suffix(len)
            let currentSlice = currentLines.prefix(len)
            if lastSlice.elementsEqual(currentSlice) {
                matchLen = len
                break
            }
        }

        if let matchLen = matchLen {
            let newLines = Array(currentLines.dropFirst(matchLen))
            if !newLines.isEmpty {
                let delta = newLines.joined(separator: "\n")
                if !delta.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    log(text: delta + "\n")
                }
            }
        } else {
            // Check if user is typing on the same line (last line prefix of first new line)
            if let last = lastScreenLines.last, let first = currentLines.first,
               first.hasPrefix(last), first.count > last.count {
                let diff = String(first.dropFirst(last.count))
                let rest = currentLines.dropFirst().joined(separator: "\n")
                let delta = diff + (rest.isEmpty ? "" : "\n" + rest)
                log(text: delta + "\n")
            } else {
                let delta = currentLines.joined(separator: "\n")
                if !delta.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    log(text: delta + "\n")
                }
            }
        }
        lastScreenLines = currentLines
    }

    public func stopRecording() -> URL? {
        guard isRecording else { return nil }

        let footer = "\n=== Session Ended: \(Date()) (Bytes: \(recordedBytes)) ===\n"
        if let data = footer.data(using: .utf8) {
            fileHandle?.write(data)
        }

        try? fileHandle?.close()
        fileHandle = nil

        timer?.invalidate()
        timer = nil

        lastScreenLines = []
        let finalURL = currentLogURL
        isRecording = false
        startTime = nil
        return finalURL
    }

    public func openLogsFolder() {
        NSWorkspace.shared.open(logsDirectoryURL)
    }

    public func revealCurrentLogInFinder() {
        if let url = currentLogURL {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            openLogsFolder()
        }
    }

    private func cleanANSIEscapeSequences(from input: String) -> String {
        // Regex to strip standard ANSI / VT100 / xterm color and cursor control sequences
        let pattern = #"\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return input
        }
        let range = NSRange(location: 0, length: input.utf16.count)
        return regex.stringByReplacingMatches(in: input, options: [], range: range, withTemplate: "")
    }

    private func sanitize(_ text: String) -> String {
        var output = text

        // Password / passphrase prompts
        let passwordPattern = #"(?i)(password|passphrase|passwd|secret)\s*[:=]\s*\S+"#
        if let regex = try? NSRegularExpression(pattern: passwordPattern) {
            output = regex.stringByReplacingMatches(
                in: output, range: NSRange(location: 0, length: output.utf16.count),
                withTemplate: "$1: [REDACTED]")
        }

        // Bearer / Auth tokens
        let tokenPattern = #"(?i)(bearer|token|authorization|auth)\s*[:=]\s*\S+"#
        if let regex = try? NSRegularExpression(pattern: tokenPattern) {
            output = regex.stringByReplacingMatches(
                in: output, range: NSRange(location: 0, length: output.utf16.count),
                withTemplate: "$1: [REDACTED]")
        }

        // AWS access keys
        let awsPattern = #"(?:AKIA|ASIA)[A-Z0-9]{16}"#
        if let regex = try? NSRegularExpression(pattern: awsPattern) {
            output = regex.stringByReplacingMatches(
                in: output, range: NSRange(location: 0, length: output.utf16.count),
                withTemplate: "[REDACTED]")
        }

        // SSH private keys
        let sshKeyPattern = #"-----BEGIN[^-]*PRIVATE KEY-----[\s\S]*?-----END[^-]*PRIVATE KEY-----"#
        if let regex = try? NSRegularExpression(pattern: sshKeyPattern, options: .dotMatchesLineSeparators) {
            output = regex.stringByReplacingMatches(
                in: output, range: NSRange(location: 0, length: output.utf16.count),
                withTemplate: "[PRIVATE KEY REDACTED]")
        }

        // Export statements with sensitive variable names
        let exportPattern = #"(?i)(export\s+\w*(?:KEY|TOKEN|SECRET|PASSWORD|CREDENTIAL|API)\w*\s*=\s*)\S+"#
        if let regex = try? NSRegularExpression(pattern: exportPattern) {
            output = regex.stringByReplacingMatches(
                in: output, range: NSRange(location: 0, length: output.utf16.count),
                withTemplate: "$1[REDACTED]")
        }

        // JWT tokens
        let jwtPattern = #"eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]+"#
        if let regex = try? NSRegularExpression(pattern: jwtPattern) {
            output = regex.stringByReplacingMatches(
                in: output, range: NSRange(location: 0, length: output.utf16.count),
                withTemplate: "[JWT REDACTED]")
        }

        // GitHub / GitLab tokens
        let ghPattern = #"(?:ghp_|gho_|ghs_|ghr_|glpat-)[A-Za-z0-9_-]{20,}"#
        if let regex = try? NSRegularExpression(pattern: ghPattern) {
            output = regex.stringByReplacingMatches(
                in: output, range: NSRange(location: 0, length: output.utf16.count),
                withTemplate: "[TOKEN REDACTED]")
        }

        return output
    }
}

// MARK: - Live Recording Overlay Indicator

public struct SessionRecordingIndicator: View {
    @ObservedObject private var logger: SessionLogger
    @State private var isBlinking = false

    public init(logger: SessionLogger? = nil) {
        self._logger = ObservedObject(wrappedValue: logger ?? SessionLogger.shared)
    }

    public var body: some View {
        if logger.isRecording {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .opacity(isBlinking ? 1.0 : 0.3)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isBlinking)

                Text("REC [\(logger.elapsedTimeFormatted)]")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.red)

                Text(logger.currentSessionName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: 100)

                Button {
                    _ = logger.stopRecording()
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Stop Session Recording")

                Button {
                    logger.revealCurrentLogInFinder()
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Reveal Log File in Finder")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.92))
                    .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
            )
            .overlay(
                Capsule()
                    .stroke(Color.red.opacity(0.4), lineWidth: 1)
            )
            .onAppear {
                isBlinking = true
            }
        }
    }
}
