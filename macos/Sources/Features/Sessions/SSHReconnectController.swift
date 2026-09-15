import Foundation
import Network

public enum SSHReconnectState: Equatable, Sendable {
    case idle
    case waiting(attempt: Int, delay: TimeInterval)
    case paused(attempt: Int)
    case cancelled
    case networkUnavailable
    case connected
    case exhausted
}

public struct ReconnectHistoryEntry: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let attempt: Int
    public let reason: String

    public init(id: UUID = UUID(), timestamp: Date = Date(), attempt: Int, reason: String) {
        self.id = id
        self.timestamp = timestamp
        self.attempt = attempt
        self.reason = reason
    }
}

@MainActor
public final class SSHReconnectController: ObservableObject {
    @Published public private(set) var state: SSHReconnectState = .idle
    @Published public private(set) var isNetworkAvailable: Bool = true
    @Published public private(set) var history: [ReconnectHistoryEntry] = []
    @Published public var autoReconnect: Bool = true
    @Published public var maximumAttempts: Int

    private var attempt = 0
    private var pathMonitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "co.skyones.spectrepro.reconnect.monitor")

    public init(maximumAttempts: Int = 3, autoReconnect: Bool = true) {
        self.maximumAttempts = max(1, maximumAttempts)
        self.autoReconnect = autoReconnect
        setupNetworkMonitor()
    }

    deinit {
        pathMonitor?.cancel()
    }

    private func setupNetworkMonitor() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let available = path.status == .satisfied
                self?.isNetworkAvailable = available
                if !available {
                    if case .waiting = self?.state {
                        self?.state = .networkUnavailable
                    }
                } else if self?.state == .networkUnavailable {
                    // Network restored: resume reconnect attempt
                    if let self = self, self.attempt < self.maximumAttempts {
                        let delay = min(pow(2, Double(self.attempt - 1)), 30)
                        self.state = .waiting(attempt: self.attempt, delay: delay)
                    }
                }
            }
        }
        monitor.start(queue: monitorQueue)
        self.pathMonitor = monitor
    }

    public func disconnected(reason: String = "Process exited") -> TimeInterval? {
        history.append(ReconnectHistoryEntry(attempt: attempt + 1, reason: reason))

        guard isNetworkAvailable else {
            state = .networkUnavailable
            return nil
        }

        guard attempt < maximumAttempts else {
            state = .exhausted
            return nil
        }
        attempt += 1
        let delay = min(pow(2, Double(attempt - 1)), 30)
        state = .waiting(attempt: attempt, delay: delay)
        return delay
    }

    public func pause() {
        guard case .waiting(let currentAttempt, _) = state else { return }
        state = .paused(attempt: currentAttempt)
    }

    public func resume() -> TimeInterval? {
        guard case .paused(let currentAttempt) = state else { return nil }
        guard isNetworkAvailable else {
            state = .networkUnavailable
            return nil
        }
        let delay = min(pow(2, Double(currentAttempt - 1)), 30)
        state = .waiting(attempt: currentAttempt, delay: delay)
        return delay
    }

    public func cancel() {
        state = .cancelled
    }

    public func connected() {
        attempt = 0
        state = .connected
    }

    public func reset() {
        attempt = 0
        state = .idle
    }
}
