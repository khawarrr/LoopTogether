//
//  LoopTogetherUITests.swift
//  LoopTogetherUITests
//

import XCTest

final class LoopTogetherUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Tab navigation

    func testTabBarExists() {
        XCTAssertTrue(app.tabBars.firstMatch.exists)
    }

    func testCanSwitchToFriendsTab() throws {
        try FriendsPage.open(app: app).verifyDisplayed()
    }

    func testCanSwitchToProfileTab() throws {
        try ProfilePage.open(app: app).verifyDisplayed()
    }

    func testCanSwitchToActivitiesTab() throws {
        try ActivitiesPage.open(app: app).verifyDisplayed()
    }

    // MARK: - Activities tab

    func testActivitiesTabLoads() throws {
        try ActivitiesPage(app: app).verifyDisplayed()
    }

    func testPlusMenuHasThreeOptions() throws {
        try ActivitiesPage(app: app)
            .openPlusMenu()
            .verifyPlusMenuOptions()
    }
}
