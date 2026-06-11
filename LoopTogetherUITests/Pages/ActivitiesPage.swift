//
//  ActivitiesPage.swift
//  LoopTogetherUITests
//

import XCTest

private enum ActivitiesPageConstants {
    static let navBarLabel          = "Activities"
    static let tabLabel             = "Activities"
    static let plusButtonLabel      = "plus.circle.fill"
    static let freeRunLabel         = "Free Run"
    static let generateRouteLabel   = "Generate Route"
    static let buildRouteLabel      = "Build Route"
}

struct ActivitiesPage {
    let app: XCUIApplication

    // MARK: - Elements
    var navBar:              XCUIElement { app.navigationBars[ActivitiesPageConstants.navBarLabel] }
    var plusButton:          XCUIElement { app.buttons[ActivitiesPageConstants.plusButtonLabel] }
    var freeRunButton:       XCUIElement { app.buttons[ActivitiesPageConstants.freeRunLabel] }
    var generateRouteButton: XCUIElement { app.buttons[ActivitiesPageConstants.generateRouteLabel] }
    var buildRouteButton:    XCUIElement { app.buttons[ActivitiesPageConstants.buildRouteLabel] }

    // MARK: - Navigation
    // Activities is the default tab so open() just verifies we are on it
    static func open(app: XCUIApplication) throws -> ActivitiesPage {
        try XCTContext.runActivity(named: "Open Activities tab") { _ in
            app.tabBars.buttons[ActivitiesPageConstants.tabLabel].tap()
        }
        return ActivitiesPage(app: app)
    }

    // MARK: - Verifications
    @discardableResult
    func verifyDisplayed() throws -> Self {
        try XCTContext.runActivity(named: "Verify \(ActivitiesPageConstants.navBarLabel) is displayed") { _ in
            XCTAssertTrue(navBar.waitForExistence(timeout: 5), "Activities tab did not load")
        }
        return self
    }

    @discardableResult
    func verifyPlusMenuOptions() throws -> Self {
        try XCTContext.runActivity(named: "Verify plus menu shows all options") { _ in
            XCTAssertTrue(freeRunButton.waitForExistence(timeout: 5), "Free Run option missing")
            XCTAssertTrue(generateRouteButton.exists, "Generate Route option missing")
            XCTAssertTrue(buildRouteButton.exists, "Build Route option missing")
        }
        return self
    }

    // MARK: - Actions
    @discardableResult
    func openPlusMenu() throws -> Self {
        try XCTContext.runActivity(named: "Open plus menu") { _ in
            plusButton.tap()
        }
        return self
    }

    @discardableResult
    func tapFreeRun() throws -> Self {
        try XCTContext.runActivity(named: "Tap Free Run") { _ in
            freeRunButton.tap()
        }
        return self
    }

    // Navigates to NewRunPage
    @discardableResult
    func tapGenerateRoute() throws -> NewRunPage {
        try XCTContext.runActivity(named: "Tap Generate Route") { _ in
            generateRouteButton.tap()
        }
        return NewRunPage(app: app)
    }

    // Navigates to BuildRoutePage
    @discardableResult
    func tapBuildRoute() throws -> BuildRoutePage {
        try XCTContext.runActivity(named: "Tap Build Route") { _ in
            buildRouteButton.tap()
        }
        return BuildRoutePage(app: app)
    }

    @discardableResult
    func dismissMenu() throws -> Self {
        try XCTContext.runActivity(named: "Dismiss menu") { _ in
            app.swipeDown()
        }
        return self
    }
}
