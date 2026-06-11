//
//  AppScreen.swift
//  LoopTogetherUITests
//
//  Shared launch helper. Page objects live in Pages/.

import XCTest

extension XCUIApplication {
    static func launched() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        return app
    }
}
