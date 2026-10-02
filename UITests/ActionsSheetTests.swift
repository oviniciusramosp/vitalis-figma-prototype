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
