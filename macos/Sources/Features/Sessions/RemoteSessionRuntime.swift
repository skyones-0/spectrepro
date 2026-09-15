import Foundation

@MainActor
public final class RemoteSessionRuntime: ObservableObject {
    public let surfaceID: UUID
    public let logger: SessionLogger
    public let automation: ExpectSendEngine
    public let transfers: SSHTransferManager
    public let reconnect: SSHReconnectController
    public let credentialStore: SessionCredentialStore

    public private(set) var session: SavedSession?

    public init(surfaceID: UUID) {
        self.surfaceID = surfaceID
        self.logger = SessionLogger()
        self.automation = ExpectSendEngine()
        self.transfers = SSHTransferManager()
        self.reconnect = SSHReconnectController()
        self.credentialStore = SessionCredentialStore()
    }

    public func attach(_ session: SavedSession) {
        self.session = session
        transfers.registerContext(for: surfaceID, session: session)
    }

    /// Convenience wrapper that resolves a credential from the per-session store.
    public func resolveCredential(_ reference: CredentialReference) -> String? {
        return try? credentialStore.secret(for: reference)
    }

    public func reset() {
        automation.cancel()
        reconnect.reset()
        transfers.reset(surfaceId: surfaceID)
        _ = logger.stopRecording()
        // Credentials are NOT cleared from Keychain on reset — they persist
        // until the session is explicitly deleted via SessionLibrary.delete(_:).
        session = nil
    }
}

@MainActor
public final class SessionRuntimeRegistry {
    public static let shared = SessionRuntimeRegistry()

    private var runtimes: [UUID: RemoteSessionRuntime] = [:]

    private init() {}

    public func runtime(for surfaceID: UUID) -> RemoteSessionRuntime {
        if let runtime = runtimes[surfaceID] { return runtime }
        let runtime = RemoteSessionRuntime(surfaceID: surfaceID)
        runtimes[surfaceID] = runtime
        return runtime
    }

    public func remove(surfaceID: UUID) {
        runtimes.removeValue(forKey: surfaceID)?.reset()
    }

    public var activeSurfaceIDs: Set<UUID> {
        Set(runtimes.keys)
    }
}
