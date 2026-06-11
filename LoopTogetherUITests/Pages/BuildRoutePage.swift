//
//  BuildRoutePage.swift
//  LoopTogetherUITests
//

import XCTest

private enum BuildRoutePageConstants {
    static let navBarLabel       = "Build Route"
    static let cancelButtonLabel = "Cancel"
    static let undoButtonLabel   = "Undo"
    static let startRunLabel     = "Start Run"
    static let clearAllLabel     = "Clear All"
}

struct BuildRoutePage {
    let app: XCUIApplication

    // MARK: - Elements
    var navBar:         XCUIElement { app.navigationBars[BuildRoutePageConstants.navBarLabel] }
    var cancelButton:   XCUIElement { app.buttons[BuildRoutePageConstants.cancelButtonLabel] }
    var undoButton:     XCUIElement { app.buttons[BuildRoutePageConstants.undoButtonLabel] }
    var startRunButton: XCUIElement { app.buttons[BuildRoutePageConstants.startRunLabel] }
    var clearAllButton: XCUIElement { app.buttons[BuildRoutePageConstants.clearAllLabel] }

    // MARK: - Verifications
    @discardableResult
    func verifyDisplayed() throws -> Self {
        try XCTContext.runActivity(named: "Verify Build Route sheet is displayed") { _ in
            XCTAssertTrue(navBar.waitForExistence(timeout: 5), "Build Route sheet did not appear")
        }
        return self
    }

    // MARK: - Actions
    // Navigates back to ActivitiesPage
    @discardableResult
    func tapCancel() throws -> ActivitiesPage {
        try XCTContext.runActivity(named: "Cancel Build Route") { _ in
            cancelButton.tap()
        }
        return ActivitiesPage(app: app)
    }
}
