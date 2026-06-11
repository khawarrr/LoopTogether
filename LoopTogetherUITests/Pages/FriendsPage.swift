//
//  FriendsPage.swift
//  LoopTogetherUITests
//

import XCTest

private enum FriendsPageConstants {
    static let navBarLabel       = "Friends"
    static let tabLabel          = "Friends"
    static let addButtonLabel    = "person.badge.plus"
    static let dailySegmentLabel = "Daily"
    static let weeklySegmentLabel = "Weekly"
    static let noFriendsTextLabel = "No friends yet"
}

struct FriendsPage {
    let app: XCUIApplication

    // MARK: - Elements
    var navBar:        XCUIElement { app.navigationBars[FriendsPageConstants.navBarLabel] }
    var addButton:     XCUIElement { app.buttons[FriendsPageConstants.addButtonLabel] }
    var dailySegment:  XCUIElement { app.buttons[FriendsPageConstants.dailySegmentLabel] }
    var weeklySegment: XCUIElement { app.buttons[FriendsPageConstants.weeklySegmentLabel] }
    var noFriendsText: XCUIElement { app.staticTexts[FriendsPageConstants.noFriendsTextLabel] }

    // MARK: - Navigation
    // Static because there is no existing instance yet — we are navigating TO this page
    static func open(app: XCUIApplication) throws -> FriendsPage {
        try XCTContext.runActivity(named: "Open Friends tab") { _ in
            app.tabBars.buttons[FriendsPageConstants.tabLabel].tap()
        }
        return FriendsPage(app: app)
    }

    // MARK: - Verifications
    @discardableResult
    func verifyDisplayed() throws -> Self {
        try XCTContext.runActivity(named: "Verify \(FriendsPageConstants.navBarLabel) is displayed") { _ in
            XCTAssertTrue(navBar.waitForExistence(timeout: 5), "Friends tab did not load")
        }
        return self
    }

    @discardableResult
    func isShowingLeaderboard() throws -> Self {
        try XCTContext.runActivity(named: "Verify leaderboard segments exist") { _ in
            XCTAssertTrue(dailySegment.exists, "Daily segment missing")
            XCTAssertTrue(weeklySegment.exists, "Weekly segment missing")
        }
        return self
    }

    // MARK: - Actions
    @discardableResult
    func tapDaily() throws -> Self {
        try XCTContext.runActivity(named: "Tap Daily segment") { _ in
            dailySegment.tap()
        }
        return self
    }

    @discardableResult
    func tapWeekly() throws -> Self {
        try XCTContext.runActivity(named: "Tap Weekly segment") { _ in
            weeklySegment.tap()
        }
        return self
    }

    // Navigates away to AddFriendPage — returns that page type
    @discardableResult
    func tapAddFriend() throws -> AddFriendPage {
        try XCTContext.runActivity(named: "Open Add Friend sheet") { _ in
            addButton.tap()
        }
        return AddFriendPage(app: app)
    }
}
