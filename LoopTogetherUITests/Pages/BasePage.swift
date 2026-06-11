//
//  BasePage.swift
//  LoopTogetherUITests
//

import XCTest

class BasePage {
    let app: XCUIApplication

    required init(app: XCUIApplication) {
        self.app = app
    }

    @discardableResult
    func waitForExistence(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    func tapTab(_ label: String) {
        app.tabBars.buttons[label].tap()
    }
}
