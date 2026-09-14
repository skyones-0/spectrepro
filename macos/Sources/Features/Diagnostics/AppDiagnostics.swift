import Foundation
import OSLog
import AppKit

enum AppDiagnostics {
    enum Verbosity: String, CaseIterable {
        case errorsOnly
        case normal
        case verbose
    }

    private static let subsystem = Bundle.main.bundleIdentifier ?? "co.skyones.spectrepro"
    private static let queue = DispatchQueue(label: "co.skyones.spectrepro.diagnostics")
    private static let maximumLogBytes = 1_000_000

    static var logFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/SpectrePro/SpectrePro.log")
    }

    static var verbosity: Verbosity {
        get { Verbosity(rawValue: UserDefaults.standard.string(forKey: "diagnostics.verbosity") ?? "normal") ?? .normal }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "diagnostics.verbosity") }
    }

    static func revealLog() {
        let fileManager = FileManager.default
        let directoryURL = logFileURL.deletingLastPathComponent()
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([logFileURL])
    }

    static func event(_ message: String, category: String = "App") {
        guard verbosity != .errorsOnly else { return }
        Logger(subsystem: subsystem, category: category).info("\(message, privacy: .public)")
        append("INFO", message: message, category: category)
    }

    static func error(_ message: String, category: String = "App") {
        Logger(subsystem: subsystem, category: category).error("\(message, privacy: .public)")
        append("ERROR", message: message, category: category)
    }

    private static func append(_ level: String, message: String, category: String) {
        queue.async {
            let fileManager = FileManager.default
            let fileURL = logFileURL
            let directoryURL = fileURL.deletingLastPathComponent()

            do {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
                try rotateIfNeeded(fileManager: fileManager, fileURL: fileURL)

                if !fileManager.fileExists(atPath: fileURL.path) {
                    fileManager.createFile(atPath: fileURL.path, contents: nil)
                }

                let line = "\(Date().ISO8601Format()) [\(level)] [\(category)] \(message)\n"
                let handle = try FileHandle(forWritingTo: fileURL)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: Data(line.utf8))
            } catch {
                Logger(subsystem: subsystem, category: "Diagnostics").error("Could not write diagnostics log: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private static func rotateIfNeeded(fileManager: FileManager, fileURL: URL) throws {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
        guard let size = attributes[.size] as? NSNumber, size.intValue >= maximumLogBytes else { return }

        let archivedURL = fileURL.deletingLastPathComponent().appendingPathComponent("SpectrePro.previous.log")
        try? fileManager.removeItem(at: archivedURL)
        try fileManager.moveItem(at: fileURL, to: archivedURL)
    }
}
