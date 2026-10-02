import XCTest

@MainActor
final class PrototypeSmokeTests: XCTestCase {
    func testDashboardAnimations() {
        let app = XCUIApplication()
        app.launchArguments = ["--preview-motion"]
        app.launch()
        let gauge = app.buttons["blast-gauge"]
        XCTAssertTrue(gauge.waitForExistence(timeout: 15))
        // Yesterday is 7.8 PSI; the comparison must still use the 14-day average.
        expectGauge(gauge, contains: "7.2 PSI, above 14-day average 5.4 PSI")
        attachScreenshot(app, name: "Animated dashboard initial")

        let history = app.descendants(matching: .any).matching(identifier: "blast-exposure-card").firstMatch
        XCTAssertTrue(history.exists)
        expectWidget(history, size: "Large")
        expectWidgetValue(history, contains: "Chart days: 14")
        func expectHistoryAverage(_ value: String) {
            let expectation = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "value CONTAINS %@", "14-day average: \(value) PSI"),
                object: history
            )
            XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
        }
        expectHistoryAverage("5.4")
        history.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.8)).tap()
        XCTAssertTrue((history.value as? String)?.contains("Selected reading,") == true, "History selection value: \(String(describing: history.value))")

        gauge.tap()
        expectGauge(gauge, contains: "3.2 PSI, below 14-day average 5.1 PSI")
        expectHistoryAverage("5.1")
        let belowAverageNotice = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS[c] %@ AND label CONTAINS[c] %@", "your Blast exposure is below", "your 14-day average")
        ).firstMatch
        XCTAssertTrue(belowAverageNotice.waitForExistence(timeout: 5))
        let crossedThresholdNotice = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "crossed", "4.0 PSI")
        ).firstMatch
        XCTAssertFalse(crossedThresholdNotice.exists, "A 3.2 PSI reading must not retain the crossed-4.0 warning")
        attachScreenshot(app, name: "Animated dashboard lower reading")
        gauge.tap()
        expectGauge(gauge, contains: "8.0 PSI, above 14-day average 5.4 PSI")
        expectHistoryAverage("5.4")
        XCTAssertTrue(crossedThresholdNotice.waitForExistence(timeout: 5))
        XCTAssertFalse(belowAverageNotice.exists)
        attachScreenshot(app, name: "Animated dashboard higher reading")
        gauge.tap()
        expectGauge(gauge, contains: "7.2 PSI, above 14-day average 5.4 PSI")
        expectHistoryAverage("5.4")

        app.tabBars.buttons["Exposure"].tap()
        app.segmentedControls.buttons["Month"].tap()
        XCTAssertTrue(app.staticTexts["This month"].waitForExistence(timeout: 5))
        attachScreenshot(app, name: "Animated monthly chart")
        app.segmentedControls.buttons["Week"].tap()
        XCTAssertTrue(app.staticTexts["This week"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Today"].tap()
    }

    func testDemoJourney() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Start cognitive test"].waitForExistence(timeout: 15))
        attachScreenshot(app, name: "Today")

        app.buttons["Start cognitive test"].tap()
        XCTAssertTrue(app.buttons["Start test"].waitForExistence(timeout: 5))
        app.buttons["Start test"].tap()
        for round in 0..<3 {
            let tap = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Tap now")).firstMatch
            XCTAssertTrue(tap.waitForExistence(timeout: 5))
            tap.tap()
            if round < 2 {
                XCTAssertTrue(app.buttons["Next round"].waitForExistence(timeout: 3))
                XCTAssertTrue(app.staticTexts["Round \(round + 1) of 3"].exists)
                app.buttons["Next round"].tap()
            }
        }
        XCTAssertTrue(app.buttons["Finish"].waitForExistence(timeout: 3))
        attachScreenshot(app, name: "Cognitive test completed")
        app.buttons["Finish"].tap()
        XCTAssertTrue(app.staticTexts["Completed this session"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Today"].tap()
        app.buttons["Report how you feel today"].tap()
        let save = app.buttons["Save report"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertFalse(save.isEnabled)
        app.staticTexts["Headache"].tap()
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.staticTexts["Check-in saved"].waitForExistence(timeout: 5))
        attachScreenshot(app, name: "Report confirmation")
        app.buttons["Done"].tap()
        XCTAssertEqual(app.staticTexts.matching(identifier: "Completed this session").count, 2)

        app.tabBars.buttons["Exposure"].tap()
        app.segmentedControls.buttons["Month"].tap()
        XCTAssertTrue(app.staticTexts["This month"].waitForExistence(timeout: 3))
        attachScreenshot(app, name: "Exposure")

        app.tabBars.buttons["Today"].tap()
        app.buttons["apple-watch-device"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["device-detail-appleWatch"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["device-last-synced"].label.contains("3 hours ago"))
        app.buttons["device-ignore"].tap()

        app.tabBars.buttons["More"].tap()
        app.buttons["Reset demo session"].tap()
        app.alerts.buttons["Reset"].tap()
        XCTAssertTrue(app.buttons["Start cognitive test"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Health"].tap()
        XCTAssertTrue(app.staticTexts["Ready when you are"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["No report this session"].exists)
        app.tabBars.buttons["Today"].tap()
    }

    func testWidgetCustomization() {
        let app = XCUIApplication()
        app.launchArguments = ["--preview-motion"]
        app.launch()
        let history = widget(in: app, identifier: "blast-exposure-card")
        XCTAssertTrue(history.waitForExistence(timeout: 15))
        expectWidget(history, size: "Large")
        expectWidgetValue(history, contains: "Chart days: 14")
        expectWidgetValue(history, contains: "14-day average: 5.4 PSI")

        changeWidgetSize(history, to: "Medium", in: app)
        expectWidgetValue(history, contains: "Chart days: 7")
        expectWidgetValue(history, contains: "7-day average: 6.2 PSI")
        let gauge = app.buttons["blast-gauge"]
        XCTAssertTrue(gauge.exists)
        gauge.tap()
        expectGauge(gauge, contains: "3.2 PSI, below 14-day average 5.1 PSI")
        expectWidgetValue(history, contains: "7-day average: 5.6 PSI")
        attachScreenshot(app, name: "Medium Blast Exposure lower reading")
        gauge.tap()
        expectGauge(gauge, contains: "8.0 PSI, above 14-day average 5.4 PSI")
        gauge.tap()
        expectGauge(gauge, contains: "7.2 PSI, above 14-day average 5.4 PSI")
        expectWidgetValue(history, contains: "7-day average: 6.2 PSI")
        attachScreenshot(app, name: "Medium Blast Exposure widget")
        changeWidgetSize(history, to: "Small", in: app)
        expectWidgetValue(history, contains: "Chart days: 0")
        expectWidgetValue(history, contains: "7.2 PSI")
        expectWidgetValue(history, contains: "14-day average: 5.4 PSI")
        attachScreenshot(app, name: "Small Blast Exposure widget")
        changeWidgetSize(history, to: "Large", in: app)
        expectWidgetValue(history, contains: "Chart days: 14")
        expectWidgetValue(history, contains: "14-day average: 5.4 PSI")
        attachScreenshot(app, name: "Large Blast Exposure widget")
        let dashboardScroll = app.scrollViews["today-dashboard-scroll"]
        let header = widget(in: app, identifier: "today-header")
        let report = app.buttons["Report how you feel today"]
        dashboardScroll.swipeUp()
        expectWidgetValue(header, contains: "Actions collapsed")
        XCTAssertFalse(report.exists && report.isHittable)
        dashboardScroll.swipeDown()
        expectWidgetValue(header, contains: "Actions expanded")
        XCTAssertTrue(report.isHittable)

        // Long press must also work over the chart without losing tap/drag selection.
        reveal(history, in: app)
        history.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.8)).press(forDuration: 1.2)
        let remove = app.buttons["Remove Widget"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        remove.tap()
        expectWidgetRemoved(history)

        let addWidgets = app.buttons["add-widgets"]
        XCTAssertTrue(addWidgets.waitForExistence(timeout: 5))
        reveal(addWidgets, in: app)
        addWidgets.tap()
        addWidgetFromGallery(kind: "activity", size: "Small", in: app)

        let activityWidget = widget(in: app, identifier: "activity-widget")
        XCTAssertTrue(activityWidget.waitForExistence(timeout: 5))
        expectWidget(activityWidget, size: "Small")
        reveal(activityWidget, in: app)
        attachScreenshot(app, name: "Activity widget added")
        activityWidget.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.16)).press(forDuration: 1.2)
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        remove.tap()
        expectWidgetRemoved(activityWidget)

        // Restore the initial widget so the smoke journey leaves a usable dashboard.
        XCTAssertTrue(addWidgets.waitForExistence(timeout: 5))
        reveal(addWidgets, in: app)
        addWidgets.tap()
        addWidgetFromGallery(kind: "blastExposure", size: "Large", in: app)
        XCTAssertTrue(history.waitForExistence(timeout: 5))
        expectWidget(history, size: "Large")
        expectWidgetValue(history, contains: "Chart days: 14")

        // Add another kind from an existing widget's menu, preserving the first.
        reveal(history, in: app)
        history.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.16)).press(forDuration: 1.2)
        app.buttons["Add Widgets…"].tap()
        addWidgetFromGallery(kind: "cognition", size: "Small", in: app)
        let cognitiveWidget = widget(in: app, identifier: "cognition-widget")
        XCTAssertTrue(cognitiveWidget.waitForExistence(timeout: 5))
        expectWidget(cognitiveWidget, size: "Small")
        XCTAssertTrue(history.exists)
        reveal(cognitiveWidget, in: app)
        attachScreenshot(app, name: "Multiple dashboard widgets")
        cognitiveWidget.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.16)).press(forDuration: 1.2)
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        remove.tap()
        expectWidgetRemoved(cognitiveWidget)
        attachScreenshot(app, name: "Blast Exposure widget restored")
    }

    func testWidgetRowPacking() {
        let app = XCUIApplication()
        app.launchArguments = ["--preview-widget-layout"]
        app.launch()
        let blast = widget(in: app, identifier: "blast-exposure-card", size: "Large")
        XCTAssertTrue(blast.waitForExistence(timeout: 15))
        expectWidgetValue(blast, contains: "Chart days: 14")
        let fullRowWidth = blast.frame.width
        XCTAssertGreaterThan(fullRowWidth, 0)

        let plot = blast.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.8))
        plot.tap()
        expectWidgetValue(blast, contains: "Selected reading,")
        plot.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Small"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Medium"].exists)
        XCTAssertTrue(app.buttons["Large"].exists)
        XCTAssertTrue(app.buttons["Remove Widget"].exists)
        XCTAssertTrue(app.buttons["Add Widgets…"].exists)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.15)).tap()

        let initialBlastY = blast.frame.minY
        let verticalStart = blast.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.8))
        let verticalEnd = verticalStart.withOffset(CGVector(dx: 0, dy: -180))
        verticalStart.press(forDuration: 0.05, thenDragTo: verticalEnd)
        let verticallyScrolled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            blast.exists && blast.frame.minY < initialBlastY - 20
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [verticallyScrolled], timeout: 5), .completed,
                       "The plot must let a vertical drag scroll the dashboard")
        attachScreenshot(app, name: "Chart vertical drag scrolls dashboard")

        let cognitionMedium = widget(in: app, identifier: "cognition-widget", size: "Medium")
        let sleepMedium = widget(in: app, identifier: "sleep-widget", size: "Medium")
        reveal(sleepMedium, in: app)
        assertRow([cognitionMedium, sleepMedium], fraction: 0.5, fullRowWidth: fullRowWidth)
        attachScreenshot(app, name: "MediumPair")

        let cognitionSmall = widget(in: app, identifier: "cognition-widget", size: "Small")
        let sleepSmall = widget(in: app, identifier: "sleep-widget", size: "Small")
        let activitySmall = widget(in: app, identifier: "activity-widget", size: "Small")
        reveal(activitySmall, in: app)
        assertRow([cognitionSmall, sleepSmall, activitySmall], fraction: 1.0 / 3.0, fullRowWidth: fullRowWidth)
        attachScreenshot(app, name: "SmallTrio")

        let health = widget(in: app, identifier: "health-summary-widget", size: "Large")
        reveal(health, in: app)
        XCTAssertEqual(health.frame.width, fullRowWidth, accuracy: 2)
        let carousel = health
        XCTAssertTrue(carousel.exists)
        carousel.swipeLeft()
        let activitySummary = widget(in: app, identifier: "health-summary-activity")
        if !activitySummary.isHittable { carousel.swipeLeft() }
        XCTAssertTrue(activitySummary.exists && activitySummary.isHittable)
        attachScreenshot(app, name: "HealthSlider")
    }

    func testHealthSliderStandalone() {
        let app = XCUIApplication()
        app.launchArguments = ["--preview-health-slider"]
        app.launch()
        let health = widget(in: app, identifier: "health-summary-widget")
        XCTAssertTrue(health.waitForExistence(timeout: 15))
        expectWidget(health, size: "Large")
        let carousel = health
        XCTAssertTrue(carousel.waitForExistence(timeout: 5))
        let blast = widget(in: app, identifier: "health-summary-blast")
        XCTAssertTrue(blast.exists)
        let initialBlastX = blast.frame.minX
        carousel.swipeLeft()
        let scrolled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            blast.exists && blast.frame.minX <= initialBlastX - 2
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [scrolled], timeout: 5), .completed,
                       "The standalone carousel must retain horizontal scrolling")
        let activity = widget(in: app, identifier: "health-summary-activity")
        XCTAssertTrue(activity.exists && activity.isHittable)
        XCTAssertLessThanOrEqual(activity.frame.maxX, health.frame.maxX + 1)
        attachScreenshot(app, name: "Standalone Health Slider scrolled")

        // Each size action opens the native menu and also checks Remove/Add.
        changeWidgetSize(health, to: "Medium", in: app)
        expectWidgetValue(health, contains: "Chart days: 7")
        changeWidgetSize(health, to: "Small", in: app)
        expectWidgetValue(health, contains: "Chart days: 0")
        changeWidgetSize(health, to: "Large", in: app)
        XCTAssertTrue(health.waitForExistence(timeout: 5))
        expectWidget(health, size: "Large")
        attachScreenshot(app, name: "Standalone Health Slider restored")
    }

    private func widget(in app: XCUIApplication, identifier: String, size: String? = nil) -> XCUIElement {
        let matches = app.descendants(matching: .any).matching(identifier: identifier)
        if let size {
            return matches.matching(NSPredicate(format: "value CONTAINS %@", "Widget size: \(size)")).firstMatch
        }
        return matches.firstMatch
    }

    private func changeWidgetSize(_ widget: XCUIElement, to size: String, in app: XCUIApplication) {
        widget.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.16)).press(forDuration: 1.2)
        let sizeOption = app.buttons[size]
        XCTAssertTrue(sizeOption.waitForExistence(timeout: 5), "The context menu should offer \(size)")
        XCTAssertTrue(app.buttons["Small"].exists)
        XCTAssertTrue(app.buttons["Medium"].exists)
        XCTAssertTrue(app.buttons["Large"].exists)
        XCTAssertTrue(app.buttons["Remove Widget"].exists)
        XCTAssertTrue(app.buttons["Add Widgets…"].exists)
        if size == "Small" { attachScreenshot(app, name: "Widget context menu") }
        sizeOption.tap()
        // Native palette pickers keep the menu open while updating the preview.
        if app.buttons["Remove Widget"].exists {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.2)).tap()
        }
        expectWidget(widget, size: size)
    }

    private func reveal(_ widget: XCUIElement, in app: XCUIApplication) {
        let dashboardScroll = app.scrollViews["today-dashboard-scroll"]
        XCTAssertTrue(dashboardScroll.waitForExistence(timeout: 5))
        let header = self.widget(in: app, identifier: "today-header")
        for _ in 0..<6 {
            if widget.exists {
                let visibleTop = max(dashboardScroll.frame.minY, header.frame.maxY)
                var visibleBottom = app.tabBars.firstMatch.frame.minY
                let start = app.buttons["Start cognitive test"]
                let actions = self.widget(in: app, identifier: "today-actions-panel")
                if start.exists && start.isHittable && actions.exists {
                    visibleBottom = min(visibleBottom, actions.frame.minY)
                }
                if widget.isHittable && widget.frame.minY >= visibleTop && widget.frame.maxY <= visibleBottom { return }
                if widget.frame.minY < visibleTop {
                    dashboardScroll.swipeDown()
                } else {
                    dashboardScroll.swipeUp()
                }
            } else {
                dashboardScroll.swipeUp()
            }
        }
        XCTAssertTrue(widget.exists && widget.isHittable, "Expected widget to be reachable by scrolling")
    }

    private func addWidgetFromGallery(kind: String, size: String, in app: XCUIApplication) {
        XCTAssertTrue(app.navigationBars["Widgets"].waitForExistence(timeout: 5))
        let kindOption = app.buttons["widget-kind-\(kind)"]
        revealInGallery(kindOption, in: app)
        kindOption.tap()
        let sizeOption = app.segmentedControls["widget-size-picker"].buttons[size]
        revealInGallery(sizeOption, in: app)
        sizeOption.tap()
        let confirm = app.buttons["confirm-add-widget"]
        revealInGallery(confirm, in: app)
        XCTAssertTrue(confirm.isEnabled)
        attachScreenshot(app, name: "Widget gallery \(kind) \(size)")
        confirm.tap()
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
        XCTAssertTrue(target.exists && target.isHittable, "Gallery control must be reachable")
    }

    private func assertRow(_ widgets: [XCUIElement], fraction: CGFloat, fullRowWidth: CGFloat) {
        let aligned = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let first = widgets.first, first.exists else { return false }
            return widgets.allSatisfy { $0.exists && abs($0.frame.minY - first.frame.minY) < 2 }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [aligned], timeout: 5), .completed)
        let expectedWidth = (fullRowWidth - CGFloat(widgets.count - 1) * 12) / CGFloat(widgets.count)
        for (index, widget) in widgets.enumerated() {
            XCTAssertEqual(widget.frame.width / fullRowWidth, fraction, accuracy: 0.04)
            XCTAssertEqual(widget.frame.width, expectedWidth, accuracy: 3)
            XCTAssertEqual(widget.frame.width, widgets[0].frame.width, accuracy: 2)
            XCTAssertEqual(widget.frame.height, 110, accuracy: 3)
            if index > 0 {
                XCTAssertGreaterThanOrEqual(widget.frame.minX, widgets[index - 1].frame.maxX)
            }
        }
    }

    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func expectGauge(_ gauge: XCUIElement, contains value: String) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value CONTAINS %@", value),
            object: gauge
        )
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
    }

    private func expectWidget(_ widget: XCUIElement, size: String) {
        expectWidgetValue(widget, contains: "Widget size: \(size)")
    }

    private func expectWidgetValue(_ widget: XCUIElement, contains value: String) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value CONTAINS %@", value),
            object: widget
        )
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
    }

    private func expectWidgetRemoved(_ widget: XCUIElement) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: widget
        )
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
    }
}
