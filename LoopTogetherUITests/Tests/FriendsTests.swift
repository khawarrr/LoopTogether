//
//  FriendsTests.swift
//  LoopTogetherUITests
//

import XCTest

final class FriendsTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        // static open() handles the tab tap — no raw UI code in test files
        try FriendsPage.open(app: app).verifyDisplayed()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testLeaderboardSegmentsExist() throws {
        try FriendsPage(app: app)
            .isShowingLeaderboard()
    }

    func testDefaultTabIsDaily() throws {
        XCTAssertTrue(
            FriendsPage(app: app).dailySegment.isSelected,
            "Daily should be selected by default"
        )
    }

    func testCanSwitchToWeekly() throws {
        try FriendsPage(app: app)
            .tapWeekly()
        XCTAssertTrue(
            FriendsPage(app: app).weeklySegment.isSelected,
            "Weekly should be selected after tap"
        )
    }

    func testAddFriendSheetOpens() throws {
        try FriendsPage(app: app)
            .tapAddFriend()
            .verifyDisplayed()
    }

    func testAddFriendSheetCanBeDismissed() throws {
        try FriendsPage(app: app)
            .tapAddFriend()
            .verifyDisplayed()
            .tapCancel()
            .verifyDisplayed()
    }
}
