import XCTest

@MainActor
final class WidgetGridEditingTests: XCTestCase {
    func testFooterEditingReflowsCardsByDraggingAndRemovesWidget() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        let scroll = app.scrollViews["today-dashboard-scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 15))
        XCTAssertFalse(element("customize-widgets", in: app).exists, "The top bar must not contain the old ellipsis menu")

        let edit = app.buttons["edit-widgets"]
        reveal(edit, using: scroll)
        XCTAssertTrue(edit.isHittable, "The small Edit Widgets button must be at the end of the dashboard")
        edit.tap()
        XCTAssertTrue(element("widget-grid-editor", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(element("widget-layout-editor", in: app).exists, "Editing must happen directly in the card grid")

        let sleep = element("editable-widget-sleep", in: app)
        let cognition = element("editable-widget-cognition", in: app)
        reveal(sleep, using: scroll)
        XCTAssertTrue(sleep.exists && cognition.exists)
        XCTAssertEqual(sleep.frame.minY, cognition.frame.minY, accuracy: 3)
        XCTAssertGreaterThan(sleep.frame.minX, cognition.frame.minX)
        let width = sleep.frame.width
        let height = sleep.frame.height
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: sleep.frame.midX, dy: sleep.frame.midY))
        let end = origin.withOffset(CGVector(dx: cognition.frame.midX, dy: cognition.frame.midY))
        // Allow the native lift to finish before the short horizontal trajectory.
        start.press(forDuration: 1.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.6)
        wait("Dragging Sleep over Cognition must exchange their positions in the same row") {
            sleep.exists && cognition.exists && sleep.frame.minX < cognition.frame.minX
                && abs(sleep.frame.minY - cognition.frame.minY) < 3
        }
        XCTAssertEqual(sleep.frame.width, width, accuracy: 3)
        XCTAssertEqual(sleep.frame.height, height, accuracy: 3)
        screenshot(app, name: "Medium widgets reflow after a real card drag")

        let removeHeart = app.buttons["remove-widget-heart"]
        reveal(removeHeart, using: scroll)
        XCTAssertTrue(removeHeart.isHittable)
        removeHeart.tap()
        wait("The remove badge must remove Heart from the grid") {
            !self.element("editable-widget-heart", in: app).exists
        }
        let done = app.buttons["widget-edit-done"]
        reveal(done, using: scroll)
        done.tap()
        XCTAssertTrue(app.buttons["edit-widgets"].waitForExistence(timeout: 5))
        XCTAssertFalse(element("editable-widget-sleep", in: app).exists)
        XCTAssertTrue(element("sleep-widget", in: app).exists)
        screenshot(app, name: "Dashboard returns from inline editing")
    }

    private func reveal(_ target: XCUIElement, using scroll: XCUIElement) {
        for _ in 0..<6 {
            if target.exists && target.isHittable { return }
            if target.exists && target.frame.minY < scroll.frame.minY + 54 {
                scroll.swipeDown()
            } else {
                scroll.swipeUp()
            }
        }
    }

    private func element(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func wait(_ message: String, condition: @escaping () -> Bool) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed, message)
    }

    private func screenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
