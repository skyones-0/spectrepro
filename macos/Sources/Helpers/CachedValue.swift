import Foundation

final class CachedValue<Value> {
    private let lock = NSLock()
    private var value: Value?
    private let fetch: () -> Value
    private let duration: Duration
    private var expiryTask: Task<Void, Never>?

    init(duration: Duration, fetch: @escaping () -> Value) {
        self.duration = duration
        self.fetch = fetch
    }

    deinit {
        lock.lock()
        expiryTask?.cancel()
        lock.unlock()
    }

    func get() -> Value {
        lock.lock()
        defer { lock.unlock() }

        if let value {
            return value
        }

        let result = fetch()
        let expires = ContinuousClock.now + duration
        value = result

        expiryTask = Task { [weak self] in
            do {
                try await Task.sleep(until: expires)
                self?.expire()
            } catch {
            }
        }

        return result
    }

    private func expire() {
        lock.lock()
        defer { lock.unlock() }

        value = nil
        expiryTask = nil
    }
}
