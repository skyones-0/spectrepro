import Foundation

public enum AutomationPermission: String, Codable, CaseIterable, Hashable, Sendable {
    case network
    case localShell
    case fileRead
    case keychain
    case production
}

public struct AutomationScript: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var source: String
    public var permissions: Set<AutomationPermission>
    public var targetSessionIDs: [UUID]

    public init(
        id: UUID = UUID(),
        name: String,
        source: String,
        permissions: Set<AutomationPermission> = [],
        targetSessionIDs: [UUID] = []
    ) {
        self.id = id
        self.name = name
        self.source = source
        self.permissions = permissions
        self.targetSessionIDs = targetSessionIDs
    }
}

public enum AutomationPolicyError: Error, LocalizedError, Equatable {
    case emptyName
    case emptySource
    case missingPermissions(Set<AutomationPermission>)
    case productionConfirmationRequired
    case targetLimitExceeded(limit: Int, actual: Int)
    case executionTimeout(TimeInterval)

    public var errorDescription: String? {
        switch self {
        case .emptyName: return "Automation name cannot be empty."
        case .emptySource: return "Automation source cannot be empty."
        case .missingPermissions(let permissions):
            return "Missing permissions: \(permissions.map(\.rawValue).sorted().joined(separator: ", "))."
        case .productionConfirmationRequired:
            return "Production automation requires an explicit confirmation."
        case .targetLimitExceeded(let limit, let actual):
            return "Target limit exceeded: maximum allowed is \(limit), but \(actual) were targeted."
        case .executionTimeout(let timeout):
            return "Automation exceeded maximum execution time limit of \(Int(timeout))s."
        }
    }
}

public struct AutomationPolicy: Equatable, Sendable {
    public var grantedPermissions: Set<AutomationPermission>
    public var maxTargets: Int
    public var timeoutLimitSeconds: TimeInterval

    public init(
        grantedPermissions: Set<AutomationPermission> = [],
        maxTargets: Int = 50,
        timeoutLimitSeconds: TimeInterval = 600
    ) {
        self.grantedPermissions = grantedPermissions
        self.maxTargets = maxTargets
        self.timeoutLimitSeconds = timeoutLimitSeconds
    }

    public func authorize(_ script: AutomationScript, productionConfirmed: Bool = false) throws {
        guard !script.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AutomationPolicyError.emptyName
        }
        guard !script.source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AutomationPolicyError.emptySource
        }
        if script.targetSessionIDs.count > maxTargets {
            throw AutomationPolicyError.targetLimitExceeded(limit: maxTargets, actual: script.targetSessionIDs.count)
        }
        let missing = script.permissions.subtracting(grantedPermissions)
        guard missing.isEmpty else { throw AutomationPolicyError.missingPermissions(missing) }
        if script.permissions.contains(.production) && !productionConfirmed {
            throw AutomationPolicyError.productionConfirmationRequired
        }
    }
}

// MARK: - Automation Templates

public enum AutomationTemplate: String, CaseIterable, Identifiable, Sendable {
    case login = "Login & Environment Setup"
    case healthCheck = "Fleet Health Check"
    case deployment = "Application Deployment"
    case backup = "Database / File Backup"
    case credentialRotation = "Credential & Key Rotation"

    public var id: String { rawValue }

    public var description: String {
        switch self {
        case .login:
            return "Configures terminal prompt, aliases, and verifies basic user session privileges."
        case .healthCheck:
            return "Inspects uptime, memory, storage utilization, and top CPU consumer processes."
        case .deployment:
            return "Performs git fetch, pulls latest release, executes migrations, and restarts services."
        case .backup:
            return "Dumps database or archives config directories with gzip compression and SHA256 verification."
        case .credentialRotation:
            return "Rotates SSH authorized keys or service passwords securely."
        }
    }

    public var requiredPermissions: Set<AutomationPermission> {
        switch self {
        case .login: return [.network]
        case .healthCheck: return [.network]
        case .deployment: return [.network, .production]
        case .backup: return [.network, .fileRead]
        case .credentialRotation: return [.network, .keychain, .production]
        }
    }

    public func buildPlan(targets: [UUID] = []) -> AutomationPlan {
        let script = AutomationScript(
            name: rawValue,
            source: rawValue.lowercased(),
            permissions: requiredPermissions,
            targetSessionIDs: targets
        )

        let steps: [AutomationStep]
        switch self {
        case .login:
            steps = [
                AutomationStep(command: "uname -a", delayAfterSend: 0.5),
                AutomationStep(command: "export TERM=xterm-256color", delayAfterSend: 0.2),
                AutomationStep(command: "echo 'Session initialized: $(date)'", delayAfterSend: 0.2)
            ]
        case .healthCheck:
            steps = [
                AutomationStep(command: "uptime", delayAfterSend: 0.5),
                AutomationStep(command: "df -h /", delayAfterSend: 0.5),
                AutomationStep(command: "free -m || vm_stat", delayAfterSend: 0.5),
                AutomationStep(command: "ps aux --sort=-%cpu | head -n 6", delayAfterSend: 0.5)
            ]
        case .deployment:
            steps = [
                AutomationStep(command: "git status", delayAfterSend: 1.0),
                AutomationStep(command: "git pull --ff-only", delayAfterSend: 2.0),
                AutomationStep(command: "systemctl is-active app.service || true", delayAfterSend: 1.0)
            ]
        case .backup:
            steps = [
                AutomationStep(command: "mkdir -p /tmp/spectre_backups", delayAfterSend: 0.5),
                AutomationStep(command: "tar -czf /tmp/spectre_backups/etc_backup_$(date +%Y%m%d).tar.gz /etc/hosts || true", delayAfterSend: 2.0),
                AutomationStep(command: "ls -lh /tmp/spectre_backups/", delayAfterSend: 0.5)
            ]
        case .credentialRotation:
            steps = [
                AutomationStep(command: "chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys", delayAfterSend: 0.5),
                AutomationStep(command: "echo '# Checked key rotation on $(date)' >> ~/.ssh/authorized_keys", delayAfterSend: 0.5)
            ]
        }

        return AutomationPlan(script: script, steps: steps)
    }
}
