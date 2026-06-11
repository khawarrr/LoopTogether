//
//  ActivitiesTests.swift
//  LoopTogetherUITests
//

import XCTest

final class ActivitiesTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        // Activities is the default tab so just verify it's displayed
        try ActivitiesPage(app: app).verifyDisplayed()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testPlusMenuShowsAllOptions() throws {
        try ActivitiesPage(app: app)
            .openPlusMenu()
            .verifyPlusMenuOptions()
    }

    func testGenerateRouteSheetOpens() throws {
        try ActivitiesPage(app: app)
            .openPlusMenu()
            .tapGenerateRoute()   // -> NewRunPage
            .verifyDisplayed()
    }

    func testBuildRouteSheetOpens() throws {
        try ActivitiesPage(app: app)
            .openPlusMenu()
            .tapBuildRoute()      // -> BuildRoutePage
            .verifyDisplayed()
    }

    func testBuildRouteCanBeCancelled() throws {
        try ActivitiesPage(app: app)
            .openPlusMenu()
            .tapBuildRoute()      // -> BuildRoutePage
            .verifyDisplayed()
            .tapCancel()          // -> ActivitiesPage
            .verifyDisplayed()
    }

    func testGenerateRouteCanBeCancelled() throws {
        try ActivitiesPage(app: app)
            .openPlusMenu()
            .tapGenerateRoute()   // -> NewRunPage
            .verifyDisplayed()
            .tapCancel()          // -> ActivitiesPage
            .verifyDisplayed()
    }
}
