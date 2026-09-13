import Combine
import Darwin
import Darwin.Mach
import Foundation

class AboutViewModel: ObservableObject {
    @Published var currentIcon: SpectrePro.MacOSIcon?
    @Published var isHovering: Bool = false
    @Published private(set) var residentMemoryBytes: UInt64 = 0
    @Published private(set) var sessionDuration: TimeInterval = 0
    @Published private(set) var processCPUUsage: Double = 0

    private var timerCancellable: AnyCancellable?
    private var telemetryTimerCancellable: AnyCancellable?
    private var sessionStartedAt: Date?
    private var lastCPUSample: CPUSample?

    private let icons: [SpectrePro.MacOSIcon] = [
        .official,
        .blueprint,
        .chalkboard,
        .microchip,
        .glass,
        .holographic,
        .paper,
        .retro,
        .xray,
    ]

    func startCyclingIcons() {
        sessionStartedAt = Date()
        updateRuntimeMetrics()
        timerCancellable = Timer.publish(every: 3, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, !isHovering else { return }
                advanceToNextIcon()
            }
        telemetryTimerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateRuntimeMetrics()
            }
    }

    func stopCyclingIcons() {
        timerCancellable = nil
        telemetryTimerCancellable = nil
        sessionStartedAt = nil
        lastCPUSample = nil
        processCPUUsage = 0
        currentIcon = nil
    }

    func advanceToNextIcon() {
        let currentIndex = currentIcon.flatMap(icons.firstIndex(of:)) ?? 0
        let nextIndex = icons.indexWrapping(after: currentIndex)
        currentIcon = icons[nextIndex]
    }

    private func updateRuntimeMetrics() {
        residentMemoryBytes = Self.currentResidentMemory()
        let now = Date()

        if let sessionStartedAt {
            sessionDuration = now.timeIntervalSince(sessionStartedAt)
        }

        let currentCPUSample = CPUSample(capturedAt: now, cpuTime: Self.currentCPUTime())
        if let lastCPUSample {
            let elapsed = currentCPUSample.capturedAt.timeIntervalSince(lastCPUSample.capturedAt)
            if elapsed > 0 {
                processCPUUsage = max(0, (currentCPUSample.cpuTime - lastCPUSample.cpuTime) / elapsed * 100)
            }
        }
        lastCPUSample = currentCPUSample
    }

    private static func currentResidentMemory() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }
        return UInt64(info.resident_size)
    }

    private static func currentCPUTime() -> TimeInterval {
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else { return 0 }

        return timeInterval(for: usage.ru_utime) + timeInterval(for: usage.ru_stime)
    }

    private static func timeInterval(for time: timeval) -> TimeInterval {
        TimeInterval(time.tv_sec) + TimeInterval(time.tv_usec) / 1_000_000
    }

    private struct CPUSample {
        let capturedAt: Date
        let cpuTime: TimeInterval
    }
}
