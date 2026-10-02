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
            _ = element("customize-widgets", in: app).waitForExistence(timeout: 10)
            app.terminate()
        }
        super.tearDown()
    }

    func testNativeDragMovesMediumWidgetAboveBlastAndPersists() {
        let app = launchDefaultLayout()
        let sleep = element("sleep-widget", in: app)
        let blast = element("blast-gauge", in: app)
        guard require(sleep.waitForExistence(timeout: 5), "The default Sleep widget must exist", in: app),
              require(blast.exists, "Today's Blast indicator must exist", in: app) else { return }
        expectValue(sleep, contains: "Widget size: Medium")
        let originalSize = sleep.frame.size
        guard require(originalSize.width > 0 && originalSize.height > 0,
                      "Sleep must have measurable dimensions before moving", in: app) else { return }

        guard openEditor(in: app) else { return }
        let sleepRow = element("widget-layout-row-sleep", in: app)
        let anchor = element("widget-layout-blast-anchor", in: app)
        guard require(sleepRow.waitForExistence(timeout: 5) && anchor.exists,
                      "The editor must expose Sleep and the main Blast gauge", in: app) else { return }
        expectValue(sleepRow, contains: "Widget size: Medium")
        expectValue(sleepRow, contains: "Below TODAY’S BLAST")
        XCTAssertGreaterThan(sleepRow.frame.minY, anchor.frame.maxY)
        screenshot(app, name: "Native widget editor before dragging")

        dragRow(sleepRow, identifier: "widget-layout-row-sleep", before: anchor, in: app)
        guard wait("Sleep must move before the Blast anchor after a real handle drag", in: app, condition: {
            sleepRow.exists && anchor.exists && sleepRow.frame.maxY <= anchor.frame.minY + 2
        }) else { return }
        expectValue(sleepRow, contains: "Above TODAY’S BLAST")
        expectValue(sleepRow, contains: "Widget size: Medium")
        screenshot(app, name: "Sleep reordered above the Blast anchor")
        guard closeEditor(in: app) else { return }
        scrollToTop(in: app)
        assertMediumAboveBlast(sleep, blast: blast, originalSize: originalSize, in: app)
        expectValue(sleep, contains: "Value: 6h30")
        expectValue(sleep, contains: "Chart days: 7")
        screenshot(app, name: "Sleep Medium above Today's Blast")

        app.terminate()
        // Omit reset/test-preview flags so this launch reads the persisted layout.
        app.launchArguments = []
        app.launch()
        guard require(element("customize-widgets", in: app).waitForExistence(timeout: 15),
                      "The dashboard must reopen", in: app) else { return }
        scrollToTop(in: app)
        let restoredSleep = element("sleep-widget", in: app)
        let restoredBlast = element("blast-gauge", in: app)
        assertMediumAboveBlast(restoredSleep, blast: restoredBlast, originalSize: originalSize, in: app)
        expectValue(restoredSleep, contains: "Value: 6h30")
        screenshot(app, name: "Widget order survives app relaunch")

        guard openEditor(in: app) else { return }
        let restoredRow = element("widget-layout-row-sleep", in: app)
        let restoredAnchor = element("widget-layout-blast-anchor", in: app)
        expectValue(restoredRow, contains: "Above TODAY’S BLAST")
        expectValue(restoredRow, contains: "Widget size: Medium")
        XCTAssertLessThanOrEqual(restoredRow.frame.maxY, restoredAnchor.frame.minY + 2)
        guard closeEditor(in: app) else { return }
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
        require(element("customize-widgets", in: app).waitForExistence(timeout: 15),
                "The dashboard customization menu must appear", in: app)
        return app
    }

    private func openEditor(in app: XCUIApplication) -> Bool {
        let customize = element("customize-widgets", in: app)
        guard require(customize.exists && customize.isHittable, "The header menu must be reachable", in: app) else { return false }
        customize.tap()
        let reorder = app.buttons["Reorder Widgets…"]
        guard require(reorder.waitForExistence(timeout: 5), "The menu must offer Reorder Widgets", in: app) else { return false }
        reorder.tap()
        return require(element("widget-layout-editor", in: app).waitForExistence(timeout: 5),
                       "The native layout editor must open", in: app)
    }

    private func closeEditor(in app: XCUIApplication) -> Bool {
        let done = element("widget-layout-done", in: app)
        guard require(done.exists && done.isHittable, "The editor Done action must be reachable", in: app) else { return false }
        done.tap()
        return wait("Done must dismiss the layout editor", in: app) {
            !self.element("widget-layout-editor", in: app).exists
        }
    }

    private func dragRow(_ row: XCUIElement, identifier: String, before anchor: XCUIElement, in app: XCUIApplication) {
        let matchingCell = app.cells.matching(identifier: identifier).firstMatch
        let containingCell = app.cells.containing(.any, identifier: identifier).firstMatch
        let nativeRow = matchingCell.exists ? matchingCell : (containingCell.exists ? containingCell : row)
        let handle = nativeRow.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Reorder")).firstMatch
        let matchingAnchorCell = app.cells.matching(identifier: anchor.identifier).firstMatch
        let containingAnchorCell = app.cells.containing(.any, identifier: anchor.identifier).firstMatch
        let nativeAnchor = matchingAnchorCell.exists
            ? matchingAnchorCell
            : (containingAnchorCell.exists ? containingAnchorCell : anchor)
        let sourceFrame = handle.exists ? handle.frame : nativeRow.frame
        let sourceX = handle.exists ? sourceFrame.midX : sourceFrame.maxX - 20
        // Freeze screen coordinates before the native list shifts its cells during the drag.
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: sourceX, dy: sourceFrame.midY))
        let destination = origin.withOffset(CGVector(dx: sourceX, dy: nativeAnchor.frame.minY - 6))
        start.press(forDuration: 0.7, thenDragTo: destination, withVelocity: .slow, thenHoldForDuration: 0.6)
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
