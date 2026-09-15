import SwiftUI
import AppKit

// MARK: - Workspace Layout & Models

public enum SplitOrientation: String, Codable, Sendable {
    case horizontal
    case vertical
}

public struct WorkspaceSplitNode: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var orientation: SplitOrientation?
    public var ratio: Double
    public var sessionID: UUID?
    public var children: [WorkspaceSplitNode]

    public init(
        id: UUID = UUID(),
        orientation: SplitOrientation? = nil,
        ratio: Double = 0.5,
        sessionID: UUID? = nil,
        children: [WorkspaceSplitNode] = []
    ) {
        self.id = id
        self.orientation = orientation
        self.ratio = ratio
        self.sessionID = sessionID
        self.children = children
    }
}

public struct WorkspaceTab: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var title: String
    public var rootSplit: WorkspaceSplitNode

    public init(id: UUID = UUID(), title: String, rootSplit: WorkspaceSplitNode) {
        self.id = id
        self.title = title
        self.rootSplit = rootSplit
    }
}

public enum TimelineEventType: String, Codable, CaseIterable, Sendable {
    case connection
    case command
    case error
    case transfer
    case reconnect
    case securityAlert
}

public struct WorkspaceTimelineEvent: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let type: TimelineEventType
    public let host: String
    public let message: String
    public let exitCode: Int?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        type: TimelineEventType,
        host: String,
        message: String,
        exitCode: Int? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.host = host
        self.message = message
        self.exitCode = exitCode
    }
}

public struct WorkspaceIncidentNote: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public var author: String
    public var content: String
    public var pendingCommands: [String]

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        author: String = NSUserName(),
        content: String,
        pendingCommands: [String] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.author = author
        self.content = content
        self.pendingCommands = pendingCommands
    }
}

public struct WorkspaceModel: Codable, Equatable, Identifiable, Sendable {
    public static let currentVersion = 1
    public let version: Int
    public let id: UUID
    public var name: String
    public var createdAt: Date
    public var lastOpenedAt: Date
    public var tabs: [WorkspaceTab]
    public var timeline: [WorkspaceTimelineEvent]
    public var notes: [WorkspaceIncidentNote]

    public init(
        version: Int = Self.currentVersion,
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        lastOpenedAt: Date = Date(),
        tabs: [WorkspaceTab] = [],
        timeline: [WorkspaceTimelineEvent] = [],
        notes: [WorkspaceIncidentNote] = []
    ) {
        self.version = version
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.lastOpenedAt = lastOpenedAt
        self.tabs = tabs
        self.timeline = timeline
        self.notes = notes
    }
}

// MARK: - Multi-Host Output Comparison

public struct HostExecutionOutput: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let host: String
    public let command: String
    public let exitCode: Int
    public let durationSeconds: Double
    public let output: String

    public init(
        id: UUID = UUID(),
        host: String,
        command: String,
        exitCode: Int,
        durationSeconds: Double,
        output: String
    ) {
        self.id = id
        self.host = host
        self.command = command
        self.exitCode = exitCode
        self.durationSeconds = durationSeconds
        self.output = output
    }
}

public struct GroupedOutputCluster: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let hosts: [String]
    public let commonOutput: String
    public let exitCode: Int
    public var isOutlier: Bool { hosts.count == 1 }
}

public enum MultiHostComparator {
    public static func groupOutputs(_ outputs: [HostExecutionOutput]) -> [GroupedOutputCluster] {
        var groups: [String: (hosts: [String], exitCode: Int)] = [:]
        for item in outputs {
            let key = "\(item.exitCode):::\(item.output.trimmingCharacters(in: .whitespacesAndNewlines))"
            if var existing = groups[key] {
                existing.hosts.append(item.host)
                groups[key] = existing
            } else {
                groups[key] = ([item.host], item.exitCode)
            }
        }

        return groups.map { (key, val) in
            let components = key.components(separatedBy: ":::")
            let outputText = components.count > 1 ? components.dropFirst().joined(separator: ":::") : key
            return GroupedOutputCluster(
                hosts: val.hosts.sorted(),
                commonOutput: outputText,
                exitCode: val.exitCode
            )
        }
        .sorted { $0.hosts.count > $1.hosts.count }
    }
}

// MARK: - Incident Bundle Exporter

public enum IncidentBundleExporter {
    public static func exportSanitizedBundle(workspace: WorkspaceModel) -> String {
        var report = "# Spectre Pro Incident Bundle\n\n"
        report += "**Workspace:** \(workspace.name)\n"
        report += "**Exported At:** \(Date())\n"
        report += "**Tabs:** \(workspace.tabs.count) tab(s)\n\n"

        report += "## Timeline of Events\n\n"
        if workspace.timeline.isEmpty {
            report += "*No timeline events recorded.*\n\n"
        } else {
            for event in workspace.timeline {
                let code = event.exitCode != nil ? " (exit: \(event.exitCode!))" : ""
                report += "- `\(event.timestamp)` **[\(event.type.rawValue.uppercased())]** `\(event.host)`: \(sanitize(event.message))\(code)\n"
            }
            report += "\n"
        }

        report += "## Incident Notes\n\n"
        if workspace.notes.isEmpty {
            report += "*No incident notes.*\n\n"
        } else {
            for note in workspace.notes {
                report += "### Note by \(note.author) on \(note.createdAt)\n"
                report += "\(sanitize(note.content))\n\n"
                if !note.pendingCommands.isEmpty {
                    report += "**Pending Commands:**\n"
                    for cmd in note.pendingCommands {
                        report += "- `\(sanitize(cmd))`\n"
                    }
                    report += "\n"
                }
            }
        }

        return report
    }

    private static func sanitize(_ text: String) -> String {
        var output = text
        // 1. Bearer token (e.g. Bearer mySecretBearerToken)
        let bearerPattern = #"(?i)bearer\s+\S+"#
        if let regex = try? NSRegularExpression(pattern: bearerPattern) {
            output = regex.stringByReplacingMatches(
                in: output, range: NSRange(location: 0, length: output.utf16.count),
                withTemplate: "Bearer [REDACTED]")
        }
        // 2. Passwords
        let passwordPattern = #"(?i)(password|passphrase|secret|passwd)\s*[:=]\s*\S+"#
        if let regex = try? NSRegularExpression(pattern: passwordPattern) {
            output = regex.stringByReplacingMatches(
                in: output, range: NSRange(location: 0, length: output.utf16.count),
                withTemplate: "$1: [REDACTED]")
        }
        // 3. Tokens / Auth key-values
        let tokenPattern = #"(?i)(token|authorization|auth)\s*[:=]\s*\S+"#
        if let regex = try? NSRegularExpression(pattern: tokenPattern) {
            output = regex.stringByReplacingMatches(
                in: output, range: NSRange(location: 0, length: output.utf16.count),
                withTemplate: "$1: [REDACTED]")
        }
        // 4. API / GitHub / GitLab tokens
        let ghPattern = #"(?:ghp_|gho_|ghs_|ghr_|glpat-)[A-Za-z0-9_-]{10,}"#
        if let regex = try? NSRegularExpression(pattern: ghPattern) {
            output = regex.stringByReplacingMatches(
                in: output, range: NSRange(location: 0, length: output.utf16.count),
                withTemplate: "[TOKEN REDACTED]")
        }
        return output
    }
}

// MARK: - Workspace Store & Persistence

@MainActor
public final class WorkspaceStore: ObservableObject {
    public static let shared = WorkspaceStore()

    @Published public private(set) var workspaces: [WorkspaceModel] = []
    @Published public var activeWorkspaceID: UUID?

    private let storeDirectory: URL

    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let baseDir = appSupport.appendingPathComponent("co.skyones.spectrepro", isDirectory: true)
        self.storeDirectory = baseDir.appendingPathComponent("workspaces", isDirectory: true)
        try? FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: storeDirectory.path)
        loadAll()
    }

    public var activeWorkspace: WorkspaceModel? {
        guard let id = activeWorkspaceID else { return workspaces.first }
        return workspaces.first(where: { $0.id == id })
    }

    public func loadAll() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: storeDirectory, includingPropertiesForKeys: nil) else { return }
        var loaded: [WorkspaceModel] = []
        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let model = try? JSONDecoder().decode(WorkspaceModel.self, from: data) {
                loaded.append(model)
            }
        }
        self.workspaces = loaded.sorted { $0.lastOpenedAt > $1.lastOpenedAt }
        if activeWorkspaceID == nil {
            activeWorkspaceID = workspaces.first?.id
        }
    }

    public func save(_ workspace: WorkspaceModel) {
        var updated = workspace
        updated.lastOpenedAt = Date()
        if let idx = workspaces.firstIndex(where: { $0.id == updated.id }) {
            workspaces[idx] = updated
        } else {
            workspaces.insert(updated, at: 0)
        }

        let fileURL = storeDirectory.appendingPathComponent("\(updated.id.uuidString).json")
        let tmpURL = fileURL.appendingPathExtension("tmp")

        if let data = try? JSONEncoder().encode(updated) {
            do {
                try data.write(to: tmpURL, options: .atomic)
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tmpURL.path)
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tmpURL)
                } else {
                    try FileManager.default.moveItem(at: tmpURL, to: fileURL)
                }
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
            } catch {
                try? FileManager.default.removeItem(at: tmpURL)
            }
        }
    }

    public func delete(id: UUID) {
        workspaces.removeAll { $0.id == id }
        let fileURL = storeDirectory.appendingPathComponent("\(id.uuidString).json")
        try? FileManager.default.removeItem(at: fileURL)
        if activeWorkspaceID == id {
            activeWorkspaceID = workspaces.first?.id
        }
    }

    public func logTimelineEvent(type: TimelineEventType, host: String, message: String, exitCode: Int? = nil) {
        guard var current = activeWorkspace else { return }
        let event = WorkspaceTimelineEvent(type: type, host: host, message: message, exitCode: exitCode)
        current.timeline.insert(event, at: 0)
        save(current)
    }

    public func addNote(_ note: WorkspaceIncidentNote) {
        guard var current = activeWorkspace else { return }
        current.notes.insert(note, at: 0)
        save(current)
    }
}
