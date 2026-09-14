import SwiftUI
import AppKit

// MARK: - Port Forwarding Types

public enum PortForwardType: String, Codable, CaseIterable, Identifiable {
    case local = "Local (-L)"
    case remote = "Remote (-R)"
    case dynamic = "Dynamic SOCKS5 (-D)"

    public var id: String { rawValue }

    public var flag: String {
        switch self {
        case .local: return "-L"
        case .remote: return "-R"
        case .dynamic: return "-D"
        }
    }
}

public struct PortForwardRule: Identifiable, Codable, Equatable {
    public var id: UUID
    public var type: PortForwardType
    public var localPort: Int
    public var remoteHost: String
    public var remotePort: Int

    public init(
        id: UUID = UUID(),
        type: PortForwardType = .local,
        localPort: Int = 8080,
        remoteHost: String = "localhost",
        remotePort: Int = 80
    ) {
        self.id = id
        self.type = type
        self.localPort = localPort
        self.remoteHost = remoteHost
        self.remotePort = remotePort
    }

    public var sshArgument: String {
        switch type {
        case .local:
            return "-L \(localPort):\(remoteHost):\(remotePort)"
        case .remote:
            return "-R \(remotePort):\(remoteHost):\(localPort)"
        case .dynamic:
            return "-D \(localPort)"
        }
    }
}

// MARK: - Expect / Send Rule

public enum ExpectSendMatchMode: String, Codable, CaseIterable, Identifiable {
    case literal
    case regularExpression

    public var id: String { rawValue }
    public var title: String { self == .literal ? "Text" : "Regex" }
}

public struct ExpectSendRule: Identifiable, Codable, Equatable {
    public var id: UUID
    public var expect: String
    public var send: String
    public var matchMode: ExpectSendMatchMode
    public var timeoutSeconds: Double
    public var retryCount: Int
    public var continueOnFailure: Bool
    public var credentialReference: CredentialReference?

    public init(
        id: UUID = UUID(),
        expect: String = "",
        send: String = "",
        matchMode: ExpectSendMatchMode = .literal,
        timeoutSeconds: Double = 15,
        retryCount: Int = 0,
        continueOnFailure: Bool = false,
        credentialReference: CredentialReference? = nil
    ) {
        self.id = id
        self.expect = expect
        self.send = send
        self.matchMode = matchMode
        self.timeoutSeconds = timeoutSeconds
        self.retryCount = retryCount
        self.continueOnFailure = continueOnFailure
        self.credentialReference = credentialReference
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        expect = try container.decodeIfPresent(String.self, forKey: .expect) ?? ""
        send = try container.decodeIfPresent(String.self, forKey: .send) ?? ""
        matchMode = try container.decodeIfPresent(ExpectSendMatchMode.self, forKey: .matchMode) ?? .literal
        timeoutSeconds = try container.decodeIfPresent(Double.self, forKey: .timeoutSeconds) ?? 15
        retryCount = try container.decodeIfPresent(Int.self, forKey: .retryCount) ?? 0
        continueOnFailure = try container.decodeIfPresent(Bool.self, forKey: .continueOnFailure) ?? false
        credentialReference = try container.decodeIfPresent(CredentialReference.self, forKey: .credentialReference)
    }
}

// MARK: - Saved Session Model

public struct SavedSession: Identifiable, Codable, Equatable {
    public var id: UUID
    public var name: String
    public var folder: String
    public var host: String
    public var user: String?
    public var port: Int?
    public var sessionType: String // "ssh", "console", "telnet"

    // Advanced SSH Parameters (Core Shell & SecureCRT grade)
    public var identityFile: String?
    public var jumpHost: String?
    public var forwardAgent: Bool
    public var compression: Bool
    public var keepAliveInterval: Int?
    public var initialCommand: String?
    public var environmentBadge: String? // "PROD", "STAGING", "DEV", "LAB"
    public var portForwards: [PortForwardRule]
    public var sessionLogging: Bool
    public var expectSendRules: [ExpectSendRule]
    public var credentialReference: CredentialReference?

    public init(
        id: UUID = UUID(),
        name: String,
        folder: String = "SSH",
        host: String,
        user: String? = nil,
        port: Int? = 22,
        sessionType: String = "ssh",
        identityFile: String? = nil,
        jumpHost: String? = nil,
        forwardAgent: Bool = false,
        compression: Bool = false,
        keepAliveInterval: Int? = nil,
        initialCommand: String? = nil,
        environmentBadge: String? = nil,
        portForwards: [PortForwardRule] = [],
        sessionLogging: Bool = false,
        expectSendRules: [ExpectSendRule] = [],
        credentialReference: CredentialReference? = nil
    ) {
        self.id = id
        self.name = name
        self.folder = folder
        self.host = host
        self.user = user
        self.port = port
        self.sessionType = sessionType
        self.identityFile = identityFile
        self.jumpHost = jumpHost
        self.forwardAgent = forwardAgent
        self.compression = compression
        self.keepAliveInterval = keepAliveInterval
        self.initialCommand = initialCommand
        self.environmentBadge = environmentBadge
        self.portForwards = portForwards
        self.sessionLogging = sessionLogging
        self.expectSendRules = expectSendRules
        self.credentialReference = credentialReference
    }

    // Custom Decodable for graceful backwards compatibility with older sessions.json
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.folder = try container.decodeIfPresent(String.self, forKey: .folder) ?? "SSH"
        self.host = try container.decode(String.self, forKey: .host)
        self.user = try container.decodeIfPresent(String.self, forKey: .user)
        self.port = try container.decodeIfPresent(Int.self, forKey: .port)
        self.sessionType = try container.decodeIfPresent(String.self, forKey: .sessionType) ?? "ssh"

        self.identityFile = try container.decodeIfPresent(String.self, forKey: .identityFile)
        self.jumpHost = try container.decodeIfPresent(String.self, forKey: .jumpHost)
        self.forwardAgent = try container.decodeIfPresent(Bool.self, forKey: .forwardAgent) ?? false
        self.compression = try container.decodeIfPresent(Bool.self, forKey: .compression) ?? false
        self.keepAliveInterval = try container.decodeIfPresent(Int.self, forKey: .keepAliveInterval)
        self.initialCommand = try container.decodeIfPresent(String.self, forKey: .initialCommand)
        self.environmentBadge = try container.decodeIfPresent(String.self, forKey: .environmentBadge)
        self.portForwards = try container.decodeIfPresent([PortForwardRule].self, forKey: .portForwards) ?? []
        self.sessionLogging = try container.decodeIfPresent(Bool.self, forKey: .sessionLogging) ?? false
        self.expectSendRules = try container.decodeIfPresent([ExpectSendRule].self, forKey: .expectSendRules) ?? []
        self.credentialReference = try container.decodeIfPresent(CredentialReference.self, forKey: .credentialReference)
    }

    public func buildProcessSpec() throws -> SSHProcessSpec {
        let errors = SessionValidator.validate(self)
        guard errors.isEmpty else { throw errors[0] }

        switch sessionType.lowercased() {
        case "telnet":
            return SSHProcessSpec(executable: "/usr/bin/telnet", arguments: [host, "\(port ?? 23)"])
        case "console":
            return SSHProcessSpec(executable: "/usr/bin/screen", arguments: [host, "\(port ?? 115200)"])
        default:
            var arguments = [
                "-o", "StrictHostKeyChecking=ask",
                "-o", "UserKnownHostsFile=\(("~/.ssh/known_hosts" as NSString).expandingTildeInPath)",
                "-o", "ServerAliveInterval=15",
                "-o", "ServerAliveCountMax=3",
                "-o", "ConnectionAttempts=3",
                "-o", "ConnectTimeout=10",
                "-o", "ControlMaster=auto",
                "-o", "ControlPath=/tmp/spectre-ssh-%C.sock",
                "-o", "ControlPersist=10m"
            ]
            if let port, port != 22 { arguments += ["-p", "\(port)"] }
            if let key = identityFile, !key.trimmingCharacters(in: .whitespaces).isEmpty {
                arguments += ["-i", (key as NSString).expandingTildeInPath]
            }
            if let jump = jumpHost, !jump.trimmingCharacters(in: .whitespaces).isEmpty { arguments += ["-J", jump] }
            if forwardAgent { arguments.append("-A") }
            if compression { arguments.append("-C") }
            if let interval = keepAliveInterval, interval > 0 { arguments += ["-o", "ServerAliveInterval=\(interval)"] }
            for forward in portForwards {
                switch forward.type {
                case .local: arguments += ["-L", "\(forward.localPort):\(forward.remoteHost):\(forward.remotePort)"]
                case .remote: arguments += ["-R", "\(forward.remotePort):\(forward.remoteHost):\(forward.localPort)"]
                case .dynamic: arguments += ["-D", "\(forward.localPort)"]
                }
            }
            let target = user.map { "\($0)@\(host)" } ?? host
            arguments.append(target)
            if let command = initialCommand, !command.trimmingCharacters(in: .whitespaces).isEmpty {
                arguments += ["-t", command]
            }
            return SSHProcessSpec(executable: "/usr/bin/ssh", arguments: arguments)
        }
    }

    public func buildConnectCommand() -> String {
        switch sessionType.lowercased() {
        case "telnet":
            let p = port ?? 23
            return "telnet \(host) \(p)"
        case "console":
            return "screen \(host) \(port ?? 115200)"
        default:
            var parts: [String] = ["ssh"]

            // Multiplexing for zero-handshake file transfers (SFTP / SCP)
            parts.append("-o ControlMaster=auto")
            parts.append("-o ControlPath=/tmp/spectre-ssh-%C.sock")
            parts.append("-o ControlPersist=10m")

            if let p = port, p != 22 {
                parts.append("-p \(p)")
            }

            if let key = identityFile, !key.trimmingCharacters(in: .whitespaces).isEmpty {
                let expanded = (key as NSString).expandingTildeInPath
                parts.append("-i \"\(expanded)\"")
            }

            if let jump = jumpHost, !jump.trimmingCharacters(in: .whitespaces).isEmpty {
                parts.append("-J \"\(jump)\"")
            }

            if forwardAgent {
                parts.append("-A")
            }

            if compression {
                parts.append("-C")
            }

            if let interval = keepAliveInterval, interval > 0 {
                parts.append("-o ServerAliveInterval=\(interval)")
            }

            for rule in portForwards {
                parts.append(rule.sshArgument)
            }

            var target = host
            if let u = user, !u.trimmingCharacters(in: .whitespaces).isEmpty {
                target = "\(u)@\(host)"
            }
            parts.append(target)

            if let cmd = initialCommand, !cmd.trimmingCharacters(in: .whitespaces).isEmpty {
                parts.append("-t \"\(cmd)\"")
            }

            return parts.joined(separator: " ")
        }
    }
}

// MARK: - Session File Envelope (Schema Versioning)

public struct SessionFileEnvelope: Codable {
    public static let currentVersion = 2
    public var version: Int
    public var sessions: [SavedSession]

    public init(version: Int = Self.currentVersion, sessions: [SavedSession]) {
        self.version = version
        self.sessions = sessions
    }
}

// MARK: - Session Library

@MainActor
public final class SessionLibrary: ObservableObject {
    public static let shared = SessionLibrary()

    @Published public var sessions: [SavedSession] = []

    private let fileURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let spectreproDir = appSupport.appendingPathComponent("co.skyones.spectrepro", isDirectory: true)
        try? FileManager.default.createDirectory(at: spectreproDir, withIntermediateDirectories: true)
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: spectreproDir.path)
        self.fileURL = spectreproDir.appendingPathComponent("sessions.json")
        load()
    }

    public func load() {
        var loaded: [SavedSession] = []
        if let data = try? Data(contentsOf: fileURL) {
            let decoder = JSONDecoder()
            if let envelope = try? decoder.decode(SessionFileEnvelope.self, from: data) {
                // Version 2+ envelope format
                loaded = envelope.sessions
            } else if let legacyList = try? decoder.decode([SavedSession].self, from: data) {
                // Legacy v1 format (bare array) — will be re-saved as envelope on next save
                loaded = legacyList
            }
        }

        // Auto-discover hosts from ~/.ssh/config if not already added
        let sshHosts = discoverSSHConfigHosts()
        for h in sshHosts {
            if !loaded.contains(where: { $0.host == h.host && $0.name == h.name }) {
                loaded.append(h)
            }
        }

        self.sessions = loaded
    }

    public func save(_ list: [SavedSession]? = nil) {
        let toSave = list ?? sessions
        self.sessions = toSave
        let envelope = SessionFileEnvelope(sessions: toSave)
        if let data = try? JSONEncoder().encode(envelope) {
            let temporaryURL = fileURL.appendingPathExtension("tmp")
            do {
                try data.write(to: temporaryURL, options: .atomic)
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: temporaryURL.path)
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: temporaryURL)
                } else {
                    try FileManager.default.moveItem(at: temporaryURL, to: fileURL)
                }
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
            } catch {
                try? FileManager.default.removeItem(at: temporaryURL)
            }
        }
    }

    public func add(_ s: SavedSession) {
        sessions.append(s)
        save()
    }

    public func update(_ s: SavedSession) {
        if let idx = sessions.firstIndex(where: { $0.id == s.id }) {
            sessions[idx] = s
            save()
        }
    }

    public func duplicate(_ s: SavedSession) {
        var cloned = s
        cloned.id = UUID()
        cloned.name = "\(s.name) (Copy)"
        // Duplicate session-level Keychain credential
        if let reference = s.credentialReference {
            cloned.credentialReference = try? SessionCredentialStore.shared.duplicate(from: reference)
        }
        // Duplicate per-rule Keychain credentials
        for i in cloned.expectSendRules.indices {
            if let ruleRef = cloned.expectSendRules[i].credentialReference {
                cloned.expectSendRules[i].credentialReference = try? SessionCredentialStore.shared.duplicate(from: ruleRef)
            }
        }
        sessions.append(cloned)
        save()
    }

    public func delete(_ s: SavedSession) {
        sessions.removeAll { $0.id == s.id }
        if let reference = s.credentialReference {
            try? SessionCredentialStore.shared.delete(reference)
        }
        save()
    }

    /// Collects all active credential references across sessions and asks the
    /// credential store to remove any Keychain entries that are no longer referenced.
    public func reconcileKeychainOrphans() {
        var activeReferences = Set<CredentialReference>()
        for session in sessions {
            if let ref = session.credentialReference {
                activeReferences.insert(ref)
            }
            for rule in session.expectSendRules {
                if let ref = rule.credentialReference {
                    activeReferences.insert(ref)
                }
            }
        }
        try? SessionCredentialStore.shared.reconcileOrphans(activeReferences: activeReferences)
    }

    public static func availableSSHKeys() -> [String] {
        let sshDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh")
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: sshDir.path) else {
            return []
        }

        let ignoredFiles: Set<String> = [
            "known_hosts", "known_hosts.old", "config", "authorized_keys",
            ".DS_Store"
        ]

        var keys: [String] = []
        for file in files {
            if ignoredFiles.contains(file) || file.hasSuffix(".pub") { continue }
            let fullPath = "~/.ssh/\(file)"
            keys.append(fullPath)
        }
        return keys.sorted()
    }

    public func discoverSSHConfigHosts() -> [SavedSession] {
        let sshConfigURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh/config")
        guard let content = try? String(contentsOf: sshConfigURL, encoding: .utf8) else { return [] }

        var results: [SavedSession] = []
        var currentHost: String? = nil
        var currentHostName: String? = nil
        var currentUser: String? = nil
        var currentPort: Int? = nil
        var currentKey: String? = nil
        var currentJump: String? = nil
        var currentForwardAgent = false
        var currentKeepAlive: Int? = nil

        let appendCurrent = {
            if let name = currentHost, !name.contains("*") && !name.contains("?") {
                results.append(SavedSession(
                    name: name,
                    folder: "SSH Config",
                    host: currentHostName ?? name,
                    user: currentUser,
                    port: currentPort ?? 22,
                    identityFile: currentKey,
                    jumpHost: currentJump,
                    forwardAgent: currentForwardAgent,
                    keepAliveInterval: currentKeepAlive
                ))
            }
        }

        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            let parts = trimmed.split(separator: " ", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let key = parts[0].lowercased()
            let val = parts[1].trimmingCharacters(in: .whitespaces)

            if key == "host" {
                appendCurrent()
                currentHost = val
                currentHostName = nil
                currentUser = nil
                currentPort = nil
                currentKey = nil
                currentJump = nil
                currentForwardAgent = false
                currentKeepAlive = nil
            } else if key == "hostname" {
                currentHostName = val
            } else if key == "user" {
                currentUser = val
            } else if key == "port" {
                currentPort = Int(val)
            } else if key == "identityfile" {
                currentKey = val
            } else if key == "proxyjump" {
                currentJump = val
            } else if key == "forwardagent" {
                currentForwardAgent = val.lowercased() == "yes"
            } else if key == "serveraliveinterval" {
                currentKeepAlive = Int(val)
            }
        }

        appendCurrent()
        return results
    }
}

// MARK: - Main View

public struct SessionManagerView: View {
    @ObservedObject var library = SessionLibrary.shared
    let surface: SpectrePro.SurfaceView?
    let onConnect: (String, Bool) -> Void
    var onSplitAndConnect: ((String) -> Void)? = nil

    @State private var searchText: String = ""
    @State private var isCreatingSession = false
    @State private var isAutomationHubPresented = false
    @State private var isWorkspaceHubPresented = false
    @State private var isFleetHubPresented = false
    @State private var editingSession: SavedSession? = nil
    @State private var collapsedFolders: Set<String> = []
    @State private var connectionError: String?

    init(
        surface: SpectrePro.SurfaceView?,
        onConnect: @escaping (String, Bool) -> Void,
        onSplitAndConnect: ((String) -> Void)? = nil
    ) {
        self.surface = surface
        self.onConnect = onConnect
        self.onSplitAndConnect = onSplitAndConnect
    }

    private var allFolders: [String] {
        let set = Set(library.sessions.map { $0.folder })
        return Array(set).sorted()
    }

    private var filteredSessions: [SavedSession] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return library.sessions
        }
        let q = searchText.lowercased()
        return library.sessions.filter {
            $0.name.lowercased().contains(q) || $0.host.lowercased().contains(q) || $0.folder.lowercased().contains(q)
        }
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                Text("Session Manager")
                    .font(.headline)
                Spacer()
                KeywordHighlightHUD()
                Button {
                    isFleetHubPresented = true
                } label: {
                    Image(systemName: "server.rack")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("Fleet Health & Inventory")
                .focusable(false)

                Button {
                    isWorkspaceHubPresented = true
                } label: {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("Operational Workspace & Incident Timeline")
                .focusable(false)

                Button {
                    isAutomationHubPresented = true
                } label: {
                    Image(systemName: "bolt.badge.automatic")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("Automation Hub & Multi-Session Plans")
                .focusable(false)

                Button {
                    isCreatingSession = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("Add New Session")
                .focusable(false)
            }

            SessionRecordingIndicator()

            // Search
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                TextField("Filter sessions...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.caption)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)

            // Folders Tree (SecureCRT Tree Layout)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(allFolders, id: \.self) { folder in
                        let sessionsInFolder = filteredSessions.filter { $0.folder == folder }
                        if !sessionsInFolder.isEmpty {
                            let isCollapsed = collapsedFolders.contains(folder)
                            VStack(alignment: .leading, spacing: 2) {
                                // Folder Header
                                Button {
                                    if isCollapsed {
                                        collapsedFolders.remove(folder)
                                    } else {
                                        collapsedFolders.insert(folder)
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 10)
                                        Image(systemName: "folder.fill")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.accentColor)
                                        Text(folder.uppercased())
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(.secondary)
                                        Text("(\(sessionsInFolder.count))")
                                            .font(.system(size: 9))
                                            .foregroundStyle(.secondary.opacity(0.7))
                                        Spacer()
                                    }
                                    .padding(.vertical, 3)
                                }
                                .buttonStyle(.plain)
                                .focusable(false)

                                if !isCollapsed {
                                    VStack(alignment: .leading, spacing: 2) {
                                        ForEach(sessionsInFolder) { session in
                                            SessionRowItem(
                                                session: session,
                                                onConnectHere: { handleConnect(session: session, inNewTab: false, inSplit: false) },
                                                onConnectNewTab: { handleConnect(session: session, inNewTab: true, inSplit: false) },
                                                onConnectSplit: { handleConnect(session: session, inNewTab: false, inSplit: true) },
                                                onEdit: { editingSession = session },
                                                onDuplicate: { library.duplicate(session) },
                                                onDelete: { library.delete(session) }
                                            )
                                        }
                                    }
                                    .padding(.leading, 14)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $isCreatingSession) {
            SessionEditorModal(sessionToEdit: nil) { newSession in
                library.add(newSession)
            }
        }
        .sheet(item: $editingSession) { session in
            SessionEditorModal(sessionToEdit: session) { updated in
                library.update(updated)
            }
        }
        .sheet(isPresented: $isAutomationHubPresented) {
            AutomationHubView()
        }
        .sheet(isPresented: $isWorkspaceHubPresented) {
            WorkspaceHubView()
        }
        .sheet(isPresented: $isFleetHubPresented) {
            FleetHubView()
        }
        .alert("Cannot Connect", isPresented: Binding(
            get: { connectionError != nil },
            set: { if !$0 { connectionError = nil } }
        )) {
            Button("OK", role: .cancel) { connectionError = nil }
        } message: {
            Text(connectionError ?? "Unknown connection error")
        }
    }

    private func handleConnect(session: SavedSession, inNewTab: Bool, inSplit: Bool) {
        let cmd: String
        do {
            cmd = try session.buildProcessSpec().shellCommand
        } catch {
            connectionError = error.localizedDescription
            return
        }

        if let surface = surface {
            let runtime = SessionRuntimeRegistry.shared.runtime(for: surface.id)
            runtime.reset()
            runtime.attach(session)
            if session.sessionLogging {
                runtime.logger.startRecording(sessionName: session.name)
            }
            if !session.expectSendRules.isEmpty {
                let storedSecret: String?
                if let reference = session.credentialReference {
                    storedSecret = try? SessionCredentialStore.shared.secret(for: reference)
                } else {
                    storedSecret = nil
                }
                runtime.automation.start(
                    rules: session.expectSendRules,
                    textReader: { [weak surface] in surface?.readVisibleText() ?? "" },
                    textSender: { [weak surface] text in surface?.surfaceModel?.sendText(text) },
                    secretProvider: { storedSecret }
                )
            }
        }

        if inSplit {
            onSplitAndConnect?(cmd)
        } else {
            onConnect(cmd, inNewTab)
        }
    }
}

// MARK: - Session Row Item

private struct SessionRowItem: View {
    let session: SavedSession
    let onConnectHere: () -> Void
    let onConnectNewTab: () -> Void
    let onConnectSplit: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    private var badgeColor: Color {
        guard let badge = session.environmentBadge?.uppercased() else { return .clear }
        switch badge {
        case "PROD": return .red
        case "STAGING": return .orange
        case "DEV": return .green
        case "LAB": return .cyan
        default: return .purple
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: session.sessionType == "console" ? "cable.connector" : "server.rack")
                .font(.system(size: 11))
                .foregroundStyle(Color.secondary)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(session.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)

                    if let badge = session.environmentBadge, !badge.isEmpty {
                        Text(badge)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(badgeColor)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(badgeColor.opacity(0.16))
                            .clipShape(Capsule())
                    }

                    if !session.portForwards.isEmpty {
                        Image(systemName: "arrow.triangle.swap")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .help("\(session.portForwards.count) port forward rules")
                    }

                    if session.identityFile != nil {
                        Image(systemName: "key.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                            .help("SSH Key attached")
                    }
                }

                Text(session.host)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isHovered {
                Button {
                    onConnectNewTab()
                } label: {
                    Image(systemName: "plus.rectangle")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Connect in New Tab")
                .focusable(false)
            }

            Menu {
                Button("Connect in Current Tab") { onConnectHere() }
                Button("Open in New Tab") { onConnectNewTab() }
                Button("Open in Split") { onConnectSplit() }
                Divider()
                Button("Edit Session...") { onEdit() }
                Button("Duplicate Session") { onDuplicate() }
                Button("Copy SSH Command") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(session.buildConnectCommand(), forType: .string)
                }
                Divider()
                if SessionLogger.shared.isRecording && SessionLogger.shared.currentSessionName == session.name {
                    Button("Stop Recording Session") {
                        _ = SessionLogger.shared.stopRecording()
                    }
                } else {
                    Button("Start Recording Session (.log)") {
                        SessionLogger.shared.startRecording(sessionName: session.name)
                    }
                }
                Divider()
                Button("Delete Session", role: .destructive) { onDelete() }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary.opacity(isHovered ? 0.9 : 0.0))
                    .frame(width: 16, height: 16)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .focusable(false)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { onConnectHere() }
        .contextMenu {
            Button("Connect in Current Tab") { onConnectHere() }
            Button("Open in New Tab") { onConnectNewTab() }
            Button("Open in Split") { onConnectSplit() }
            Divider()
            Button("Edit Session...") { onEdit() }
            Button("Duplicate Session") { onDuplicate() }
            Button("Copy SSH Command") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(session.buildConnectCommand(), forType: .string)
            }
            Divider()
            if SessionLogger.shared.isRecording && SessionLogger.shared.currentSessionName == session.name {
                Button("Stop Recording Session") {
                    _ = SessionLogger.shared.stopRecording()
                }
            } else {
                Button("Start Recording Session (.log)") {
                    SessionLogger.shared.startRecording(sessionName: session.name)
                }
            }
            Divider()
            Button("Delete Session", role: .destructive) { onDelete() }
        }
    }
}

// MARK: - Professional Session Editor Modal (Core Shell & SecureCRT Grade)

private struct SessionEditorModal: View {
    let sessionToEdit: SavedSession?
    let onSave: (SavedSession) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var activeTab: EditorTab = .general

    // General
    @State private var name: String = ""
    @State private var folder: String = "SSH"
    @State private var sessionType: String = "ssh"
    @State private var host: String = ""
    @State private var port: String = "22"
    @State private var user: String = ""
    @State private var environmentBadge: String = "None"

    // Authentication
    @State private var identityFile: String = ""
    @State private var forwardAgent: Bool = false
    @State private var credentialSecret: String = ""
    @State private var storeCredential: Bool = false
    @State private var credentialError: String?

    // Tunnels & Bastion
    @State private var jumpHost: String = ""
    @State private var portForwards: [PortForwardRule] = []

    // Advanced & Automation
    @State private var initialCommand: String = ""
    @State private var keepAliveInterval: String = ""
    @State private var compression: Bool = false
    @State private var sessionLogging: Bool = false
    @State private var expectSendRules: [ExpectSendRule] = []

    // Discovered keys cache
    @State private var discoveredKeys: [String] = []

    private enum EditorTab: String, CaseIterable, Identifiable {
        case general = "General"
        case authentication = "Authentication"
        case tunnels = "Tunnels & Bastion"
        case advanced = "Advanced"

        var id: String { rawValue }

        var iconName: String {
            switch self {
            case .general: return "slider.horizontal.3"
            case .authentication: return "key.fill"
            case .tunnels: return "arrow.triangle.swap"
            case .advanced: return "gearshape.fill"
            }
        }
    }

    init(sessionToEdit: SavedSession?, onSave: @escaping (SavedSession) -> Void) {
        self.sessionToEdit = sessionToEdit
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            // Modal Header
            HStack {
                Text(sessionToEdit == nil ? "New Session" : "Edit Session: \(name)")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Segmented Tab Picker
            Picker("", selection: $activeTab) {
                ForEach(EditorTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.iconName).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            Divider()

            // Tab Content
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch activeTab {
                    case .general:
                        generalTab
                    case .authentication:
                        authenticationTab
                    case .tunnels:
                        tunnelsTab
                    case .advanced:
                        advancedTab
                    }
                }
                .padding(16)
            }
            .frame(height: 340)

            Divider()

            // Modal Footer Actions
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .focusable(false)

                Button(sessionToEdit == nil ? "Create Session" : "Save Changes") {
                    saveSession()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || host.trimmingCharacters(in: .whitespaces).isEmpty)
                .focusable(false)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        }
        .frame(width: 480)
        .onAppear {
            loadInitialData()
        }
        .alert("Credential Storage Error", isPresented: Binding(
            get: { credentialError != nil },
            set: { if !$0 { credentialError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(credentialError ?? "Unable to update the Keychain.")
        }
    }

    // MARK: - Tab Views

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Session Name")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("e.g. Core-Switch-01 or Bastion Host", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Folder / Group")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("e.g. Production, Datacenter, Lab", text: $folder)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Protocol")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $sessionType) {
                        Text("SSH").tag("ssh")
                        Text("Telnet").tag("telnet")
                        Text("Console").tag("console")
                    }
                    .labelsHidden()
                }
                .frame(width: 110)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Host / IP Address")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("hostname, IPv4 or IPv6", text: $host)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Port")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("22", text: $port)
                        .textFieldStyle(.roundedBorder)
                }
                .frame(width: 80)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Username (optional)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("e.g. admin, root, ec2-user", text: $user)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Environment Badge")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("", selection: $environmentBadge) {
                    Text("None").tag("None")
                    Text("🔴 PROD").tag("PROD")
                    Text("🟠 STAGING").tag("STAGING")
                    Text("🟢 DEV").tag("DEV")
                    Text("🔵 LAB").tag("LAB")
                }
                .labelsHidden()
            }
        }
    }

    private var authenticationTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SSH KEY AUTHENTICATION")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Identity File (Private Key)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    TextField("~/.ssh/id_ed25519 or path to private key", text: $identityFile)
                        .textFieldStyle(.roundedBorder)

                    if !discoveredKeys.isEmpty {
                        Menu {
                            Button("Clear Key") { identityFile = "" }
                            Divider()
                            ForEach(discoveredKeys, id: \.self) { keyPath in
                                Button(keyPath) {
                                    identityFile = keyPath
                                }
                            }
                        } label: {
                            Image(systemName: "key")
                                .font(.system(size: 11))
                        }
                        .menuStyle(.borderlessButton)
                        .frame(width: 24)
                        .help("Pick from discovered ~/.ssh/ keys")
                    }

                    Button("Browse...") {
                        selectKeyFile()
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            Divider()

            Toggle(isOn: $forwardAgent) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Forward SSH Agent (-A)")
                        .font(.system(size: 12, weight: .medium))
                    Text("Allows remote servers to authenticate using your local ssh-agent credentials.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.checkbox)

            Divider()

            Text("CREDENTIAL STORAGE")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)

            SecureField("Password or passphrase", text: $credentialSecret)
                .textFieldStyle(.roundedBorder)

            Toggle(isOn: $storeCredential) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Store in macOS Keychain")
                        .font(.system(size: 12, weight: .medium))
                    Text(storeCredential && sessionToEdit?.credentialReference != nil
                         ? "A new value replaces the saved credential when you save."
                         : "The secret is never written to the session file.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.checkbox)

            if sessionToEdit?.credentialReference != nil {
                Label("A credential is already saved for this session.", systemImage: "checkmark.shield")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var tunnelsTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("BASTION / JUMP HOST (-J)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                TextField("e.g. jumpuser@bastion.corp.net:22", text: $jumpHost)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
            }

            Divider()

            HStack {
                Text("PORT FORWARDING TUNNELS (\(portForwards.count))")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("+ Add Tunnel") {
                    portForwards.append(PortForwardRule(localPort: 8080, remoteHost: "localhost", remotePort: 80))
                }
                .font(.system(size: 10, weight: .medium))
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if portForwards.isEmpty {
                Text("No port forward rules defined. Add local (-L), remote (-R), or SOCKS5 (-D) tunnels.")
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(0.8))
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 6) {
                    ForEach($portForwards) { $rule in
                        HStack(spacing: 6) {
                            Picker("", selection: $rule.type) {
                                ForEach(PortForwardType.allCases) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 130)

                            TextField("Local Port", value: $rule.localPort, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)

                            if rule.type != .dynamic {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)

                                TextField("Remote Host", text: $rule.remoteHost)
                                    .textFieldStyle(.roundedBorder)

                                TextField("Remote Port", value: $rule.remotePort, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 55)
                            } else {
                                Text("(SOCKS5 Proxy on localhost:\(rule.localPort))")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }

                            Button {
                                portForwards.removeAll { $0.id == rule.id }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.red.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                            .focusable(false)
                        }
                        .padding(6)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(6)
                    }
                }
            }
        }
    }

    private var advancedTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("INITIAL COMMAND POST-LOGIN (-t)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                TextField("e.g. tmux new -A -s main or sudo su -", text: $initialCommand)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("KeepAlive Interval (secs)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("e.g. 30", text: $keepAliveInterval)
                        .textFieldStyle(.roundedBorder)
                }
                .frame(width: 140)

                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Enable Compression (-C)", isOn: $compression)
                        .font(.system(size: 11))
                    Toggle("Auto Session Logging (.log)", isOn: $sessionLogging)
                        .font(.system(size: 11))
                }
            }

            Divider()

            HStack {
                Text("EXPECT / SEND LOGON AUTOMATION (\(expectSendRules.count))")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("+ Add Step") {
                    expectSendRules.append(ExpectSendRule(expect: "Password:", send: ""))
                }
                .font(.system(size: 10, weight: .medium))
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if expectSendRules.isEmpty {
                Text("No logon triggers defined. Automate prompt responses (e.g. Cisco enable, OTP prompts).")
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(0.8))
            } else {
                VStack(spacing: 4) {
                    ForEach($expectSendRules) { $step in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                            TextField("Expect (e.g. Password:)", text: $step.expect)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 160)

                            Image(systemName: "arrow.right")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)

                            if step.credentialReference != nil {
                                HStack(spacing: 4) {
                                    Text("🔑 Keychain")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                    Button {
                                        if let ref = step.credentialReference {
                                            try? SessionCredentialStore.shared.delete(ref)
                                        }
                                        step.credentialReference = nil
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } else if step.expect.range(of: "password|passphrase|secret", options: [.regularExpression, .caseInsensitive]) != nil {
                                HStack(spacing: 4) {
                                    SecureField("Send (secret)", text: $step.send)
                                        .textFieldStyle(.roundedBorder)
                                    Button {
                                        let ref = CredentialReference()
                                        try? SessionCredentialStore.shared.save(secret: step.send, for: ref)
                                        step.credentialReference = ref
                                        step.send = ""
                                    } label: {
                                        Image(systemName: "key.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.orange)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Store in Keychain")
                                    .disabled(step.send.isEmpty)
                                }
                            } else {
                                TextField("Send (e.g. password or enable)", text: $step.send)
                                    .textFieldStyle(.roundedBorder)
                            }

                                Button {
                                expectSendRules.removeAll { $0.id == step.id }
                                } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.red.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                                .focusable(false)
                            }

                            HStack(spacing: 8) {
                                Picker("Match", selection: $step.matchMode) {
                                    ForEach(ExpectSendMatchMode.allCases) { mode in
                                        Text(mode.title).tag(mode)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 90)
                                TextField("Timeout", value: $step.timeoutSeconds, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 70)
                                Text("sec").foregroundStyle(.secondary)
                                Stepper("Retries \(step.retryCount)", value: $step.retryCount, in: 0...10)
                                    .controlSize(.small)
                                Toggle("Continue on failure", isOn: $step.continueOnFailure)
                                    .toggleStyle(.checkbox)
                                    .controlSize(.small)
                            }
                            .font(.system(size: 10))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func loadInitialData() {
        discoveredKeys = SessionLibrary.availableSSHKeys()

        if let s = sessionToEdit {
            name = s.name
            folder = s.folder
            sessionType = s.sessionType
            host = s.host
            port = "\(s.port ?? 22)"
            user = s.user ?? ""
            environmentBadge = s.environmentBadge ?? "None"
            identityFile = s.identityFile ?? ""
            forwardAgent = s.forwardAgent
            jumpHost = s.jumpHost ?? ""
            portForwards = s.portForwards
            initialCommand = s.initialCommand ?? ""
            if let keepAlive = s.keepAliveInterval {
                keepAliveInterval = "\(keepAlive)"
            }
            compression = s.compression
            sessionLogging = s.sessionLogging
            expectSendRules = s.expectSendRules
            storeCredential = s.credentialReference != nil
        }
    }

    private func selectKeyFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh")

        if panel.runModal() == .OK, let url = panel.url {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            if url.path.hasPrefix(home) {
                identityFile = url.path.replacingOccurrences(of: home, with: "~")
            } else {
                identityFile = url.path
            }
        }
    }

    private func saveSession() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedHost = host.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, !trimmedHost.isEmpty else { return }

        let existingReference = sessionToEdit?.credentialReference
        let credentialReference: CredentialReference?
        do {
            if storeCredential {
                let reference = existingReference ?? CredentialReference()
                if !credentialSecret.isEmpty {
                    try SessionCredentialStore.shared.save(secret: credentialSecret, for: reference)
                }
                credentialReference = reference
            } else {
                if let existingReference {
                    try SessionCredentialStore.shared.delete(existingReference)
                }
                credentialReference = nil
            }
        } catch {
            credentialError = error.localizedDescription
            return
        }

        let s = SavedSession(
            id: sessionToEdit?.id ?? UUID(),
            name: trimmedName,
            folder: folder.trimmingCharacters(in: .whitespaces).isEmpty ? "SSH" : folder.trimmingCharacters(in: .whitespaces),
            host: trimmedHost,
            user: user.trimmingCharacters(in: .whitespaces).isEmpty ? nil : user.trimmingCharacters(in: .whitespaces),
            port: Int(port) ?? 22,
            sessionType: sessionType,
            identityFile: identityFile.trimmingCharacters(in: .whitespaces).isEmpty ? nil : identityFile.trimmingCharacters(in: .whitespaces),
            jumpHost: jumpHost.trimmingCharacters(in: .whitespaces).isEmpty ? nil : jumpHost.trimmingCharacters(in: .whitespaces),
            forwardAgent: forwardAgent,
            compression: compression,
            keepAliveInterval: Int(keepAliveInterval),
            initialCommand: initialCommand.trimmingCharacters(in: .whitespaces).isEmpty ? nil : initialCommand.trimmingCharacters(in: .whitespaces),
            environmentBadge: environmentBadge == "None" ? nil : environmentBadge,
            portForwards: portForwards,
            sessionLogging: sessionLogging,
            expectSendRules: expectSendRules,
            credentialReference: credentialReference
        )

        onSave(s)
        dismiss()
    }
}
