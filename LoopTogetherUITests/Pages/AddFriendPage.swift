//
//  AddFriendPage.swift
//  LoopTogetherUITests
//

import XCTest

private enum AddFriendPageConstants {
    static let navBarLabel      = "Add Friend"
    static let cancelButtonLabel = "Cancel"
    static let codeFieldLabel   = "Paste their code here"
    static let sendButtonLabel  = "Send Request"
    static let shareButtonLabel = "Share My Code"
}

struct AddFriendPage {
    let app: XCUIApplication

    // MARK: - Elements
    var navBar:          XCUIElement { app.navigationBars[AddFriendPageConstants.navBarLabel] }
    var cancelButton:    XCUIElement { app.buttons[AddFriendPageConstants.cancelButtonLabel] }
    var codeField:       XCUIElement { app.textFields[AddFriendPageConstants.codeFieldLabel] }
    var sendButton:      XCUIElement { app.buttons[AddFriendPageConstants.sendButtonLabel] }
    var shareCodeButton: XCUIElement { app.buttons[AddFriendPageConstants.shareButtonLabel] }

    // MARK: - Verifications
    @discardableResult
    func verifyDisplayed() throws -> Self {
        try XCTContext.runActivity(named: "Verify Add Friend sheet is displayed") { _ in
            XCTAssertTrue(navBar.waitForExistence(timeout: 5), "Add Friend sheet did not appear")
        }
        return self
    }

    // MARK: - Actions
    @discardableResult
    func enterCode(_ code: String) throws -> Self {
        try XCTContext.runActivity(named: "Enter friend code") { _ in
            codeField.tap()
            codeField.typeText(code)
        }
        return self
    }

    // Navigates back — returns FriendsPage
    @discardableResult
    func tapCancel() throws -> FriendsPage {
        try XCTContext.runActivity(named: "Dismiss Add Friend sheet") { _ in
            cancelButton.tap()
        }
        return FriendsPage(app: app)
    }
}
