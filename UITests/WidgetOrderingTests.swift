import XCTest

@MainActor
final class WidgetOrderingTests: XCTestCase {
    private var needsLayoutReset = false

    override func tearDown() {
        if needsLayoutReset {
            let app = XCUIApplication()
            app.terminate()
            app.launchArguments = ["--reset-widget-layout"]
            app.launch()
            _ = element("today-header", in: app).waitForExistence(timeout: 10)
            app.terminate()
        }
        super.tearDown()
    }

    func testCardDragMovesMediumWidgetAboveBlastAndPersists() {
        let app = launchDefaultLayout()
        let sleep = element("sleep-widget", in: app)
        let blast = element("blast-gauge", in: app)
        guard require(sleep.waitForExistence(timeout: 5) && blast.exists,
                      "Sleep and Today’s Blast must appear", in: app) else { return }
        let originalSize = sleep.frame.size
        guard openEditor(in: app) else { return }
        let scroll = app.scrollViews["today-dashboard-scroll"]
        scroll.swipeDown()
        let card = element("editable-widget-sleep", in: app)
        let target = element("widget-drop-above-blast", in: app)
        guard require(card.exists && target.exists && card.isHittable,
                      "The editable Sleep card and gauge drop zone must appear", in: app) else { return }
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: card.frame.midX, dy: card.frame.midY))
        let end = origin.withOffset(CGVector(dx: target.frame.midX, dy: target.frame.midY))
        start.press(forDuration: 0.7, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.35)
        guard wait("A card drag must move Sleep above the gauge", in: app, condition: {
            card.exists && blast.exists && card.frame.maxY <= blast.frame.minY + 3
        }) else { return }
        screenshot(app, name: "Sleep card dragged above Today’s Blast")
        guard closeEditor(in: app) else { return }
        scrollToTop(in: app)
        assertMediumAboveBlast(sleep, blast: blast, originalSize: originalSize, in: app)
        expectValue(sleep, contains: "Value: 6h30")
        expectValue(sleep, contains: "Chart days: 7")

        app.terminate()
        app.launchArguments = []
        app.launch()
        guard require(element("today-header", in: app).waitForExistence(timeout: 15),
                      "The dashboard must reopen", in: app) else { return }
        let restoredSleep = element("sleep-widget", in: app)
        let restoredBlast = element("blast-gauge", in: app)
        assertMediumAboveBlast(restoredSleep, blast: restoredBlast, originalSize: originalSize, in: app)
        expectValue(restoredSleep, contains: "Value: 6h30")
        screenshot(app, name: "Card order survives app relaunch")
    }

    func testQuickMovesPackMediumPairAndPreserveSizes() {
        let app = launchDefaultLayout()
        let sleep = element("sleep-widget", in: app)
        let cognition = element("cognition-widget", in: app)
        let blast = element("blast-gauge", in: app)
        let history = element("blast-exposure-card", in: app)
        guard require(history.waitForExistence(timeout: 5) && sleep.exists && cognition.exists,
                      "The default widgets must exist", in: app) else { return }
        let fullRowWidth = history.frame.width
        let mediumWidth = (fullRowWidth - 12) / 2

        guard quickMove(sleep, action: "Move Above Today’s Blast", in: app),
              quickMove(cognition, action: "Move Above Today’s Blast", in: app) else { return }
        scrollToTop(in: app)
        guard wait("The two Medium widgets must occupy one row above Today's Blast", in: app, condition: {
            sleep.exists && cognition.exists && blast.exists
                && abs(sleep.frame.minY - cognition.frame.minY) <= 2
                && max(sleep.frame.maxY, cognition.frame.maxY) <= blast.frame.minY + 2
        }) else { return }
        for widget in [sleep, cognition] {
            expectValue(widget, contains: "Widget size: Medium")
            expectValue(widget, contains: "Chart days: 7")
            XCTAssertEqual(widget.frame.width, mediumWidth, accuracy: 3)
            XCTAssertEqual(widget.frame.height, 110, accuracy: 3)
        }
        let orderedFrames = [sleep.frame, cognition.frame].sorted { $0.minX < $1.minX }
        XCTAssertEqual(orderedFrames[1].minX - orderedFrames[0].maxX, 12, accuracy: 3)
        screenshot(app, name: "Medium pair reordered above Today's Blast")

        guard quickMove(sleep, action: "Move Below Today’s Blast", in: app) else { return }
        scrollToTop(in: app)
        guard wait("Quick move must put Sleep below the Blast indicator", in: app, condition: {
            sleep.exists && blast.exists && sleep.frame.minY >= blast.frame.maxY - 2
        }) else { return }
        XCTAssertLessThanOrEqual(cognition.frame.maxY, blast.frame.minY + 2)
        expectValue(sleep, contains: "Widget size: Medium")
        XCTAssertEqual(sleep.frame.width, mediumWidth, accuracy: 3)
        screenshot(app, name: "Sleep moved below Today's Blast without resizing")
    }

    private func launchDefaultLayout() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-widget-layout"]
        needsLayoutReset = true
        app.launch()
        require(element("today-header", in: app).waitForExistence(timeout: 15),
                "The dashboard header must appear", in: app)
        return app
    }

    private func openEditor(in app: XCUIApplication) -> Bool {
        let edit = element("edit-widgets", in: app)
        guard reveal(edit, in: app) else { return false }
        edit.tap()
        return require(element("widget-grid-editor", in: app).waitForExistence(timeout: 5),
                       "The dashboard must enter card editing", in: app)
    }

    private func closeEditor(in app: XCUIApplication) -> Bool {
        let done = element("widget-edit-done", in: app)
        guard reveal(done, in: app) else { return false }
        done.tap()
        return wait("Done must leave card editing", in: app) {
            !self.element("widget-grid-editor", in: app).exists
        }
    }

    private func quickMove(_ widget: XCUIElement, action: String, in app: XCUIApplication) -> Bool {
        guard reveal(widget, in: app) else { return false }
        widget.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.16)).press(forDuration: 1.2)
        let option = app.buttons[action]
        guard require(option.waitForExistence(timeout: 5), "The widget menu must offer \(action)", in: app) else { return false }
        option.tap()
        return wait("The quick move menu must close", in: app) { !option.exists }
    }

    private func scrollToTop(in app: XCUIApplication) {
        let scroll = app.scrollViews["today-dashboard-scroll"]
        let header = element("today-header", in: app)
        for _ in 0..<5 {
            if (header.value as? String)?.contains("Actions expanded") == true { return }
            scroll.swipeDown()
        }
    }

    private func reveal(_ widget: XCUIElement, in app: XCUIApplication) -> Bool {
        let scroll = app.scrollViews["today-dashboard-scroll"]
        let header = element("today-header", in: app)
        for _ in 0..<6 {
            if widget.exists {
                let top = max(scroll.frame.minY, header.frame.maxY)
                var bottom = app.tabBars.firstMatch.frame.minY
                let start = app.buttons["Start cognitive test"]
                let panel = element("today-actions-panel", in: app)
                if start.exists && start.isHittable && panel.exists { bottom = min(bottom, panel.frame.minY) }
                if widget.isHittable && widget.frame.minY >= top && widget.frame.maxY <= bottom { return true }
                if widget.frame.minY < top { scroll.swipeDown() } else { scroll.swipeUp() }
            } else {
                scroll.swipeUp()
            }
        }
        return require(false, "The widget must be visible before opening its context menu", in: app)
    }

    private func assertMediumAboveBlast(_ widget: XCUIElement, blast: XCUIElement, originalSize: CGSize, in app: XCUIApplication) {
        guard wait("Sleep must be above Today's Blast", in: app, condition: {
            widget.exists && blast.exists && widget.frame.maxY <= blast.frame.minY + 2
        }) else { return }
        expectValue(widget, contains: "Widget size: Medium")
        XCTAssertEqual(widget.frame.width, originalSize.width, accuracy: 3)
        XCTAssertEqual(widget.frame.height, originalSize.height, accuracy: 3)
        XCTAssertEqual(widget.frame.height, 110, accuracy: 3)
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func expectValue(_ target: XCUIElement, contains text: String) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", text), object: target)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
    }

    @discardableResult
    private func wait(_ message: String, in app: XCUIApplication, condition: @escaping () -> Bool) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        return require(XCTWaiter.wait(for: [expectation], timeout: 5) == .completed, message, in: app)
    }

    @discardableResult
    private func require(_ condition: Bool, _ message: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> Bool {
        if !condition {
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "Widget ordering hierarchy on failure"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
            screenshot(app, name: "Widget ordering failure")
            XCTFail(message, file: file, line: line)
        }
        return condition
    }

    private func screenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
