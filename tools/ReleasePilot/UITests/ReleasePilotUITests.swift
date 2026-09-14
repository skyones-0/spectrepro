import XCTest

final class ReleasePilotUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testInitialReleaseControlsAreVisibleAndPublishingIsBlocked() {
        XCTAssertTrue(app.staticTexts["Release Pilot"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["refresh"].exists)
        XCTAssertTrue(app.buttons["chooseRepository"].exists)
        XCTAssertTrue(app.buttons["saveToken"].exists)
        XCTAssertTrue(app.buttons["flowAction-1"].exists)
        XCTAssertTrue(app.buttons["flowAction-2"].exists)
        XCTAssertTrue(app.buttons["flowAction-3"].exists)
        XCTAssertTrue(app.buttons["publishRelease"].exists)
        XCTAssertFalse(app.buttons["publishRelease"].isEnabled)
    }

    func testRepositoryAndVersionFieldsAcceptUserInput() {
        let repository = app.textFields["owner/repository"]
        XCTAssertTrue(repository.waitForExistence(timeout: 5))
        repository.click()
        repository.typeText("skyones-0/spectrepro")

        let version = app.textFields["1.0.17"]
        XCTAssertTrue(version.exists)
        version.click()
        version.typeText("1.0.18")
        XCTAssertTrue(version.value as? String != nil)
    }

    func testLaunchPerformanceAndMemory() {
        measure(metrics: [XCTApplicationLaunchMetric(), XCTMemoryMetric()]) {
            app.launch()
            XCTAssertTrue(app.staticTexts["Release Pilot"].waitForExistence(timeout: 5))
            app.terminate()
        }
    }
}
