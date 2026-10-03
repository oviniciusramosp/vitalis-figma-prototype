import XCTest

@MainActor
final class DashboardUXTests: XCTestCase {
    func testDashboardScrollKeepsHeaderAndTabsAvailable() {
        let app = XCUIApplication()
        app.launch()
        let header = element("today-header", in: app)
        guard require(header.waitForExistence(timeout: 15), "Today header must appear", in: app) else { return }
        expectValue(header, contains: "Actions expanded")

        let blast = element("blast-exposure-card", in: app)
        let cognition = element("cognition-widget", in: app)
        guard require(blast.waitForExistence(timeout: 5), "The default dashboard must contain Blast Exposure", in: app),
              require(cognition.exists, "The default dashboard must contain Cognition", in: app),
              require(blast.frame.width > 0 && blast.frame.height > 100, "Blast Exposure must have a visible layout frame", in: app),
              require(blast.frame.maxY <= cognition.frame.minY + 2, "Blast Exposure must be above Cognition", in: app) else { return }

        let blastDevice = app.buttons["blast-gauge-device"]
        let watchDevice = app.buttons["apple-watch-device"]
        XCTAssertTrue(blastDevice.isHittable && watchDevice.isHittable)
        let initialHeaderFrame = header.frame
        let initialBlastDeviceFrame = blastDevice.frame
        let initialWatchDeviceFrame = watchDevice.frame
        let start = app.buttons["Start cognitive test"]
        XCTAssertTrue(start.isHittable)
        XCTAssertTrue(element("today-actions-panel", in: app).exists)
        screenshot(app, name: "Default dashboard before scrolling")

        let scroll = app.scrollViews["today-dashboard-scroll"]
        XCTAssertTrue(scroll.exists)
        for _ in 0..<3 {
            scroll.swipeUp()
            if (header.value as? String)?.contains("Actions collapsed") == true { break }
        }
        expectValue(header, contains: "Actions collapsed")
        XCTAssertFalse(start.exists && start.isHittable)
        assertSameFrame(header.frame, initialHeaderFrame)
        assertSameFrame(blastDevice.frame, initialBlastDeviceFrame)
        assertSameFrame(watchDevice.frame, initialWatchDeviceFrame)
        XCTAssertTrue(blastDevice.isHittable && watchDevice.isHittable)
        for title in ["Today", "Exposure", "Health", "More"] {
            XCTAssertTrue(app.tabBars.buttons[title].isHittable, "\(title) must remain reachable while scrolling")
        }
        screenshot(app, name: "Scrolled dashboard with fixed header")

        for _ in 0..<3 {
            scroll.swipeDown()
            if start.exists && start.isHittable { break }
        }
        expectValue(header, contains: "Actions expanded")
        XCTAssertTrue(start.isHittable)
        XCTAssertTrue(element("today-actions-panel", in: app).exists)
        assertSameFrame(header.frame, initialHeaderFrame)
        assertSameFrame(blastDevice.frame, initialBlastDeviceFrame)
        assertSameFrame(watchDevice.frame, initialWatchDeviceFrame)
        screenshot(app, name: "Dashboard actions reopened")
    }

    func testDeviceModalsPreserveIndependentSyncState() {
        let app = XCUIApplication()
        app.launch()
        let blastButton = app.buttons["blast-gauge-device"]
        let watchButton = app.buttons["apple-watch-device"]
        XCTAssertTrue(blastButton.waitForExistence(timeout: 15))
        expectValue(blastButton, contains: "Synchronization alert")
        expectValue(watchButton, contains: "No device alert")
        screenshot(app, name: "Default device badges: Blast only")
        let watchCenter = CGPoint(x: watchButton.frame.midX, y: watchButton.frame.midY)
        let exposureTab = app.tabBars.buttons["Exposure"]
        let exposureTabCenter = CGPoint(x: exposureTab.frame.midX, y: exposureTab.frame.midY)

        blastButton.tap()
        let blastModal = element("device-detail-blastGauge", in: app)
        XCTAssertTrue(blastModal.waitForExistence(timeout: 5))
        expectLabel(element("device-last-synced", in: app), equals: "Last synced: 2 days ago.")
        XCTAssertTrue(app.buttons["device-sync-now"].isHittable)
        XCTAssertTrue(app.buttons["device-ignore"].isHittable)
        XCTAssertFalse(exposureTab.exists && exposureTab.isHittable)
        let start = app.buttons["Start cognitive test"]
        XCTAssertFalse(start.exists && start.isHittable)

        // Coordinates captured before opening the modal exercise the blocked backdrop.
        tap(exposureTabCenter, in: app)
        tap(watchCenter, in: app)
        XCTAssertTrue(blastModal.exists)
        XCTAssertFalse(element("device-detail-appleWatch", in: app).exists)
        screenshot(app, name: "Blast Gauge unsynced modal")
        app.buttons["device-ignore"].tap()
        expectGone(blastModal)
        XCTAssertTrue(app.tabBars.buttons["Today"].isSelected)
        XCTAssertFalse(app.buttons["Start test"].exists)

        // Ignore preserves stale state; completing Blast sync leaves Watch stale.
        blastButton.tap()
        XCTAssertTrue(blastModal.waitForExistence(timeout: 5))
        expectLabel(element("device-last-synced", in: app), equals: "Last synced: 2 days ago.")
        completeSync(in: app)
        screenshot(app, name: "Blast Gauge simulated sync completed")
        app.buttons["device-done"].tap()
        expectGone(blastModal)
        expectLabel(blastButton, contains: "Blast Gauge synced, battery")
        expectValue(blastButton, contains: "No device alert")
        expectValue(watchButton, contains: "No device alert")
        expectLabel(watchButton, contains: "last synced 3 hours ago")

        watchButton.tap()
        let watchModal = element("device-detail-appleWatch", in: app)
        XCTAssertTrue(watchModal.waitForExistence(timeout: 5))
        expectLabel(element("device-last-synced", in: app), equals: "Last synced: 3 hours ago.")
        expectValue(element("device-battery", in: app), contains: "38 percent")
        screenshot(app, name: "Apple Watch unsynced with battery")
        app.buttons["device-ignore"].tap()
        expectGone(watchModal)
        watchButton.tap()
        XCTAssertTrue(watchModal.waitForExistence(timeout: 5))
        expectLabel(element("device-last-synced", in: app), equals: "Last synced: 3 hours ago.")
        completeSync(in: app)
        expectValue(element("device-battery", in: app), contains: "38 percent")
        screenshot(app, name: "Apple Watch simulated sync completed")
        app.buttons["device-done"].tap()
        expectGone(watchModal)

        for (button, modal) in [(blastButton, blastModal), (watchButton, watchModal)] {
            button.tap()
            XCTAssertTrue(modal.waitForExistence(timeout: 5))
            expectLabel(element("device-connection-status", in: app), equals: "Connected")
            expectLabel(element("device-last-synced", in: app), equals: "Last synced: Just now.")
            XCTAssertFalse(app.buttons["device-sync-now"].exists)
            app.buttons["device-done"].tap()
            expectGone(modal)
        }
        XCTAssertTrue(app.tabBars.buttons["Today"].isSelected)
    }

    func testPhysiologicalWidgetsShareValuesWithHealthOverview() {
        let app = XCUIApplication()
        app.launchArguments = ["--preview-motion"]
        app.launch()
        var anchor = element("blast-exposure-card", in: app)
        XCTAssertTrue(anchor.waitForExistence(timeout: 15))
        let samples = [
            (kind: "heart", size: "Small", days: 0, value: "90 bpm", unit: "bpm"),
            (kind: "hrv", size: "Medium", days: 7, value: "48 ms", unit: "ms"),
            (kind: "respiration", size: "Large", days: 14, value: "16 breaths/min", unit: "breaths/min")
        ]
        for sample in samples {
            revealOnDashboard(anchor, in: app)
            anchor.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.16)).press(forDuration: 1.2)
            let addWidgets = app.buttons["Add Widgets…"]
            XCTAssertTrue(addWidgets.waitForExistence(timeout: 5))
            addWidgets.tap()
            XCTAssertTrue(app.navigationBars["Widgets"].waitForExistence(timeout: 5))
            let kind = app.buttons["widget-kind-\(sample.kind)"]
            revealInGallery(kind, in: app)
            kind.tap()
            let size = app.segmentedControls["widget-size-picker"].buttons[sample.size]
            revealInGallery(size, in: app)
            size.tap()
            let confirm = app.buttons["confirm-add-widget"]
            revealInGallery(confirm, in: app)
            screenshot(app, name: "\(sample.kind) \(sample.size) gallery preview")
            confirm.tap()

            let card = element("\(sample.kind)-widget", in: app)
            XCTAssertTrue(card.waitForExistence(timeout: 5))
            revealOnDashboard(card, in: app)
            expectValue(card, contains: "Widget size: \(sample.size)")
            expectValue(card, contains: "Value: \(sample.value)")
            expectValue(card, contains: "Chart days: \(sample.days)")
            expectValue(card, contains: "Chart unit: \(sample.unit)")
            screenshot(app, name: "\(sample.kind) \(sample.size) dashboard widget")
            anchor = card
        }

        app.terminate()
        app.launchArguments = ["--preview-health-slider"]
        app.launch()
        let health = element("health-summary-widget", in: app)
        XCTAssertTrue(health.waitForExistence(timeout: 15))
        expectValue(health, contains: "Widget size: Large")
        expectValue(health, contains: "Heart: 90 bpm.")
        expectValue(health, contains: "HRV: 48 ms.")
        expectValue(health, contains: "Respiration: 16 breaths/min.")
        let respiration = element("health-summary-respiration", in: app)
        for _ in 0..<3 {
            health.swipeLeft()
            if respiration.exists && respiration.isHittable { break }
        }
        XCTAssertTrue(respiration.exists && respiration.isHittable)
        XCTAssertLessThanOrEqual(respiration.frame.maxX, health.frame.maxX + 1)
        for sample in samples {
            expectValue(element("health-summary-\(sample.kind)", in: app), contains: sample.value)
        }
        screenshot(app, name: "Health Overview shares physiological readings")
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func completeSync(in app: XCUIApplication) {
        app.buttons["device-sync-now"].tap()
        let connected = element("device-connection-status", in: app)
        XCTAssertTrue(connected.waitForExistence(timeout: 5))
        expectLabel(connected, equals: "Connected")
        expectLabel(element("device-last-synced", in: app), equals: "Last synced: Just now.")
        XCTAssertTrue(app.buttons["device-done"].isHittable)
    }

    private func revealOnDashboard(_ target: XCUIElement, in app: XCUIApplication) {
        let scroll = app.scrollViews["today-dashboard-scroll"]
        let header = element("today-header", in: app)
        for _ in 0..<6 {
            if target.exists {
                let visibleTop = max(scroll.frame.minY, header.frame.maxY)
                var visibleBottom = app.tabBars.firstMatch.frame.minY
                let start = app.buttons["Start cognitive test"]
                if start.exists && start.isHittable {
                    let actions = element("today-actions-panel", in: app)
                    if actions.exists {
                        visibleBottom = min(visibleBottom, actions.frame.minY)
                    }
                }
                if target.isHittable && target.frame.minY >= visibleTop && target.frame.maxY <= visibleBottom { return }
                if target.frame.minY < visibleTop {
                    scroll.swipeDown()
                } else {
                    scroll.swipeUp()
                }
            } else {
                scroll.swipeUp()
            }
        }
        require(target.exists && target.isHittable, "Dashboard widget must be reachable", in: app)
    }

    private func revealInGallery(_ target: XCUIElement, in app: XCUIApplication) {
        let scroll: XCUIElement
        if app.collectionViews.firstMatch.exists {
            scroll = app.collectionViews.firstMatch
        } else if app.tables.firstMatch.exists {
            scroll = app.tables.firstMatch
        } else {
            scroll = app.scrollViews.firstMatch
        }
        for _ in 0..<6 {
            if target.exists && target.isHittable { return }
            scroll.swipeUp()
        }
        require(target.exists && target.isHittable, "Gallery control must be reachable", in: app)
    }

    private func tap(_ point: CGPoint, in app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: point.x, dy: point.y)).tap()
    }

    private func expectValue(_ target: XCUIElement, contains text: String) {
        wait(for: NSPredicate(format: "value CONTAINS %@", text), on: target)
    }

    private func expectLabel(_ target: XCUIElement, contains text: String) {
        wait(for: NSPredicate(format: "label CONTAINS %@", text), on: target)
    }

    private func expectLabel(_ target: XCUIElement, equals text: String) {
        wait(for: NSPredicate(format: "label == %@", text), on: target)
    }

    private func expectGone(_ target: XCUIElement) {
        wait(for: NSPredicate(format: "exists == false"), on: target)
    }

    private func wait(for predicate: NSPredicate, on target: XCUIElement) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: target)], timeout: 5), .completed)
    }

    private func assertSameFrame(_ actual: CGRect, _ expected: CGRect) {
        XCTAssertEqual(actual.minX, expected.minX, accuracy: 2)
        XCTAssertEqual(actual.minY, expected.minY, accuracy: 2)
        XCTAssertEqual(actual.width, expected.width, accuracy: 2)
        XCTAssertEqual(actual.height, expected.height, accuracy: 2)
    }

    @discardableResult
    private func require(_ condition: Bool, _ message: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> Bool {
        if !condition {
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "Dashboard hierarchy on failure"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
            screenshot(app, name: "Dashboard failure")
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
