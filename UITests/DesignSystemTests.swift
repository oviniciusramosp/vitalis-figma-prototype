import XCTest

@MainActor
final class DesignSystemTests: XCTestCase {
    func testLiveCatalogThemesComponentsAndMotion() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-theme"]
        app.launch()
        XCTAssertTrue(app.buttons["blast-gauge"].waitForExistence(timeout: 15))
        app.tabBars.buttons["More"].tap()

        for theme in ["gray", "dark", "light"] {
            app.buttons["theme-\(theme)"].tap()
            capture(app, name: "More \(theme) background")
        }
        app.buttons["theme-gray"].tap()
        let link = app.buttons["open-design-system"]
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        link.tap()

        let catalog = app.scrollViews["design-system-screen"]
        XCTAssertTrue(catalog.waitForExistence(timeout: 5))
        let picker = catalog.segmentedControls["design-system-theme-picker"]
        XCTAssertTrue(picker.exists)
        picker.buttons["Light"].tap()
        XCTAssertTrue(catalog.staticTexts["Semantic tokens · Light theme"].exists)
        capture(app, name: "Design System light foundations")

        let primary = catalog.buttons["design-system-primary-action"]
        scrollTo(primary, in: catalog)
        primary.tap()
        XCTAssertEqual(catalog.staticTexts["design-system-control-feedback"].label, "Primary action previewed.")

        let large = catalog.descendants(matching: .any).matching(identifier: "blast-exposure-card").firstMatch
        scrollTo(large, in: catalog)
        XCTAssertTrue((large.value as? String ?? "").contains("Chart days: 14"))
        let medium = catalog.descendants(matching: .any).matching(identifier: "cognition-widget").firstMatch
        scrollTo(medium, in: catalog)
        XCTAssertTrue((medium.value as? String ?? "").contains("Chart days: 7"))
        let small = catalog.descendants(matching: .any).matching(identifier: "activity-widget").firstMatch
        scrollTo(small, in: catalog)
        XCTAssertTrue((small.value as? String ?? "").contains("Chart days: 0"))
        let heart = catalog.descendants(matching: .any).matching(identifier: "heart-widget").firstMatch
        let hrv = catalog.descendants(matching: .any).matching(identifier: "hrv-widget").firstMatch
        XCTAssertEqual(small.frame.width, heart.frame.width, accuracy: 1)
        XCTAssertEqual(heart.frame.width, hrv.frame.width, accuracy: 1)
        capture(app, name: "Design System live widget sizes")

        let replay = catalog.buttons["replay-design-system-motion"]
        scrollTo(replay, in: catalog)
        replay.tap()
        let gauge = catalog.buttons["blast-gauge"]
        let settled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value CONTAINS %@", "7.2 PSI, above 14-day average 5.4 PSI"), object: gauge
        )
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 8), .completed)
        capture(app, name: "Design System motion preview")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        let light = app.buttons["theme-light"]
        XCTAssertTrue(light.waitForExistence(timeout: 5))
        XCTAssertEqual(light.value as? String, "Selected")
        app.buttons["theme-gray"].tap()
    }

    private func scrollTo(_ element: XCUIElement, in scrollView: XCUIElement) {
        for _ in 0..<10 {
            if element.exists && element.isHittable && element.frame.midY < scrollView.frame.maxY - 80 { return }
            scrollView.swipeUp()
        }
        XCTAssertTrue(element.exists && element.isHittable, "Catalog component should be reachable")
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
