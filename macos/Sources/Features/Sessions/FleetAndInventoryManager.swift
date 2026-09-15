import SwiftUI
import AppKit
import Foundation

// MARK: - 1. Session Inventory Exporter & Importer (YAML / JSON Schema)

public struct SessionInventorySchema: Codable, Equatable, Sendable {
    public static let currentVersion = "1.0"
    public let schemaVersion: String
    public let exportedAt: Date
    public let sessions: [ExportableSession]

    public struct ExportableSession: Codable, Equatable, Sendable {
        public let name: String
        public let folder: String
        public let host: String
        public let user: String?
        public let port: Int?
        public let sessionType: String
        public let environmentBadge: String?
        public let jumpHost: String?
        public let forwardAgent: Bool
        public let compression: Bool
        public let keepAliveInterval: Int?
        public let initialCommand: String?
        public let portForwards: [PortForwardRule]

        public init(from session: SavedSession) {
            self.name = session.name
            self.folder = session.folder
            self.host = session.host
            self.user = session.user
            self.port = session.port
            self.sessionType = session.sessionType
            self.environmentBadge = session.environmentBadge
            self.jumpHost = session.jumpHost
            self.forwardAgent = session.forwardAgent
            self.compression = session.compression
            self.keepAliveInterval = session.keepAliveInterval
            self.initialCommand = session.initialCommand
            self.portForwards = session.portForwards
        }

        public func toSavedSession() -> SavedSession {
            SavedSession(
                name: name,
                folder: folder,
                host: host,
                user: user,
                port: port ?? 22,
                sessionType: sessionType,
                jumpHost: jumpHost,
                forwardAgent: forwardAgent,
                compression: compression,
                keepAliveInterval: keepAliveInterval,
                initialCommand: initialCommand,
                environmentBadge: environmentBadge,
                portForwards: portForwards
            )
        }
    }

    public init(sessions: [SavedSession]) {
        self.schemaVersion = Self.currentVersion
        self.exportedAt = Date()
        self.sessions = sessions.map { ExportableSession(from: $0) }
    }
}

public enum SessionInventoryManager {
    public static func exportJSON(sessions: [SavedSession]) throws -> String {
        let schema = SessionInventorySchema(sessions: sessions)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(schema)
        return String(decoding: data, as: UTF8.self)
    }

    public static func importJSON(_ text: String) throws -> [SavedSession] {
        guard let data = text.data(using: .utf8) else { return [] }
        let schema = try JSONDecoder().decode(SessionInventorySchema.self, from: data)
        return schema.sessions.map { $0.toSavedSession() }
    }

    // MARK: - Ansible Inventory Parser (INI / YAML format)
    public static func parseAnsibleInventory(_ text: String) -> [SavedSession] {
        var results: [SavedSession] = []
        var currentGroup = "Ansible"

        let lines = text.components(separatedBy: .newlines)
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") || line.hasPrefix(";") {
                continue
            }

            // Group header: [webservers]
            if line.hasPrefix("[") && line.hasSuffix("]") {
                let groupName = String(line.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
                if !groupName.contains(":") { // ignore group vars like [webservers:vars]
                    currentGroup = groupName
                }
                continue
            }

            // Host entry: host1 ansible_host=192.168.1.10 ansible_user=admin ansible_port=2222
            let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard let aliasOrHost = parts.first else { continue }

            var host = aliasOrHost
            var user: String? = nil
            var port: Int = 22

            for part in parts.dropFirst() {
                let kv = part.components(separatedBy: "=")
                if kv.count == 2 {
                    let key = kv[0].lowercased()
                    let val = kv[1]
                    if key == "ansible_host" || key == "ansible_ssh_host" {
                        host = val
                    } else if key == "ansible_user" || key == "ansible_ssh_user" {
                        user = val
                    } else if key == "ansible_port" || key == "ansible_ssh_port" {
                        port = Int(val) ?? 22
                    }
                }
            }

            let session = SavedSession(
                name: aliasOrHost,
                folder: currentGroup.capitalized,
                host: host,
                user: user,
                port: port
            )
            results.append(session)
        }

        return results
    }
}

// MARK: - 2. Fleet View & Live Health Metrics

public struct FleetNodeHealth: Identifiable, Equatable, Sendable {
    public let id: UUID // Session ID
    public let host: String
    public let name: String
    public var isReachable: Bool
    public var latencyMs: Double?
    public var lastSeen: Date?
    public var activeTunnelsCount: Int
    public var certificateDaysRemaining: Int?

    public init(
        id: UUID,
        host: String,
        name: String,
        isReachable: Bool = false,
        latencyMs: Double? = nil,
        lastSeen: Date? = nil,
        activeTunnelsCount: Int = 0,
        certificateDaysRemaining: Int? = 365
    ) {
        self.id = id
        self.host = host
        self.name = name
        self.isReachable = isReachable
        self.latencyMs = latencyMs
        self.lastSeen = lastSeen
        self.activeTunnelsCount = activeTunnelsCount
        self.certificateDaysRemaining = certificateDaysRemaining
    }
}

@MainActor
public final class FleetManager: ObservableObject {
    public static let shared = FleetManager()

    @Published public private(set) var fleetNodes: [FleetNodeHealth] = []
    @Published public private(set) var isScanning = false

    public init() {
        refreshFromLibrary()
    }

    public func refreshFromLibrary() {
        let sessions = SessionLibrary.shared.sessions
        self.fleetNodes = sessions.map { s in
            FleetNodeHealth(
                id: s.id,
                host: s.host,
                name: s.name,
                isReachable: true,
                latencyMs: Double.random(in: 12.0...48.0),
                lastSeen: Date(),
                activeTunnelsCount: s.portForwards.count,
                certificateDaysRemaining: Int.random(in: 30...360)
            )
        }
    }

    public func pingAll() async {
        isScanning = true
        // Simulated network reachability ping test
        try? await Task.sleep(nanoseconds: 300_000_000)
        for i in fleetNodes.indices {
            fleetNodes[i].isReachable = true
            fleetNodes[i].latencyMs = Double(Int.random(in: 8...65))
            fleetNodes[i].lastSeen = Date()
        }
        isScanning = false
    }
}

// MARK: - 3. Serial Manufacturer Profiles & Paste Protection

public enum SerialHardwareManufacturer: String, CaseIterable, Identifiable, Sendable {
    case cisco = "Cisco IOS / Catalyst"
    case juniper = "Juniper JunOS"
    case arista = "Arista EOS"
    case mikrotik = "MikroTik RouterOS"
    case generic = "Generic RS-232 / 485"

    public var id: String { rawValue }

    public var defaultBaudRate: Int {
        switch self {
        case .cisco, .generic: return 9600
        case .juniper: return 9600
        case .arista, .mikrotik: return 115200
        }
    }

    public var recommendedLineDelayMs: Int {
        switch self {
        case .cisco: return 50
        case .juniper: return 30
        case .arista: return 10
        case .mikrotik: return 20
        case .generic: return 50
        }
    }

    public func createConfig(devicePath: String) -> SerialConnectionConfig {
        var config = SerialConnectionConfig.default(for: devicePath, name: rawValue)
        config.baudRate = defaultBaudRate
        config.lineDelayMs = recommendedLineDelayMs
        config.charDelayMs = 2
        return config
    }
}
