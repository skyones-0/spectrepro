import SwiftUI
import AppKit

@MainActor
public final class ExpectSendEngine: ObservableObject {
    public static let shared = ExpectSendEngine()

    @Published public private(set) var isRunning = false
    @Published public private(set) var currentStatus: String?
    @Published public private(set) var lastRunSummary: String?

    private var currentTask: Task<Void, Never>?

    public init() {}

    public func start(
        rules: [ExpectSendRule],
        textReader: @escaping () -> String,
        textSender: @escaping (String) -> Void,
        secretProvider: (() -> String?)? = nil,
        credentialResolver: ((CredentialReference) -> String?)? = nil
    ) {
        cancel()
        guard !rules.isEmpty else { return }

        isRunning = true
        lastRunSummary = nil
        currentStatus = "Expect/Send: Started (1/\(rules.count))"

        currentTask = Task { [weak self] in
            var completed = 0
            var failed = 0
            for (index, rule) in rules.enumerated() {
                if Task.isCancelled { break }

                let stepNum = index + 1
                let expectedPattern = rule.expect.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !expectedPattern.isEmpty else { continue }

                await MainActor.run {
                    self?.currentStatus = "Waiting for \(rule.matchMode.title.lowercased()) '\(expectedPattern)' (\(stepNum)/\(rules.count))"
                }

                var matched = false
                let attempts = max(1, min(rule.retryCount, 10) + 1)
                for attempt in 1...attempts {
                    let timeout = max(0.1, min(rule.timeoutSeconds, 3600))
                    let deadline = ContinuousClock.now + .seconds(timeout)
                    while ContinuousClock.now < deadline {
                        guard !Task.isCancelled else { break }
                        try? await Task.sleep(for: .milliseconds(250))
                        let currentText = await MainActor.run { textReader() }
                        if Self.matches(currentText, pattern: expectedPattern, mode: rule.matchMode) {
                            matched = true
                            break
                        }
                    }
                    if matched || Task.isCancelled { break }
                    await MainActor.run {
                        self?.currentStatus = "Retry \(attempt)/\(attempts) for '\(expectedPattern)'"
                    }
                }

                if Task.isCancelled { break }

                if matched {
                    await MainActor.run {
                        self?.currentStatus = "Matched '\(expectedPattern)'. Sending response..."
                        var toSend: String
                        if let ref = rule.credentialReference, let resolved = credentialResolver?(ref) {
                            toSend = resolved
                        } else {
                            toSend = rule.send
                            if toSend.isEmpty,
                               rule.matchMode == .literal,
                               expectedPattern.range(of: "password|passphrase|secret", options: [.regularExpression, .caseInsensitive]) != nil {
                                toSend = secretProvider?() ?? ""
                            }
                        }
                        if !toSend.hasSuffix("\n") {
                            toSend += "\n"
                        }
                        textSender(toSend)
                    }
                    completed += 1
                } else {
                    failed += 1
                    await MainActor.run {
                        self?.currentStatus = "Timeout waiting for '\(expectedPattern)'"
                    }
                    if !rule.continueOnFailure { break }
                }
            }

            await MainActor.run {
                self?.isRunning = false
                self?.currentStatus = nil
                self?.lastRunSummary = "Completed \(completed) step(s), \(failed) failed"
            }
        }
    }

    private static func matches(_ text: String, pattern: String, mode: ExpectSendMatchMode) -> Bool {
        switch mode {
        case .literal:
            return text.localizedCaseInsensitiveContains(pattern)
        case .regularExpression:
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
            return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
        }
    }

    public func cancel() {
        currentTask?.cancel()
        currentTask = nil
        isRunning = false
        currentStatus = nil
    }
}
