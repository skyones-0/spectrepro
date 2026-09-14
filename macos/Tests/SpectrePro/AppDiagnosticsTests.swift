import Foundation
import Testing
@testable import SpectrePro

@Suite
struct AppDiagnosticsTests {
    @Test func writesPersistentEvent() async throws {
        let marker = "diagnostics-test-\(UUID().uuidString)"
        AppDiagnostics.event(marker, category: "Tests")

        for _ in 0..<20 {
            let contents = (try? String(contentsOf: AppDiagnostics.logFileURL, encoding: .utf8)) ?? ""
            if contents.contains(marker) {
                return
            }
            try await Task.sleep(for: .milliseconds(50))
        }

        Issue.record("Expected the diagnostics log to contain the emitted event.")
    }
}
