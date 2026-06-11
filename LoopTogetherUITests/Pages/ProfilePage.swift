//
//  ProfilePage.swift
//  LoopTogetherUITests
//

import XCTest

private enum ProfilePageConstants {
    static let navBarLabel        = "Profile"
    static let tabLabel           = "Profile"
    static let unitsLabel         = "Units"
    static let voiceGuidanceLabel = "Voice Guidance"
    static let runnerIconLabel    = "Runner Icon"
    static let monthlyGoalLabel   = "Monthly Goal"
    static let signOutLabel       = "Sign Out"
}

struct ProfilePage {
    let app: XCUIApplication

    // MARK: - Elements
    var navBar:           XCUIElement { app.navigationBars[ProfilePageConstants.navBarLabel] }
    var unitsRow:         XCUIElement { app.buttons[ProfilePageConstants.unitsLabel] }
    var voiceGuidanceRow: XCUIElement { app.buttons[ProfilePageConstants.voiceGuidanceLabel] }
    var runnerIconRow:    XCUIElement { app.buttons[ProfilePageConstants.runnerIconLabel] }
    var monthlyGoalRow:   XCUIElement { app.buttons[ProfilePageConstants.monthlyGoalLabel] }
    var signOutButton:    XCUIElement { app.buttons[ProfilePageConstants.signOutLabel] }

    // MARK: - Navigation
    static func open(app: XCUIApplication) throws -> ProfilePage {
        try XCTContext.runActivity(named: "Open Profile tab") { _ in
            app.tabBars.buttons[ProfilePageConstants.tabLabel].tap()
        }
        return ProfilePage(app: app)
    }

    // MARK: - Verifications
    @discardableResult
    func verifyDisplayed() throws -> Self {
        try XCTContext.runActivity(named: "Verify \(ProfilePageConstants.navBarLabel) is displayed") { _ in
            XCTAssertTrue(navBar.waitForExistence(timeout: 5), "Profile tab did not load")
        }
        return self
    }

    @discardableResult
    func verifySettingsRowsExist() throws -> Self {
        try XCTContext.runActivity(named: "Verify settings rows exist") { _ in
            XCTAssertTrue(unitsRow.exists, "Units row missing")
            XCTAssertTrue(voiceGuidanceRow.exists, "Voice Guidance row missing")
            XCTAssertTrue(runnerIconRow.exists, "Runner Icon row missing")
            XCTAssertTrue(monthlyGoalRow.exists, "Monthly Goal row missing")
        }
        return self
    }

    // MARK: - Actions
    @discardableResult
    func tapUnits() throws -> Self {
        try XCTContext.runActivity(named: "Tap Units") { _ in
            unitsRow.tap()
        }
        return self
    }

    @discardableResult
    func tapRunnerIcon() throws -> Self {
        try XCTContext.runActivity(named: "Tap Runner Icon") { _ in
            runnerIconRow.tap()
        }
        return self
    }

    @discardableResult
    func tapMonthlyGoal() throws -> Self {
        try XCTContext.runActivity(named: "Tap Monthly Goal") { _ in
            monthlyGoalRow.tap()
        }
        return self
    }
}
