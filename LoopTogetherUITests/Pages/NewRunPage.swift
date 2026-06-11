//
//  NewRunPage.swift
//  LoopTogetherUITests
//

import XCTest

private enum NewRunPageConstants {
    static let navBarLabel         = "New Run"
    static let cancelButtonLabel   = "Cancel"
    static let generateButtonLabel = "Generate Route"
    static let startRunLabel       = "Start Run"
    static let tryAnotherLabel     = "Try Another Route"
}

struct NewRunPage {
    let app: XCUIApplication

    // MARK: - Elements
    var navBar:           XCUIElement { app.navigationBars[NewRunPageConstants.navBarLabel] }
    var cancelButton:     XCUIElement { app.buttons[NewRunPageConstants.cancelButtonLabel] }
    var generateButton:   XCUIElement { app.buttons[NewRunPageConstants.generateButtonLabel] }
    var startRunButton:   XCUIElement { app.buttons[NewRunPageConstants.startRunLabel] }
    var tryAnotherButton: XCUIElement { app.buttons[NewRunPageConstants.tryAnotherLabel] }
    var distanceSlider:   XCUIElement { app.sliders.firstMatch }

    // MARK: - Verifications
    @discardableResult
    func verifyDisplayed() throws -> Self {
        try XCTContext.runActivity(named: "Verify New Run sheet is displayed") { _ in
            XCTAssertTrue(navBar.waitForExistence(timeout: 5), "New Run sheet did not appear")
        }
        return self
    }

    @discardableResult
    func verifyStartRunVisible() throws -> Self {
        try XCTContext.runActivity(named: "Verify Start Run button is visible") { _ in
            // Longer timeout because route generation takes time
            XCTAssertTrue(startRunButton.waitForExistence(timeout: 15), "Start Run button did not appear after generation")
        }
        return self
    }

    // MARK: - Actions
    // Navigates back to ActivitiesPage
    @discardableResult
    func tapCancel() throws -> ActivitiesPage {
        try XCTContext.runActivity(named: "Cancel New Run") { _ in
            cancelButton.tap()
        }
        return ActivitiesPage(app: app)
    }

    @discardableResult
    func tapGenerateRoute() throws -> Self {
        try XCTContext.runActivity(named: "Tap Generate Route") { _ in
            generateButton.tap()
        }
        return self
    }
}
