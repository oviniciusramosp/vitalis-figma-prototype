import SwiftUI
import UIKit

struct TodayView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale
    @State private var sampleIndex = 0
    @State private var helmetRingProgress = 0.0
    @State private var watchRingProgress = 0.0
    @State private var showDeviceWarning = false
    @State private var showExposureAlert = false
    @State private var widgetLayout: PrototypeWidgetLayout
    @State private var showWidgetGallery = false
    @State private var showWidgetEditor = false
    @State private var scrollProgress: CGFloat = 0

    // Keep the original color when SwiftUI bridges this image to the native menu.
    private static let removeWidgetIcon = UIImage(systemName: "minus.circle")?
        .withTintColor(.systemRed, renderingMode: .alwaysOriginal)

    let onStartTest: () -> Void
    let onReport: () -> Void
    let onShowDevices: () -> Void
    let onShowDevice: (PrototypeDevice) -> Void
    let blastIsSynced: Bool
    let watchIsSynced: Bool

    init(
        onStartTest: @escaping () -> Void,
        onReport: @escaping () -> Void,
        onShowDevices: @escaping () -> Void,
        onShowDevice: ((PrototypeDevice) -> Void)? = nil,
        blastIsSynced: Bool = false,
        watchIsSynced: Bool = false
    ) {
        self.onStartTest = onStartTest
        self.onReport = onReport
        self.onShowDevices = onShowDevices
        self.onShowDevice = onShowDevice ?? { _ in onShowDevices() }
        self.blastIsSynced = blastIsSynced
        self.watchIsSynced = watchIsSynced
        _ = Self.resetWidgetLayoutForTesting
        _widgetLayout = State(initialValue: .load(defaultWidgets: Self.initialWidgets, persist: Self.persistsWidgetLayout))
    }

    private static let resetWidgetLayoutForTesting: Void = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--reset-widget-layout") {
            UserDefaults.standard.removeObject(forKey: "prototype.widget-layout.v1")
        }
        #endif
    }()

    private static var persistsWidgetLayout: Bool {
        #if DEBUG
        return !ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("--preview-") || $0 == "--ui-testing" }
        #else
        return true
        #endif
    }

    private static var initialWidgets: [PrototypeWidget] {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--preview-health-slider") {
            return [PrototypeWidget(kind: .healthSummary, size: .large)]
        }
        if ProcessInfo.processInfo.arguments.contains("--preview-widget-layout") {
            return [
                PrototypeWidget(kind: .blastExposure, size: .large),
                PrototypeWidget(kind: .cognition, size: .medium),
                PrototypeWidget(kind: .sleep, size: .medium),
                PrototypeWidget(kind: .cognition, size: .small),
                PrototypeWidget(kind: .sleep, size: .small),
                PrototypeWidget(kind: .activity, size: .small),
                PrototypeWidget(kind: .healthSummary, size: .large)
            ]
        }
        if ProcessInfo.processInfo.arguments.contains("--preview-motion") {
            return [PrototypeWidget(kind: .blastExposure, size: .large)]
        }
        #endif
        return [
            PrototypeWidget(kind: .blastExposure, size: .large),
            PrototypeWidget(kind: .cognition, size: .medium),
            PrototypeWidget(kind: .sleep, size: .medium),
            PrototypeWidget(kind: .activity, size: .medium),
            PrototypeWidget(kind: .heart, size: .medium)
        ]
    }

    var body: some View {
        GeometryReader { geometry in
            // The reference has 725 points of content above the native tab bar.
            // Compress the gauge and its surrounding space on shorter phones.
            let verticalScale = min(1, max(0.38, (geometry.size.height - 410) / 315))
            let panelHeight = max(144, geometry.size.height - (256 + 315 * verticalScale))

            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: 54 + 20 * verticalScale)

                        if !widgetLayout.aboveBlastWidgets.isEmpty {
                            widgetGrid(widgetLayout.aboveBlastWidgets)
                                .padding(.horizontal, 20)
                                .frame(height: widgetAreaHeight(widgetLayout.aboveBlastWidgets))

                            Color.clear.frame(height: 24 * verticalScale)
                        }

                        blastGauge
                            .scaleEffect(verticalScale)
                            .frame(height: 240 * verticalScale)
                            .frame(maxWidth: .infinity)

                        Color.clear.frame(height: 20 * verticalScale)

                        exposureNotice
                            .frame(height: 68)

                        Color.clear.frame(height: 20 * verticalScale)

                        if !widgetLayout.belowBlastWidgets.isEmpty || widgetLayout.widgets.isEmpty {
                            widgetGrid(widgetLayout.belowBlastWidgets)
                                .padding(.horizontal, 20)
                                .frame(height: widgetAreaHeight(widgetLayout.belowBlastWidgets))
                        }

                        Color.clear.frame(height: 18 + 15 * verticalScale)
                    }
                    .frame(width: geometry.size.width, alignment: .top)
                    // Keep the collapse gesture available even with a single widget row.
                    .frame(minHeight: geometry.size.height + 80, alignment: .top)
                }
                .accessibilityIdentifier("today-dashboard-scroll")
                .overlay(alignment: .top) {
                    header
                        .frame(height: 54)
                        .background {
                            PrototypeBackdropBlur(progress: scrollProgress)
                                .overlay(Color.black.opacity(0.08 * scrollProgress))
                                .ignoresSafeArea(edges: .top)
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("today-header")
                        .accessibilityValue(scrollProgress >= 0.98 ? "Actions collapsed" : "Actions expanded")
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                .scrollClipDisabled()
                .scrollEdgeEffectHidden(true, for: .top)
                .onScrollGeometryChange(for: CGFloat.self) { scroll in
                    let offset = max(0, scroll.contentOffset.y + scroll.contentInsets.top)
                    // Track physical pixels without separate frame timers or chart updates.
                    return min(1, (offset * displayScale).rounded() / max(1, displayScale) / 80)
                } action: { _, progress in
                    scrollProgress = progress
                }
                actionsPanel(bottomInset: geometry.safeAreaInsets.bottom)
                    .frame(height: panelHeight, alignment: .top)
                    .offset(y: scrollProgress * (panelHeight - 18))
                    .allowsHitTesting(scrollProgress < 0.98)
                    .accessibilityHidden(scrollProgress >= 0.98)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("today-actions-panel")
            }
        }
        .foregroundStyle(PrototypeTheme.foreground)
        .task(id: reduceMotion) {
            await animateDeviceAppearance()
        }
        .sheet(isPresented: $showWidgetGallery) {
            WidgetGalleryView { kind, size in
                changeWidgets { widgetLayout.append(PrototypeWidget(kind: kind, size: size)) }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showWidgetEditor) {
            WidgetLayoutEditorView(layout: $widgetLayout, onChange: saveWidgetLayout)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.dark)
        }
    }

    private func widgetGrid(_ widgets: [PrototypeWidget]) -> some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 12) {
                if widgets.isEmpty {
                    Button {
                        showWidgetGallery = true
                    } label: {
                        Label("Add Widgets", systemImage: "plus")
                            .font(PrototypeFont.inter(size: 15, weight: .medium))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .buttonStyle(.plain)
                    .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(PrototypeTheme.foreground.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    }
                    .accessibilityIdentifier("add-widgets")
                    .accessibilityHint("Choose a widget and a size for your dashboard")
                } else {
                    ForEach(widgetRows(widgets)) { row in
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(row.widgets) { widget in
                                widgetCard(widget)
                                    .frame(width: widget.size.width(in: geometry.size.width, spacing: 12), height: widget.size.height)
                                    .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 16))
                                    .contextMenu {
                                        Picker("Widget Size", selection: widgetSizeBinding(for: widget)) {
                                            ForEach(PrototypeWidgetSize.allCases) { size in
                                                Label(size.title, systemImage: size.symbol)
                                                    .tag(size)
                                            }
                                        }
                                        .pickerStyle(.palette)
                                        .paletteSelectionEffect(.automatic)

                                        Button("Reorder Widgets…", systemImage: "arrow.up.arrow.down") {
                                            showWidgetEditor = true
                                        }

                                        let isAboveBlast = widgetLayout.aboveBlastWidgets.contains { $0.id == widget.id }
                                        Button(
                                            isAboveBlast ? "Move Below Today’s Blast" : "Move Above Today’s Blast",
                                            systemImage: isAboveBlast ? "arrow.down.to.line" : "arrow.up.to.line"
                                        ) {
                                            changeWidgets { widgetLayout.move(id: widget.id, aboveBlast: !isAboveBlast) }
                                        }

                                        Button(role: .destructive) {
                                            changeWidgets { widgetLayout.remove(id: widget.id) }
                                        } label: {
                                            Label {
                                                Text("Remove Widget")
                                            } icon: {
                                                if let icon = Self.removeWidgetIcon {
                                                    Image(uiImage: icon)
                                                        .renderingMode(.original)
                                                }
                                            }
                                        }

                                        Button("Add Widgets…", systemImage: "plus") {
                                            showWidgetGallery = true
                                        }
                                    }
                                    .menuOrder(.fixed)
                            }
                            if row.columnSpan < 6 {
                                Spacer(minLength: 0)
                            }
                        }
                        .frame(height: row.height)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func widgetCard(_ widget: PrototypeWidget) -> some View {
        switch widget.kind {
        case .blastExposure:
            BlastExposureCard(
                averageExposure: currentSample.average,
                historyHeights: currentSample.history,
                widgetSize: widget.size
            )
        case .cognition, .sleep, .activity, .heart, .hrv, .respiration:
            PrototypeAuxiliaryWidgetCard(
                kind: widget.kind,
                size: widget.size,
                onStartTest: onStartTest,
                onShowDevices: onShowDevices
            )
        case .healthSummary:
            HealthSummaryWidgetCard(
                exposure: currentSample.blast,
                averageExposure: currentSample.average,
                size: widget.size
            )
        }
    }

    private func widgetSizeBinding(for widget: PrototypeWidget) -> Binding<PrototypeWidgetSize> {
        Binding {
            widgetLayout.widgets.first { $0.id == widget.id }?.size ?? widget.size
        } set: { size in
            changeWidgets { widgetLayout.resize(id: widget.id, to: size) }
        }
    }

    private func changeWidgets(_ change: () -> Void) {
        withAnimation(reduceMotion ? nil : .spring(duration: 0.38, bounce: 0.06), change)
        saveWidgetLayout()
    }

    private func saveWidgetLayout() {
        if Self.persistsWidgetLayout { widgetLayout.save() }
    }

    private func widgetRows(_ widgets: [PrototypeWidget]) -> [PrototypeWidgetRow] {
        var rows: [PrototypeWidgetRow] = []
        for widget in widgets {
            if let last = rows.indices.last,
               rows[last].columnSpan + widget.size.columnSpan <= 6 {
                rows[last].widgets.append(widget)
            } else {
                rows.append(PrototypeWidgetRow(widgets: [widget]))
            }
        }
        return rows
    }

    private func widgetAreaHeight(_ widgets: [PrototypeWidget]) -> CGFloat {
        let rows = widgetRows(widgets)
        guard !rows.isEmpty else { return 134 }
        return rows.reduce(0) { $0 + $1.height } + CGFloat(max(0, rows.count - 1)) * 12
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image("vitalis-logo")
                .resizable()
                .scaledToFit()
                .frame(width: 151.767, height: 24)
                .accessibilityLabel("Vitalis")

            Menu {
                Button("Reorder Widgets…", systemImage: "arrow.up.arrow.down") {
                    showWidgetEditor = true
                }
                Button("Add Widgets…", systemImage: "plus") {
                    showWidgetGallery = true
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Customize Widgets")
            .accessibilityIdentifier("customize-widgets")

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                DeviceStatusButton(
                    image: "device-one",
                    ring: "device-one-ring",
                    progress: helmetRingProgress,
                    accessibilityLabel: blastIsSynced ? "Blast Gauge synced, battery 90 percent" : "Blast Gauge, battery 90 percent, last synced 2 days ago",
                    accessibilityIdentifier: "blast-gauge-device",
                    hasWarning: !blastIsSynced,
                    warningVisible: showDeviceWarning,
                    onTap: { onShowDevice(.blastGauge) }
                )

                DeviceStatusButton(
                    image: "device-two",
                    ring: "device-two-ring",
                    progress: watchRingProgress,
                    accessibilityLabel: watchIsSynced ? "Apple Watch synced, battery 38 percent, charge recommended" : "Apple Watch, battery 38 percent, last synced 3 hours ago",
                    accessibilityIdentifier: "apple-watch-device",
                    hasWarning: true,
                    warningVisible: showDeviceWarning,
                    onTap: { onShowDevice(.appleWatch) }
                )
            }
            .padding(.trailing, -5)
        }
        .padding(.horizontal, 20)
    }

    private var blastGauge: some View {
        BlastGaugeView(
            exposure: currentSample.blast,
            averageExposure: currentSample.average,
            onRefresh: refreshExposurePreview,
            onMotionStarted: { showExposureAlert = false },
            onMotionSettled: {
                if reduceMotion {
                    showExposureAlert = true
                } else {
                    withAnimation(.easeOut(duration: 0.24)) { showExposureAlert = true }
                }
            }
        )
    }

    private var exposureNotice: some View {
        HStack(spacing: 10) {
            Group {
                if currentSample.blast >= ExposurePreviewSample.demoPromptThresholdPSI {
                    Image("exposure-alert")
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 23))
                        .foregroundStyle(PrototypeTheme.success)
                }
            }
                .frame(width: 24, height: 24)
                .opacity(showExposureAlert ? 1 : 0)
                .offset(y: showExposureAlert ? 0 : -3)
                .accessibilityHidden(true)

            Text(currentSample.blast >= ExposurePreviewSample.demoPromptThresholdPSI
                 ? "Your Blast exposure crossed\n4.0 PSI this morning. Complete your tests."
                 : "Your Blast exposure is below\nyour 14-day average. Check in when ready.")
                .font(PrototypeFont.inter(size: 15, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 34)
        .accessibilityElement(children: .combine)
    }

    private func actionsPanel(bottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image("cognition")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)

                Text("Cognitive Test")
                    .font(PrototypeFont.inter(size: 15, weight: .semibold))

                Text("~30 sec")
                    .font(PrototypeFont.inter(size: 12, weight: .medium))
                    .foregroundStyle(PrototypeTheme.muted)

                Spacer(minLength: 0)

                Button("Start", systemImage: "play.fill", action: onStartTest)
                    .labelStyle(.titleAndIcon)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                    .tint(PrototypeTheme.success)
                    .accessibilityLabel("Start cognitive test")
            }
            .padding(.vertical, 16)

            Rectangle()
                .fill(PrototypeTheme.foreground.opacity(0.28))
                .frame(height: 1 / max(1, displayScale))
                .accessibilityHidden(true)

            HStack {
                Text("Feeling off today?")
                    .font(PrototypeFont.inter(size: 15))

                Spacer()

                Button("Report Now", action: onReport)
                    .font(PrototypeFont.inter(size: 15, weight: .medium))
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                    .tint(PrototypeTheme.success)
                    .foregroundStyle(PrototypeTheme.success)
                    .frame(minHeight: 30)
                    .accessibilityLabel("Report how you feel today")
            }
            .padding(.vertical, 12)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            panelShape
                .fill(.ultraThinMaterial)
                .overlay {
                    panelShape.fill(Color.black.opacity(0.12))
                }
                .padding(.bottom, -bottomInset)
        }
        .overlay {
            panelShape
                .stroke(PrototypeTheme.foreground.opacity(0.3), lineWidth: 0.5)
                .padding(.bottom, -bottomInset)
        }
        .overlay(alignment: .top) {
            Capsule()
                .fill(PrototypeTheme.foreground.opacity(0.1))
                .frame(width: 60, height: 4)
                .padding(.top, 6)
                .accessibilityHidden(true)
        }
    }

    private var panelShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 38, topTrailingRadius: 38)
    }

    @MainActor
    private func animateDeviceAppearance() async {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            helmetRingProgress = reduceMotion ? 1 : 0
            watchRingProgress = reduceMotion ? 1 : 0
            showDeviceWarning = reduceMotion
        }
        guard !reduceMotion else { return }

        do {
            try await Task.sleep(for: .milliseconds(80))
        } catch {
            return
        }
        guard !Task.isCancelled else { return }

        withAnimation(.spring(duration: 0.86, bounce: 0.08)) {
            helmetRingProgress = 1
        }
        do {
            try await Task.sleep(for: .milliseconds(220))
        } catch {
            return
        }
        guard !Task.isCancelled else { return }
        withAnimation(.spring(duration: 1.04, bounce: 0.1)) {
            watchRingProgress = 1
        }
        do {
            try await Task.sleep(for: .milliseconds(1130))
        } catch {
            return
        }
        guard !Task.isCancelled else { return }
        withAnimation(.spring(duration: 0.28, bounce: 0.12)) {
            showDeviceWarning = true
        }
    }

    @MainActor
    private func refreshExposurePreview() {
        sampleIndex = (sampleIndex + 1) % ExposurePreviewSample.samples.count
    }

    private var currentSample: ExposurePreviewSample {
        ExposurePreviewSample.samples[sampleIndex]
    }
}

private struct PrototypeWidgetRow: Identifiable {
    var widgets: [PrototypeWidget]
    var id: UUID { widgets[0].id }
    var height: CGFloat { widgets.map(\.size.height).max() ?? 134 }
    var columnSpan: Int { widgets.reduce(0) { $0 + $1.size.columnSpan } }
}

struct PrototypeBackdropBlur: UIViewRepresentable {
    let progress: CGFloat
    var style: UIBlurEffect.Style = .systemUltraThinMaterialDark

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView()
        view.isUserInteractionEnabled = false
        view.accessibilityElementsHidden = true
        return view
    }

    func updateUIView(_ view: UIVisualEffectView, context: Context) {
        let fraction = min(1, max(0, progress))
        let coordinator = context.coordinator
        guard fraction != coordinator.lastProgress else { return }
        coordinator.lastProgress = fraction
        if fraction == 0 || fraction == 1 {
            coordinator.animator?.stopAnimation(true)
            coordinator.animator = nil
            view.effect = fraction == 0 ? nil : UIBlurEffect(style: style)
            return
        }
        if coordinator.animator == nil {
            view.effect = nil
            let animator = UIViewPropertyAnimator(duration: 1, curve: .linear) { [weak view] in
                view?.effect = UIBlurEffect(style: style)
            }
            animator.pausesOnCompletion = true
            animator.startAnimation()
            animator.pauseAnimation()
            coordinator.animator = animator
        }
        guard let animator = coordinator.animator else { return }
        animator.fractionComplete = fraction
    }

    static func dismantleUIView(_ view: UIVisualEffectView, coordinator: Coordinator) {
        coordinator.animator?.stopAnimation(true)
    }

    final class Coordinator {
        var animator: UIViewPropertyAnimator?
        var lastProgress: CGFloat?
    }
}

private struct DeviceStatusButton: View {
    let image: String
    let ring: String
    let progress: Double
    let accessibilityLabel: String
    var accessibilityIdentifier = "device-status"
    var hasWarning = false
    var warningVisible = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                ZStack {
                    ZStack {
                        Image(isBodySensor ? "device-two-track" : "device-one-track")
                            .resizable()
                            .scaledToFit()

                        FigmaDeviceSweepShape(isBodySensor: isBodySensor, progress: progress)
                            .stroke(
                                isBodySensor ? PrototypeTheme.accent : PrototypeTheme.success,
                                style: StrokeStyle(lineWidth: 3.18749, lineCap: .round, lineJoin: .round)
                            )
                            .opacity(progress > 0 ? 1 : 0)
                    }
                    .frame(width: 34, height: 34)

                    deviceImage
                        .offset(y: 0.5)
                }
                .overlay {
                    if hasWarning {
                        Circle()
                            .fill(.black)
                            .frame(width: 17, height: 17)
                            .offset(y: -16)
                            .opacity(warningVisible ? 1 : 0)
                            .blendMode(.destinationOut)
                    }
                }
                .compositingGroup()

                if hasWarning {
                    Image("device-warning")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 12, height: 12)
                        .background(Circle().fill(.white).frame(width: 10, height: 10))
                        .scaleEffect(warningVisible ? 1 : 0.8)
                        .offset(y: -16)
                        .opacity(warningVisible ? 1 : 0)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityHint("Opens this device's battery and synchronization status")
    }

    private var isBodySensor: Bool { ring == "device-two-ring" }

    @ViewBuilder
    private var deviceImage: some View {
        if image == "device-two" {
            Image(image)
                .resizable()
                .frame(width: 24.254, height: 29.677)
                .offset(x: 1.873, y: -1.386)
                .frame(width: 28, height: 28, alignment: .topLeading)
                .clipped()
        } else {
            Image(image)
                .resizable()
                .scaledToFill()
                .frame(width: 28, height: 28)
                .clipped()
        }
    }
}

/// Reversed cubic coordinates from the supplied ring assets, so each fills from the top.
private struct FigmaDeviceSweepShape: Shape {
    let isBodySensor: Bool
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        guard progress > 0 else { return Path() }
        var path = Path()
        path.move(to: CGPoint(x: 17.0001, y: 1.59381))
        if isBodySensor {
            path.addCurve(to: CGPoint(x: 25.9788, y: 4.48072), control1: CGPoint(x: 20.2212, y: 1.59381), control2: CGPoint(x: 23.3613, y: 2.60344))
            path.addCurve(to: CGPoint(x: 31.5926, y: 12.0595), control1: CGPoint(x: 28.5964, y: 6.358), control2: CGPoint(x: 30.5597, y: 9.0085))
            path.addCurve(to: CGPoint(x: 31.7375, y: 21.4899), control1: CGPoint(x: 32.6256, y: 15.1105), control2: CGPoint(x: 32.6762, y: 18.4086))
            path.addCurve(to: CGPoint(x: 26.3592, y: 29.2375), control1: CGPoint(x: 30.7988, y: 24.5712), control2: CGPoint(x: 28.9178, y: 27.2807))
        } else {
            path.addCurve(to: CGPoint(x: 24.5957, y: 3.59636), control1: CGPoint(x: 19.6624, y: 1.59381), control2: CGPoint(x: 22.2794, y: 2.28375))
            path.addCurve(to: CGPoint(x: 30.2167, y: 9.08344), control1: CGPoint(x: 26.912, y: 4.90898), control2: CGPoint(x: 28.8486, y: 6.79945))
            path.addCurve(to: CGPoint(x: 32.4018, y: 16.6286), control1: CGPoint(x: 31.5848, y: 11.3674), control2: CGPoint(x: 32.3376, y: 13.967))
            path.addCurve(to: CGPoint(x: 30.5829, y: 24.2702), control1: CGPoint(x: 32.466, y: 19.2902), control2: CGPoint(x: 31.8393, y: 21.923))
            path.addCurve(to: CGPoint(x: 25.233, y: 30.0219), control1: CGPoint(x: 29.3265, y: 26.6175), control2: CGPoint(x: 27.4833, y: 28.5992))
            path.addCurve(to: CGPoint(x: 17.7427, y: 32.3883), control1: CGPoint(x: 22.9826, y: 31.4446), control2: CGPoint(x: 20.402, y: 32.2599))
            path.addCurve(to: CGPoint(x: 10.0594, y: 30.7542), control1: CGPoint(x: 15.0834, y: 32.5166), control2: CGPoint(x: 12.4363, y: 31.9536))
            path.addCurve(to: CGPoint(x: 4.18044, y: 25.5445), control1: CGPoint(x: 7.68252, y: 29.5548), control2: CGPoint(x: 5.65703, y: 27.7598))
        }
        return path.trimmedPath(from: 0, to: CGFloat(min(1, max(0, progress))))
            .applying(CGAffineTransform(scaleX: rect.width / 34, y: rect.height / 34))
    }
}
