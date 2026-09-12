//
//  SpectreProTitleUITests.swift
//  SpectreProUITests
//
//  Created by luca on 13.10.2025.
//

import XCTest

final class SpectreProTitleUITests: SpectreProCustomConfigCase {
    override func setUp() async throws {
        try await super.setUp()
        try updateConfig(#"title = "SpectreProUITestsLaunchTests""#)
    }

    @MainActor
    func testTitle() throws {
        let app = try spectreproApplication()
        app.launch()

        XCTAssertEqual(app.windows.firstMatch.title, "SpectreProUITestsLaunchTests", "Oops, `title=` doesn't work!")
    }
}
