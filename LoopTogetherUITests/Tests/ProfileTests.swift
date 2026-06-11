//
//  ProfileTests.swift
//  LoopTogetherUITests
//

import XCTest

final class ProfileTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        // static open() handles the tab tap
        try ProfilePage.open(app: app).verifyDisplayed()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testSettingsRowsExist() throws {
        try ProfilePage(app: app)
            .verifySettingsRowsExist()
    }

    func testUnitsSettingsOpens() throws {
        try ProfilePage(app: app)
            .tapUnits()
        XCTAssertTrue(
            app.navigationBars["Units"].waitForExistence(timeout: 5),
            "Units settings did not open"
        )
    }

    func testRunnerIconSettingsOpens() throws {
        try ProfilePage(app: app)
            .tapRunnerIcon()
        XCTAssertTrue(
            app.navigationBars["Runner Icon"].waitForExistence(timeout: 5),
            "Runner Icon settings did not open"
        )
    }

    func testMonthlyGoalSettingsOpens() throws {
        try ProfilePage(app: app)
            .tapMonthlyGoal()
        XCTAssertTrue(
            app.navigationBars["Monthly Goal"].waitForExistence(timeout: 5),
            "Monthly Goal settings did not open"
        )
    }
}
