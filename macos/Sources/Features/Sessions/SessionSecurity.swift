import Foundation
import Security

public struct CredentialReference: Codable, Equatable, Hashable, Sendable {
    public let id: UUID

    public init(id: UUID = UUID()) {
        self.id = id
    }
}

public enum SessionCredentialStoreError: Error, LocalizedError {
    case invalidData
    case keychain(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .invalidData:
            return "The credential data is invalid."
        case .keychain(let status):
            return "Keychain operation failed with status \(status)."
        }
    }
}

public final class SessionCredentialStore: @unchecked Sendable {
    public static let shared = SessionCredentialStore()

    private let service = "co.skyones.spectrepro.credentials"

    public init() {}

    public func save(secret: String, for reference: CredentialReference) throws {
        guard let data = secret.data(using: .utf8) else {
            throw SessionCredentialStoreError.invalidData
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: reference.id.uuidString
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            let addStatus = SecItemAdd(item as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw SessionCredentialStoreError.keychain(addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw SessionCredentialStoreError.keychain(updateStatus)
        }
    }

    public func secret(for reference: CredentialReference) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: reference.id.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw SessionCredentialStoreError.keychain(status)
        }
        guard let data = result as? Data, let secret = String(data: data, encoding: .utf8) else {
            throw SessionCredentialStoreError.invalidData
        }
        return secret
    }

    public func delete(_ reference: CredentialReference) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: reference.id.uuidString
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SessionCredentialStoreError.keychain(status)
        }
    }

    /// Enumerate all Keychain items stored under the credential service.
    public func allReferences() throws -> [CredentialReference] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess else {
            throw SessionCredentialStoreError.keychain(status)
        }
        guard let items = result as? [[String: Any]] else { return [] }
        return items.compactMap { item in
            guard let account = item[kSecAttrAccount as String] as? String,
                  let uuid = UUID(uuidString: account) else { return nil }
            return CredentialReference(id: uuid)
        }
    }

    /// Delete any Keychain items that are NOT in the provided active set.
    public func reconcileOrphans(activeReferences: Set<CredentialReference>) throws {
        let stored = try allReferences()
        for ref in stored where !activeReferences.contains(ref) {
            try delete(ref)
        }
    }

    /// Duplicate a credential: read its secret, create a new reference, store under the new reference.
    public func duplicate(from source: CredentialReference) throws -> CredentialReference? {
        guard let existingSecret = try secret(for: source) else { return nil }
        let newRef = CredentialReference()
        try save(secret: existingSecret, for: newRef)
        return newRef
    }
}

// MARK: - Credential Resolver Protocol

/// Protocol that abstracts credential store operations for dependency injection.
@MainActor
public protocol SessionCredentialResolver {
    func resolve(_ reference: CredentialReference) throws -> String?
    func store(secret: String, for reference: CredentialReference) throws
    func delete(_ reference: CredentialReference) throws
}

/// Default implementation that delegates to a `SessionCredentialStore` instance.
@MainActor
public final class DefaultSessionCredentialResolver: SessionCredentialResolver {
    private let credentialStore: SessionCredentialStore

    public init(store: SessionCredentialStore = .shared) {
        self.credentialStore = store
    }

    public func resolve(_ reference: CredentialReference) throws -> String? {
        try credentialStore.secret(for: reference)
    }

    public func store(secret: String, for reference: CredentialReference) throws {
        try credentialStore.save(secret: secret, for: reference)
    }

    public func delete(_ reference: CredentialReference) throws {
        try credentialStore.delete(reference)
    }
}

public enum SessionValidationError: Error, LocalizedError, Equatable {
    case emptyName
    case invalidHost
    case invalidUser
    case invalidPort
    case invalidIdentityFile
    case invalidPKCS11Provider
    case invalidKexAlgorithms
    case invalidJumpHost
    case invalidForward
    case unsupportedSessionType

    public var errorDescription: String? {
        switch self {
        case .emptyName: return "Session name cannot be empty."
        case .invalidHost: return "Host must be a valid hostname, IP address, or serial device path."
        case .invalidUser: return "Username contains unsupported characters."
        case .invalidPort: return "Port must be between 1 and 65535."
        case .invalidIdentityFile: return "Identity file path is invalid."
        case .invalidPKCS11Provider: return "PKCS#11 provider path is invalid."
        case .invalidKexAlgorithms: return "Key exchange algorithms contain unsupported characters or an empty entry."
        case .invalidJumpHost: return "Jump host is invalid."
        case .invalidForward: return "Port forwarding rule is invalid."
        case .unsupportedSessionType: return "Session type is not supported."
        }
    }
}

public enum SessionValidator {
    public static func validate(_ session: SavedSession) -> [SessionValidationError] {
        var errors: [SessionValidationError] = []
        if session.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyName)
        }

        let type = session.sessionType.lowercased()
        guard ["ssh", "console", "telnet"].contains(type) else {
            errors.append(.unsupportedSessionType)
            return errors
        }

        if type == "console" {
            if !session.host.hasPrefix("/dev/") { errors.append(.invalidHost) }
            if let baud = session.port, !(1...4_000_000).contains(baud) { errors.append(.invalidPort) }
            return errors
        }

        if !isValidHost(session.host) { errors.append(.invalidHost) }
        if let user = session.user, !user.isEmpty,
           user.range(of: #"^[A-Za-z0-9._-]+$"#, options: .regularExpression) == nil {
            errors.append(.invalidUser)
        }
        let port = session.port ?? (type == "telnet" ? 23 : 22)
        if !(1...65535).contains(port) { errors.append(.invalidPort) }
        if let identity = session.identityFile, !identity.isEmpty,
           identity.contains("\n") || identity.contains("\r") || identity.hasPrefix("-") {
            errors.append(.invalidIdentityFile)
        }
        if let provider = session.pkcs11Provider, !provider.isEmpty,
           provider.contains("\n") || provider.contains("\r") || provider.hasPrefix("-") {
            errors.append(.invalidPKCS11Provider)
        }
        if let kexAlgorithms = session.kexAlgorithms,
           !kexAlgorithms.isEmpty,
           !isValidKexAlgorithms(kexAlgorithms) {
            errors.append(.invalidKexAlgorithms)
        }
        if let jump = session.jumpHost, !jump.isEmpty, !isValidHost(jump) {
            errors.append(.invalidJumpHost)
        }
        if session.portForwards.contains(where: { !validateForward($0) }) {
            errors.append(.invalidForward)
        }
        return errors
    }

    private static func isValidHost(_ host: String) -> Bool {
        guard !host.isEmpty, host.count <= 253,
              !host.contains("\n"), !host.contains("\r"), !host.contains(" ") else { return false }
        return host.range(of: #"^[A-Za-z0-9._:%\[\]-]+$"#, options: .regularExpression) != nil
    }

    private static func validateForward(_ forward: PortForwardRule) -> Bool {
        guard (1...65535).contains(forward.localPort),
              (1...65535).contains(forward.remotePort),
              !forward.remoteHost.isEmpty,
              !forward.remoteHost.contains(where: { $0 == "\n" || $0 == "\r" || $0 == " " }) else { return false }
        return true
    }

    private static func isValidKexAlgorithms(_ value: String) -> Bool {
        guard value.count <= 1_024 else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "@._+-^"))
        return value.split(separator: ",", omittingEmptySubsequences: false).allSatisfy { token in
            !token.isEmpty && token.unicodeScalars.allSatisfy(allowed.contains)
        }
    }
}

public struct SSHProcessSpec: Equatable, Sendable {
    public let executable: String
    public let arguments: [String]

    public init(executable: String, arguments: [String]) {
        self.executable = executable
        self.arguments = arguments
    }

    public var shellCommand: String {
        ([executable] + arguments).map(Self.quote).joined(separator: " ")
    }

    private static func quote(_ value: String) -> String {
        guard value.range(of: #"^[A-Za-z0-9_./:@%+=,-]+$"#, options: .regularExpression) != nil else {
            return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
        }
        return value
    }
}
