import Foundation

public struct AutomationStep: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var command: String
    public var delayAfterSend: TimeInterval

    public init(id: UUID = UUID(), command: String, delayAfterSend: TimeInterval = 0) {
        self.id = id
        self.command = command
        self.delayAfterSend = max(0, delayAfterSend)
    }
}

public struct AutomationPlan: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var script: AutomationScript
    public var steps: [AutomationStep]

    public init(id: UUID = UUID(), script: AutomationScript, steps: [AutomationStep]) {
        self.id = id
        self.script = script
        self.steps = steps
    }
}

public struct AutomationTargetResult: Codable, Equatable, Sendable {
    public let targetID: UUID
    public var sentSteps: Int
    public var failed: Bool
    public var message: String

    public init(targetID: UUID, sentSteps: Int, failed: Bool, message: String) {
        self.targetID = targetID
        self.sentSteps = sentSteps
        self.failed = failed
        self.message = message
    }
}

public struct AutomationExecutionRecord: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let planName: String
    public let executedBy: String
    public let startedAt: Date
    public let durationSeconds: TimeInterval
    public let targetCount: Int
    public let successfulTargets: Int
    public let failedTargets: Int
    public let results: [AutomationTargetResult]

    public init(
        id: UUID = UUID(),
        planName: String,
        executedBy: String = NSUserName(),
        startedAt: Date = Date(),
        durationSeconds: TimeInterval,
        targetCount: Int,
        successfulTargets: Int,
        failedTargets: Int,
        results: [AutomationTargetResult]
    ) {
        self.id = id
        self.planName = planName
        self.executedBy = executedBy
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.targetCount = targetCount
        self.successfulTargets = successfulTargets
        self.failedTargets = failedTargets
        self.results = results
    }
}

public struct AutomationPreviewInfo: Equatable, Sendable {
    public let planName: String
    public let targetCount: Int
    public let stepCount: Int
    public let estimatedDurationSeconds: TimeInterval
    public let requiresProductionConfirmation: Bool
    public let isAuthorized: Bool
    public let missingPermissions: [AutomationPermission]
    public let validationError: String?

    public init(
        planName: String,
        targetCount: Int,
        stepCount: Int,
        estimatedDurationSeconds: TimeInterval,
        requiresProductionConfirmation: Bool,
        isAuthorized: Bool,
        missingPermissions: [AutomationPermission] = [],
        validationError: String? = nil
    ) {
        self.planName = planName
        self.targetCount = targetCount
        self.stepCount = stepCount
        self.estimatedDurationSeconds = estimatedDurationSeconds
        self.requiresProductionConfirmation = requiresProductionConfirmation
        self.isAuthorized = isAuthorized
        self.missingPermissions = missingPermissions
        self.validationError = validationError
    }
}

@MainActor
public final class AutomationExecutor: ObservableObject {
    public static let shared = AutomationExecutor()

    @Published public private(set) var isRunning = false
    @Published public private(set) var results: [AutomationTargetResult] = []
    @Published public private(set) var executionHistory: [AutomationExecutionRecord] = []

    private var task: Task<Void, Never>?
    private let historyFileURL: URL

    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let baseDir = appSupport.appendingPathComponent("co.skyones.spectrepro", isDirectory: true)
        try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
        self.historyFileURL = baseDir.appendingPathComponent("automation_history.json")
        loadHistory()
    }

    // MARK: - Preview Mode

    public func preview(
        plan: AutomationPlan,
        policy: AutomationPolicy,
        productionConfirmed: Bool = false
    ) -> AutomationPreviewInfo {
        var isAuth = true
        var missing: [AutomationPermission] = []
        var valError: String? = nil

        do {
            try policy.authorize(plan.script, productionConfirmed: productionConfirmed)
        } catch let err as AutomationPolicyError {
            isAuth = false
            valError = err.localizedDescription
            if case .missingPermissions(let p) = err {
                missing = Array(p).sorted(by: { $0.rawValue < $1.rawValue })
            }
        } catch {
            isAuth = false
            valError = error.localizedDescription
        }

        let validSteps = plan.steps.filter { !$0.command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let perTargetDelay = validSteps.reduce(0.0) { $0 + $1.delayAfterSend }
        let estimatedTotal = perTargetDelay * Double(plan.script.targetSessionIDs.count)

        return AutomationPreviewInfo(
            planName: plan.script.name,
            targetCount: plan.script.targetSessionIDs.count,
            stepCount: validSteps.count,
            estimatedDurationSeconds: estimatedTotal,
            requiresProductionConfirmation: plan.script.permissions.contains(.production),
            isAuthorized: isAuth,
            missingPermissions: missing,
            validationError: valError
        )
    }

    // MARK: - Execution

    public func run(
        plan: AutomationPlan,
        policy: AutomationPolicy,
        productionConfirmed: Bool = false,
        send: @escaping (UUID, String) -> Bool
    ) {
        cancel()
        do {
            try policy.authorize(plan.script, productionConfirmed: productionConfirmed)
        } catch {
            results = plan.script.targetSessionIDs.map {
                AutomationTargetResult(targetID: $0, sentSteps: 0, failed: true, message: error.localizedDescription)
            }
            return
        }

        let validSteps = plan.steps.filter { !$0.command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !validSteps.isEmpty, !plan.script.targetSessionIDs.isEmpty else { return }
        isRunning = true
        results = []

        let startTime = Date()
        let planName = plan.script.name
        let targets = plan.script.targetSessionIDs
        let maxTimeout = policy.timeoutLimitSeconds

        task = Task { [weak self] in
            var accumulatedResults: [AutomationTargetResult] = []

            for targetID in targets {
                if Task.isCancelled { break }
                if Date().timeIntervalSince(startTime) > maxTimeout {
                    accumulatedResults.append(AutomationTargetResult(
                        targetID: targetID,
                        sentSteps: 0,
                        failed: true,
                        message: "Execution timeout reached."
                    ))
                    continue
                }

                var sentSteps = 0
                var failed = false
                for step in validSteps {
                    guard !Task.isCancelled else { break }
                    guard send(targetID, step.command) else {
                        failed = true
                        break
                    }
                    sentSteps += 1
                    if step.delayAfterSend > 0 {
                        try? await Task.sleep(for: .seconds(step.delayAfterSend))
                    }
                }

                let targetResult = AutomationTargetResult(
                    targetID: targetID,
                    sentSteps: sentSteps,
                    failed: failed,
                    message: failed ? "Execution failed on step \(sentSteps + 1)." : "Completed \(sentSteps) step(s)."
                )
                accumulatedResults.append(targetResult)

                await MainActor.run {
                    self?.results = accumulatedResults
                }
            }

            let duration = Date().timeIntervalSince(startTime)
            let successful = accumulatedResults.filter { !$0.failed }.count
            let failed = accumulatedResults.filter { $0.failed }.count

            let record = AutomationExecutionRecord(
                planName: planName,
                durationSeconds: duration,
                targetCount: targets.count,
                successfulTargets: successful,
                failedTargets: failed,
                results: accumulatedResults
            )

            await MainActor.run {
                self?.isRunning = false
                self?.task = nil
                self?.executionHistory.insert(record, at: 0)
                self?.saveHistory()
            }
        }
    }

    public func cancel() {
        task?.cancel()
        task = nil
        isRunning = false
    }

    public func clearHistory() {
        executionHistory.removeAll()
        saveHistory()
    }

    private func loadHistory() {
        guard let data = try? Data(contentsOf: historyFileURL),
              let list = try? JSONDecoder().decode([AutomationExecutionRecord].self, from: data) else { return }
        self.executionHistory = list
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(executionHistory) {
            try? data.write(to: historyFileURL, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: historyFileURL.path)
        }
    }
}
