import AppKit
import Darwin
import Foundation

public struct YubiKeyPINRequest: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let serial: UInt32
    public let retries: Int
    public let sessionID: UUID

    public init(id: UUID = UUID(), serial: UInt32, retries: Int, sessionID: UUID) {
        self.id = id
        self.serial = serial
        self.retries = retries
        self.sessionID = sessionID
    }
}

public enum YubiKeyAuthenticationState: Equatable, Sendable {
    case idle
    case detecting
    case waitingForPIN(YubiKeyPINRequest)
    case waitingForTouch
    case authenticating
    case authenticated
    case failed(String)
}

public enum YubiKeyAuthenticationError: LocalizedError, Equatable {
    case unavailable
    case cancelled
    case timeout
    case tokenRemoved
    case helperUnavailable
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .unavailable: return "No compatible YubiKey PIV helper is available."
        case .cancelled: return "YubiKey authentication was cancelled."
        case .timeout: return "YubiKey PIN request timed out."
        case .tokenRemoved: return "The YubiKey was removed during authentication."
        case .helperUnavailable: return "Spectre Pro could not start its YubiKey helper."
        case .invalidResponse: return "The YubiKey helper returned an invalid response."
        }
    }
}

private struct YubiKeyPromptMessage: Codable, Sendable {
    let type: String
    let serial: UInt32?
    let retries: Int?
    let token: String
    let pin: String?
    let error: String?
}

@MainActor
public final class YubiKeyAuthenticationCoordinator: ObservableObject {
    @Published public private(set) var state: YubiKeyAuthenticationState = .idle
    @Published public private(set) var detection: YubiKeyDetectionResult?

    public let sessionID: UUID
    private var helperProcess: Process?
    private var promptServer: YubiKeyPromptServer?
    private var pinContinuation: CheckedContinuation<String, Error>?
    private var requestTimeoutTask: Task<Void, Never>?
    private var detectionTask: Task<Void, Never>?
    private var authSocketPath: String?
    private var pinSocketPath: String?
    private var authToken: String?

    public init(sessionID: UUID) {
        self.sessionID = sessionID
    }

    deinit {
        detectionTask?.cancel()
        requestTimeoutTask?.cancel()
        helperProcess?.terminate()
        promptServer?.stop()
    }

    public var isYubiKeyPresent: Bool {
        guard let detection else { return false }
        return detection.pkcs11LibraryPath != nil && !detection.pivPublicKeys.isEmpty
    }

    public var identityAgentPath: String? { authSocketPath }

    public func prepare(for session: SavedSession) async throws {
        stop()
        guard session.sessionType.lowercased() == "ssh", session.sshAuthentication == .yubikeyPIV else {
            state = .idle
            return
        }

        state = .detecting
        let result = await YubiKeyDetector.detect(forceRefresh: true)
        detection = result
        guard result.pkcs11LibraryPath != nil, !result.pivPublicKeys.isEmpty else {
            state = .failed(YubiKeyAuthenticationError.unavailable.localizedDescription)
            throw YubiKeyAuthenticationError.unavailable
        }

        guard let helperURL = Bundle.main.url(forResource: "SpectreProYubiKeyAgent", withExtension: nil, subdirectory: "Helpers") else {
            state = .failed(YubiKeyAuthenticationError.helperUnavailable.localizedDescription)
            throw YubiKeyAuthenticationError.helperUnavailable
        }

        #if !DEBUG
        guard Self.isSignedHelper(helperURL) else {
            state = .failed(YubiKeyAuthenticationError.helperUnavailable.localizedDescription)
            throw YubiKeyAuthenticationError.helperUnavailable
        }
        #endif

        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("co.skyones.spectrepro", isDirectory: true)
            .appendingPathComponent("yubikey", isDirectory: true)
            .appendingPathComponent(sessionID.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)

        let agentSocket = directory.appendingPathComponent("agent.sock").path
        let promptSocket = directory.appendingPathComponent("prompt.sock").path
        let token = UUID().uuidString + UUID().uuidString
        let server = try YubiKeyPromptServer(path: promptSocket, token: token) { [weak self] message in
            await self?.handlePrompt(message) ?? YubiKeyPromptMessage(
                type: "error", serial: nil, retries: nil, token: message.token, pin: nil, error: "session ended")
        }
        promptServer = server
        try server.start()

        let process = Process()
        process.executableURL = helperURL
        process.arguments = ["-l", agentSocket, "-p", promptSocket, "-t", token]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()

        helperProcess = process
        authSocketPath = agentSocket
        pinSocketPath = promptSocket
        authToken = token
        state = .authenticating
        detectionTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard let self else { return }
                let current = await YubiKeyDetector.detect()
                self.detection = current
                if current.pivPublicKeys.isEmpty {
                    self.state = .failed(YubiKeyAuthenticationError.tokenRemoved.localizedDescription)
                    return
                }
            }
        }
    }

    public func acceptPIN(_ pin: String) {
        guard !pin.isEmpty else { return }
        pinContinuation?.resume(returning: pin)
        pinContinuation = nil
        requestTimeoutTask?.cancel()
        requestTimeoutTask = nil
        state = .waitingForTouch
    }

    public func cancelPIN() {
        pinContinuation?.resume(throwing: YubiKeyAuthenticationError.cancelled)
        pinContinuation = nil
        requestTimeoutTask?.cancel()
        requestTimeoutTask = nil
        state = .failed(YubiKeyAuthenticationError.cancelled.localizedDescription)
    }

    public func markAuthenticated() {
        state = .authenticated
    }

    public func stop() {
        pinContinuation?.resume(throwing: YubiKeyAuthenticationError.cancelled)
        pinContinuation = nil
        requestTimeoutTask?.cancel()
        requestTimeoutTask = nil
        detectionTask?.cancel()
        detectionTask = nil
        helperProcess?.terminate()
        helperProcess = nil
        promptServer?.stop()
        promptServer = nil
        cleanupSocketPaths()
        authSocketPath = nil
        pinSocketPath = nil
        authToken = nil
        state = .idle
    }

    private func handlePrompt(_ message: YubiKeyPromptMessage) async -> YubiKeyPromptMessage {
        guard message.token == authToken, message.type == "pin", let serial = message.serial else {
            return YubiKeyPromptMessage(type: "error", serial: nil, retries: nil, token: message.token, pin: nil, error: "invalid request")
        }

        let request = YubiKeyPINRequest(serial: serial, retries: message.retries ?? 0, sessionID: sessionID)
        state = .waitingForPIN(request)
        do {
            let pin = try await withCheckedThrowingContinuation { continuation in
                pinContinuation = continuation
                requestTimeoutTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(90))
                    guard let self, self.pinContinuation != nil else { return }
                    self.pinContinuation?.resume(throwing: YubiKeyAuthenticationError.timeout)
                    self.pinContinuation = nil
                    self.state = .failed(YubiKeyAuthenticationError.timeout.localizedDescription)
                }
            }
            return YubiKeyPromptMessage(type: "pin", serial: nil, retries: nil, token: message.token, pin: pin, error: nil)
        } catch {
            return YubiKeyPromptMessage(type: "error", serial: nil, retries: nil, token: message.token, pin: nil, error: error.localizedDescription)
        }
    }

    private func cleanupSocketPaths() {
        for path in [authSocketPath, pinSocketPath].compactMap({ $0 }) {
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    private static func isSignedHelper(_ url: URL) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--verify", "--strict", url.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}

private final class YubiKeyPromptServer: @unchecked Sendable {
    private let path: String
    private let token: String
    private let handler: @Sendable (YubiKeyPromptMessage) async -> YubiKeyPromptMessage
    private var fileDescriptor: Int32 = -1
    private var task: Task<Void, Never>?

    init(path: String, token: String, handler: @escaping @Sendable (YubiKeyPromptMessage) async -> YubiKeyPromptMessage) throws {
        self.path = path
        self.token = token
        self.handler = handler
    }

    func start() throws {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8) + [0]
        guard bytes.count <= MemoryLayout.size(ofValue: address.sun_path) else { throw YubiKeyAuthenticationError.helperUnavailable }
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            buffer.copyBytes(from: bytes)
        }

        fileDescriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fileDescriptor >= 0 else { throw YubiKeyAuthenticationError.helperUnavailable }
        unlink(path)
        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fileDescriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0, listen(fileDescriptor, 1) == 0 else {
            close(fileDescriptor)
            throw YubiKeyAuthenticationError.helperUnavailable
        }
        chmod(path, 0o600)

        let descriptor = fileDescriptor
        task = Task.detached { [handler, token] in
            while !Task.isCancelled {
                let client = accept(descriptor, nil, nil)
                guard client >= 0 else { break }
                defer { close(client) }
                var data = Data()
                var byte: UInt8 = 0
                while read(client, &byte, 1) == 1 {
                    if byte == 10 { break }
                    data.append(byte)
                    if data.count > 4096 { break }
                }
                guard var message = try? JSONDecoder().decode(YubiKeyPromptMessage.self, from: data), message.token == token else { continue }
                message = await handler(message)
                if let response = try? JSONEncoder().encode(message) {
                    _ = response.withUnsafeBytes { write(client, $0.baseAddress, response.count) }
                    var newline: UInt8 = 10
                    _ = write(client, &newline, 1)
                }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        if fileDescriptor >= 0 {
            shutdown(fileDescriptor, SHUT_RDWR)
            close(fileDescriptor)
            fileDescriptor = -1
        }
        unlink(path)
    }
}
