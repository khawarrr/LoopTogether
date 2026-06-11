//
//  NavigationTests.swift
//  LoopTogetherUITests
//

import XCTest

final class NavigationTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testTabBarExists() {
        // No throws needed — just reading a property, not calling a throwing method
        XCTAssertTrue(app.tabBars.firstMatch.exists)
    }

    func testActivitiesTabLoads() throws {
        try ActivitiesPage(app: app).verifyDisplayed()
    }

    func testFriendsTabLoads() throws {
        // open() handles the tab tap, verifyDisplayed() confirms arrival
        try FriendsPage.open(app: app).verifyDisplayed()
    }

    func testProfileTabLoads() throws {
        try ProfilePage.open(app: app).verifyDisplayed()
    }

    func testCanNavigateBetweenAllTabs() {
        // Raw loop kept here intentionally — Achievements has no page object yet
        let tabs = ["Activities", "Friends", "Achievements", "Profile"]
        for tab in tabs {
            app.tabBars.buttons[tab].tap()
            XCTAssertTrue(
                app.navigationBars[tab].waitForExistence(timeout: 5),
                "\(tab) tab did not load"
            )
        }
    }
}
