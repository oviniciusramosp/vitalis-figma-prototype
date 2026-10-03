import XCTest

@MainActor
final class ActionsSheetTests: XCTestCase {
    func testSheetSnapsAtScrollThresholdAndHandleOverridesPosition() {
        let app = XCUIApplication()
        app.launchArguments = ["--preview-motion", "--reset-theme"]
        app.launch()
        let header = element("today-header", in: app)
        let sheet = element("today-actions-panel", in: app)
        let handle = app.buttons["actions-panel-handle"]
        let scroll = app.scrollViews["today-dashboard-scroll"]
        XCTAssertTrue(handle.waitForExistence(timeout: 15))
        expect(sheet, "Expanded")
        let initialY = sheet.frame.minY
        let initialHeader = header.frame

        // A short drag scrolls the content without moving the resting sheet.
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: scroll.frame.midX, dy: scroll.frame.minY + 320))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -38)), withVelocity: .slow, thenHoldForDuration: 0.2)
        expect(sheet, "Expanded")
        XCTAssertEqual(sheet.frame.minY, initialY, accuracy: 2)

        scroll.swipeUp()
        expect(sheet, "Collapsed")
        XCTAssertEqual(header.frame.minY, initialHeader.minY, accuracy: 2)
        XCTAssertFalse(app.buttons["Start cognitive test"].exists && app.buttons["Start cognitive test"].isHittable)
        XCTAssertTrue(handle.isHittable, "The handle must remain reachable over the tabs")
        screenshot(app, "Sheet snaps down; header stays fixed")

        // The handle can reopen the sheet even while the content stays scrolled.
        let collapsedHandle = origin.withOffset(CGVector(dx: handle.frame.midX, dy: handle.frame.midY))
        collapsedHandle.press(forDuration: 0.05, thenDragTo: collapsedHandle.withOffset(CGVector(dx: 0, dy: -95)), withVelocity: .slow, thenHoldForDuration: 0.2)
        expect(sheet, "Expanded")
        XCTAssertTrue(app.buttons["Start cognitive test"].isHittable)

        let expandedHandle = origin.withOffset(CGVector(dx: handle.frame.midX, dy: handle.frame.midY))
        expandedHandle.press(forDuration: 0.05, thenDragTo: expandedHandle.withOffset(CGVector(dx: 0, dy: 90)), withVelocity: .slow, thenHoldForDuration: 0.2)
        expect(sheet, "Collapsed")
        scroll.swipeDown()
        expect(sheet, "Expanded")
        screenshot(app, "Sheet returns at upper scroll trigger")
    }

    func testNativeSheetKeepsTabsVisibleAndDashboardInteractive() {
        let app = XCUIApplication()
        app.launchArguments = ["--native-actions-sheet", "--preview-motion", "--reset-theme"]
        app.launch()
        let panel = element("native-actions-panel", in: app)
        let scroll = app.scrollViews["today-dashboard-scroll"]
        func tab(_ title: String) -> XCUIElement {
            let transparent = app.buttons["collapsed-tab-" + title]
            return transparent.exists ? transparent : app.tabBars.buttons[title]
        }
        var today: XCUIElement { tab("Today") }
        var more: XCUIElement { tab("More") }
        XCTAssertTrue(today.waitForExistence(timeout: 15))
        expect(panel, "Expanded")
        XCTAssertTrue(today.isHittable)
        XCTAssertTrue(more.isHittable)
        XCTAssertTrue(app.buttons["Start cognitive test"].isHittable)
        let expandedSideInset = today.frame.minX - panel.frame.minX
        XCTAssertEqual(panel.frame.maxY - today.frame.maxY, expandedSideInset, accuracy: 2)
        screenshot(app, "Native sheet expanded with embedded tabs")

        scroll.swipeUp()
        expect(panel, "Collapsed")
        XCTAssertTrue(today.isHittable)
        XCTAssertTrue(more.isHittable)
        XCTAssertFalse(app.buttons["Start cognitive test"].isHittable)
        XCTAssertEqual(today.frame.minY, more.frame.minY, accuracy: 1)
        XCTAssertEqual(today.frame.height, more.frame.height, accuracy: 1)
        let leftInset = today.frame.minX - panel.frame.minX
        XCTAssertEqual(today.frame.minY - panel.frame.minY, leftInset, accuracy: 2)
        XCTAssertEqual(panel.frame.maxX - more.frame.maxX, leftInset, accuracy: 2)
        screenshot(app, "Native sheet collapsed with tabs visible")

        more.tap()
        XCTAssertTrue(app.navigationBars["More"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Today"].isHittable)
        app.tabBars.buttons["Today"].tap()
        expect(panel, "Collapsed")
        XCTAssertTrue(more.isHittable)


        // The native grabber remains usable while the background is scrolled.
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let grabber = origin.withOffset(CGVector(dx: app.frame.midX, dy: today.frame.minY - 4))
        grabber.press(forDuration: 0.05, thenDragTo: grabber.withOffset(CGVector(dx: 0, dy: -210)), withVelocity: .slow, thenHoldForDuration: 0.3)
        expect(panel, "Expanded")
        XCTAssertTrue(today.isHittable)


        scroll.swipeDown()
        expect(panel, "Expanded")
        app.buttons["Start cognitive test"].tap()
        XCTAssertTrue(app.navigationBars["Cognitive test"].waitForExistence(timeout: 5))
        app.buttons["Close"].tap()
        XCTAssertTrue(today.waitForExistence(timeout: 5))
        more.tap()
        XCTAssertTrue(app.navigationBars["More"].waitForExistence(timeout: 5))
        XCTAssertTrue(today.isHittable)
        today.tap()
        expect(panel, "Expanded")
    }

    func testNativeSheetCanBeEnabledAndDisabledFromMore() {
        let app = XCUIApplication()
        app.launchArguments = ["--preview-motion", "--reset-theme"]
        app.launch()
        let more = app.tabBars.buttons["More"]
        XCTAssertTrue(more.waitForExistence(timeout: 15))
        more.tap()
        let toggle = app.switches["native-sheet-experiment"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        if toggle.value as? String == "1" { toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap() }
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        expect(toggle, "1")
        app.terminate()
        app.launch()
        XCTAssertTrue(element("native-actions-panel", in: app).waitForExistence(timeout: 5))
        app.tabBars.buttons["More"].tap()
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        app.terminate()
        app.launch()
        XCTAssertTrue(element("today-actions-panel", in: app).waitForExistence(timeout: 5))
    }

    private func element(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func expect(_ element: XCUIElement, _ value: String) {
        let predicate = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [predicate], timeout: 5), .completed)
    }

    private func screenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
