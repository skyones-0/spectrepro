import Foundation

public enum SSHAuthenticationMethod: String, Codable, CaseIterable, Identifiable, Sendable {
    case automatic
    case identityFile
    case yubikeyPIV
    case yubikeyFIDO2

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .automatic: return "Automatic"
        case .identityFile: return "SSH key file"
        case .yubikeyPIV: return "YubiKey PIV"
        case .yubikeyFIDO2: return "YubiKey FIDO2"
        }
    }
}

public struct YubiKeyDetectionResult: Equatable, Sendable {
    public var pkcs11LibraryPath: String?
    public var pivPublicKeys: [String]
    public var sshExecutablePath: String
    public var supportsFIDO2: Bool

    public var summary: String {
        if !pivPublicKeys.isEmpty && supportsFIDO2 { return "PIV keys and FIDO2 support detected" }
        if !pivPublicKeys.isEmpty { return "PIV keys detected" }
        if pkcs11LibraryPath != nil && supportsFIDO2 { return "PIV library and FIDO2 support detected" }
        if pkcs11LibraryPath != nil { return "PIV library detected" }
        if supportsFIDO2 { return "FIDO2 support detected" }
        return "No YubiKey SSH support detected"
    }
}

public enum YubiKeyDetector {
    private static let pkcs11Candidates = [
        "/opt/homebrew/lib/libykcs11.dylib",
        "/usr/local/lib/libykcs11.dylib",
        "/Library/Application Support/Yubico/libykcs11.dylib"
    ]

    private static let sshCandidates = [
        "/opt/homebrew/bin/ssh",
        "/usr/local/bin/ssh",
        "/usr/bin/ssh"
    ]

    private static let cacheLock = NSLock()
    private static var cachedResult: (result: YubiKeyDetectionResult, date: Date)?
    private static let cacheLifetime: TimeInterval = 30

    public static func sshExecutable(for method: SSHAuthenticationMethod) -> String {
        guard method == .yubikeyFIDO2 else { return "/usr/bin/ssh" }
        let fileManager = FileManager.default
        return sshCandidates.first { fileManager.isExecutableFile(atPath: $0) } ?? "/usr/bin/ssh"
    }

    public static func detect(forceRefresh: Bool = false) async -> YubiKeyDetectionResult {
        if !forceRefresh {
            cacheLock.lock()
            let cached = cachedResult
            cacheLock.unlock()
            if let cached, Date().timeIntervalSince(cached.date) < cacheLifetime {
                return cached.result
            }
        }

        return await Task.detached(priority: .utility) {
            let fileManager = FileManager.default
            let processArchitecture = commandOutput(executable: "/usr/bin/arch", arguments: [])?.trimmingCharacters(in: .whitespacesAndNewlines)
            let library = pkcs11Candidates.first { path in
                guard fileManager.isReadableFile(atPath: path) else { return false }
                guard let processArchitecture, !processArchitecture.isEmpty else { return true }
                guard let libraryDescription = commandOutput(executable: "/usr/bin/file", arguments: [path]) else { return false }
                return libraryDescription.contains(processArchitecture)
            }
            let sshPath = sshCandidates.first { fileManager.isExecutableFile(atPath: $0) } ?? "/usr/bin/ssh"
            let supportsFIDO2 = commandOutput(executable: sshPath, arguments: ["-Q", "key"])?.contains("sk-") == true
            let pivKeys: [String] = library.flatMap { provider -> [String]? in
                let resolvedProvider = URL(fileURLWithPath: provider).resolvingSymlinksInPath().path
                AppDiagnostics.event("Enumerating PIV keys with provider path \(resolvedProvider).", category: "YubiKey")
                return commandOutput(executable: "/usr/bin/ssh-keygen", arguments: ["-D", resolvedProvider])
                    .map { output in output.split(whereSeparator: { character in character.isNewline }).map(String.init) }
            } ?? []
            let result = YubiKeyDetectionResult(
                pkcs11LibraryPath: library,
                pivPublicKeys: pivKeys,
                sshExecutablePath: sshPath,
                supportsFIDO2: supportsFIDO2
            )
            cacheLock.lock()
            cachedResult = (result, Date())
            cacheLock.unlock()
            return result
        }.value
    }

    private static func commandOutput(executable: String, arguments: [String]) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            let termination = DispatchGroup()
            termination.enter()
            process.terminationHandler = { _ in termination.leave() }
            try process.run()
            guard termination.wait(timeout: .now() + 3) == .success else {
                process.terminate()
                return nil
            }
            guard process.terminationStatus == 0 else { return nil }
            return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        } catch {
            return nil
        }
    }
}
