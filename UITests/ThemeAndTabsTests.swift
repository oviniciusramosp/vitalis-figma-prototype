import XCTest

@MainActor
final class ThemeAndTabsTests: XCTestCase {
    func testThemesApplyAndPersistAfterRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-theme"]
        app.launch()
        XCTAssertTrue(app.buttons["blast-gauge"].waitForExistence(timeout: 15))

        for theme in ["gray", "dark", "light"] {
            app.tabBars.buttons["More"].tap()
            let choice = app.buttons["theme-\(theme)"]
            XCTAssertTrue(choice.waitForExistence(timeout: 5))
            choice.tap()
            expectSelected(choice)
            app.tabBars.buttons["Today"].tap()
            XCTAssertTrue(app.buttons["blast-gauge"].waitForExistence(timeout: 5))
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "Dashboard \(theme) theme"
            attachment.lifetime = .keepAlways
            add(attachment)
        }

        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["blast-gauge"].waitForExistence(timeout: 15))
        app.tabBars.buttons["More"].tap()
        expectSelected(app.buttons["theme-light"])
        XCTAssertEqual(app.buttons["theme-dark"].value as? String, "Not selected")
        XCTAssertEqual(app.buttons["theme-gray"].value as? String, "Not selected")

        // Leave the shared simulator appearance at the prototype's default.
        app.buttons["theme-gray"].tap()
        expectSelected(app.buttons["theme-gray"])
    }

    func testExposureAndHealthKeepCurrentScreenAndSelection() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-theme"]
        app.launch()
        let gauge = app.buttons["blast-gauge"]
        XCTAssertTrue(gauge.waitForExistence(timeout: 15))

        for inactiveTab in ["Exposure", "Health"] {
            app.tabBars.buttons[inactiveTab].tap()
            XCTAssertTrue(gauge.exists)
            XCTAssertTrue(app.tabBars.buttons["Today"].isSelected)
            XCTAssertFalse(app.tabBars.buttons[inactiveTab].isSelected)
        }

        app.tabBars.buttons["More"].tap()
        let theme = app.buttons["theme-gray"]
        XCTAssertTrue(theme.waitForExistence(timeout: 5))
        for inactiveTab in ["Exposure", "Health"] {
            app.tabBars.buttons[inactiveTab].tap()
            XCTAssertTrue(theme.exists)
            XCTAssertTrue(app.tabBars.buttons["More"].isSelected)
            XCTAssertFalse(app.tabBars.buttons[inactiveTab].isSelected)
        }
    }

    private func expectSelected(_ button: XCUIElement) {
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        let selected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "Selected"), object: button
        )
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed)
    }
}
