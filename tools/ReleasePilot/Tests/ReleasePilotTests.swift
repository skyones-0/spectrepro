import XCTest
@testable import ReleasePilot

final class ReleasePilotTests: XCTestCase {
    private let manifest = #"""
    .{
        .name = .spectrepro,
        .version = "1.0.17",
    }
    """#

    func testExtractsAndIncrementsSemanticVersion() {
        XCTAssertEqual(ReleaseRules.manifestVersion(in: manifest), "1.0.17")
        XCTAssertEqual(ReleaseRules.nextPatchVersion(after: "1.0.17"), "1.0.18")
        XCTAssertNil(ReleaseRules.nextPatchVersion(after: "1.0"))
    }

    func testRejectsMalformedManifestVersion() {
        XCTAssertNil(ReleaseRules.manifestVersion(in: ".version = \"preview\""))
        XCTAssertThrowsError(try ReleaseRules.validate(version: "1.0.18", manifest: ".version = \"preview\"", latestTag: "v1.0.17"))
    }

    func testReleaseVersionMustMatchManifestAndExceedLatestTag() throws {
        XCTAssertNoThrow(try ReleaseRules.validate(version: "1.0.17", manifest: manifest, latestTag: "v1.0.16"))
        XCTAssertThrowsError(try ReleaseRules.validate(version: "1.0.16", manifest: manifest, latestTag: "v1.0.15"))
        XCTAssertThrowsError(try ReleaseRules.validate(version: "1.0.17", manifest: manifest, latestTag: "v1.0.17"))
        XCTAssertThrowsError(try ReleaseRules.validate(version: "not-a-version", manifest: manifest, latestTag: "v1.0.16"))
    }

    func testSemanticVersionComparisonUsesAllComponents() {
        XCTAssertTrue(ReleaseRules.isVersion("1.10.0", greaterThan: "1.9.99"))
        XCTAssertTrue(ReleaseRules.isVersion("2.0.0", greaterThan: "1.99.99"))
        XCTAssertFalse(ReleaseRules.isVersion("1.0.0", greaterThan: "1.0.0"))
        XCTAssertFalse(ReleaseRules.isVersion("1.0.0", greaterThan: "1.0.1"))
    }

    func testChecksStateDistinguishesPendingFailedAndSuccessfulRuns() {
        XCTAssertEqual(ReleaseRules.checksState(for: [.init(status: "in_progress", conclusion: nil)]), "Waiting for checks")
        XCTAssertEqual(ReleaseRules.checksState(for: [.init(status: "completed", conclusion: "failure")]), "Checks failed")
        XCTAssertEqual(ReleaseRules.checksState(for: [
            .init(status: "completed", conclusion: "success"),
            .init(status: "completed", conclusion: "skipped"),
        ]), "All checks passed")
    }

    func testWorkflowStatusUsesLatestRunState() {
        let running = WorkflowStatus(id: 1, name: "CI", path: ".github/workflows/ci.yml", isActive: true, status: "in_progress", conclusion: nil)
        let failed = WorkflowStatus(id: 2, name: "Release", path: ".github/workflows/release.yml", isActive: true, status: "completed", conclusion: "failure")
        XCTAssertEqual(running.presentation, "in_progress")
        XCTAssertEqual(failed.presentation, "failure")
    }

    @MainActor
    func testCoordinatorDoesNotRetainItselfWithoutMonitoring() {
        weak var weakCoordinator: ReleaseCoordinator?
        autoreleasepool {
            let coordinator = ReleaseCoordinator()
            weakCoordinator = coordinator
        }
        XCTAssertNil(weakCoordinator)
    }

    func testReleaseRulesPerformance() {
        measure {
            for _ in 0..<10_000 {
                _ = ReleaseRules.manifestVersion(in: manifest)
                _ = ReleaseRules.nextPatchVersion(after: "1.0.17")
                _ = ReleaseRules.isVersion("1.0.18", greaterThan: "1.0.17")
                _ = ReleaseRules.checksState(for: [.init(status: "completed", conclusion: "success")])
            }
        }
    }
}
