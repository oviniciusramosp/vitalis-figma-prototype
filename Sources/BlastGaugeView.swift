import SwiftUI

/// All intermediate counter state lives here, keeping the dashboard and charts
/// out of the gauge's short animation and haptic sequence.
struct BlastGaugeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var haptics = BlastHaptics()
    @State private var sweepExposure = 0.0
    @State private var displayedExposure = 0.0
    @State private var showIndicators = false
    @State private var needsInitialSweep = true

    let exposure: Double
    let averageExposure: Double
    let onRefresh: () -> Void
    var onMotionStarted: () -> Void = {}
    var onMotionSettled: () -> Void = {}

    var body: some View {
        Button(action: requestRefresh) {
            ZStack(alignment: .top) {
                animatedArc

                VStack(spacing: 0) {
                    Text("TODAY’S BLAST")
                        .font(PrototypeFont.inter(size: 14, weight: .medium))
                        .tracking(2.1)
                        .frame(height: 29, alignment: .top)

                    Text(displayedExposure.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "en_US"))))
                        .font(PrototypeFont.inter(size: 72))
                        .tracking(-2.88)
                        .contentTransition(.numericText(value: displayedExposure))
                        .frame(height: 87.375)

                    Text("PSI")
                        .font(PrototypeFont.inter(size: 14))
                        .foregroundStyle(PrototypeTheme.muted)
                        .frame(height: 17)
                }
                .frame(width: 239.066, height: 133.375)
                .padding(.top, 66.61)
                .offset(x: 2.11)

                comparisonIndicator
                    .foregroundStyle(comparisonColor)
                    .padding(.top, 127.49)
                    .offset(x: 68.007, y: showIndicators ? 0 : indicatorPush)
                    .opacity(showIndicators ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .frame(width: 250, height: 200)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(PrototypeTheme.foreground)
        .accessibilityIdentifier("blast-gauge")
        .accessibilityLabel("Refresh exposure preview")
        .accessibilityValue(accessibleExposureValue)
        .accessibilityHint("Compares today with the 14-day average, including today. Updates the simulated readings and chart.")
        .task(id: MotionID(exposure: exposure, averageExposure: averageExposure, reduceMotion: reduceMotion, scenePhase: scenePhase)) {
            await animateExposure()
        }
        .onDisappear {
            haptics.stop()
            needsInitialSweep = true
        }
    }

    @MainActor
    private func requestRefresh() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { showIndicators = false }
        haptics.stop()
        onMotionStarted()
        onRefresh()
    }

    private var comparison: ExposureComparison {
        ExposureComparison.compare(exposure: exposure, average: averageExposure)
    }

    private var accessibleExposureValue: String {
        let value = displayedExposure.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "en_US")))
        guard showIndicators else { return "\(value) PSI, updating exposure" }
        let mean = averageExposure.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "en_US")))
        return "\(value) PSI, \(comparisonPhrase) 14-day average \(mean) PSI"
    }

    private var comparisonColor: Color {
        switch comparison {
        case .above: .red
        case .below: PrototypeTheme.success
        case .equal: PrototypeTheme.muted
        }
    }

    private var comparisonPhrase: String {
        switch comparison {
        case .above: "above"
        case .below: "below"
        case .equal: "equal to"
        }
    }

    private var indicatorPush: CGFloat {
        switch comparison {
        case .above: 6
        case .below: -6
        case .equal: 0
        }
    }

    @ViewBuilder
    private var comparisonIndicator: some View {
        if comparison == .equal {
            Image(systemName: "minus")
                .font(.system(size: 18, weight: .medium))
                .frame(width: 24, height: 24)
        } else {
            Image("trend-down")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .rotationEffect(.degrees(comparison == .above ? 180 : 0))
        }
    }

    private var animatedArc: some View {
        ZStack(alignment: .topLeading) {
            Image("gauge-track")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 249.695, height: 193.397)

            FigmaBlastSweepShape(exposure: sweepExposure)
                .stroke(
                    LinearGradient(
                        colors: [PrototypeTheme.foreground, PrototypeTheme.foreground.opacity(0.5)],
                        startPoint: UnitPoint(x: 219.514 / 249.695, y: 46.6689 / 193.397),
                        endPoint: UnitPoint(x: 23.2771 / 249.695, y: 193.846 / 193.397)
                    ),
                    style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round)
                )
                .opacity(sweepExposure > 0 ? 1 : 0)
                .frame(width: 249.695, height: 193.397)
        }
        .frame(width: 250, alignment: .leading)
    }

    @MainActor
    private func animateExposure() async {
        haptics.stop()
        var transaction = Transaction()
        transaction.disablesAnimations = true
        if reduceMotion {
            withTransaction(transaction) {
                sweepExposure = exposure
                displayedExposure = exposure
                showIndicators = true
                needsInitialSweep = false
            }
            onMotionSettled()
            return
        }
        guard scenePhase == .active else {
            needsInitialSweep = true
            return
        }

        onMotionStarted()
        let initialSweep = needsInitialSweep
        withTransaction(transaction) {
            showIndicators = false
            if initialSweep {
                sweepExposure = 0
                displayedExposure = 0
            }
            needsInitialSweep = false
        }
        haptics.prepare()
        do {
            try await Task.sleep(for: .milliseconds(initialSweep ? 120 : 40))
            try Task.checkCancellation()
            let startingValue = displayedExposure
            withAnimation(.easeInOut(duration: 1.3)) {
                sweepExposure = exposure
            }
            try await haptics.animate(from: startingValue, to: exposure, hapticsEnabled: true) { value in
                withAnimation(.easeOut(duration: 0.12)) {
                    displayedExposure = value
                }
            }
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(160))
            try Task.checkCancellation()
        } catch {
            return
        }
        withAnimation(.easeOut(duration: 0.24)) {
            displayedExposure = exposure
            showIndicators = true
        }
        onMotionSettled()
    }

    private struct MotionID: Hashable {
        let exposure: Double
        let averageExposure: Double
        let reduceMotion: Bool
        let scenePhase: ScenePhase
    }
}

/// The original Figma cubic path continued to the track endpoint, with a shared 8 PSI scale.
private struct FigmaBlastSweepShape: Shape {
    var exposure: Double

    var animatableData: Double {
        get { exposure }
        set { exposure = newValue }
    }

    func path(in rect: CGRect) -> Path {
        guard exposure > 0 else { return Path() }

        var path = Path()
        path.move(to: CGPoint(x: 21.791, y: 187.896))
        path.addCurve(to: CGPoint(x: 5.65912, y: 120.88), control1: CGPoint(x: 10.062, y: 167.581), control2: CGPoint(x: 4.4596, y: 144.307))
        path.addCurve(to: CGPoint(x: 28.5515, y: 55.8612), control1: CGPoint(x: 6.85864, y: 97.4524), control2: CGPoint(x: 14.8089, y: 74.8722))
        path.addCurve(to: CGPoint(x: 83.1116, y: 13.7345), control1: CGPoint(x: 42.294, y: 36.8502), control2: CGPoint(x: 61.2422, y: 22.22))
        path.addCurve(to: CGPoint(x: 151.807, y: 8.03699), control1: CGPoint(x: 104.981, y: 5.24892), control2: CGPoint(x: 128.838, y: 3.27025))

        let start = atan2(8.03699 - 127.098, 151.807 - 127.098) * 180 / .pi + 360
        path.addArc(center: CGPoint(x: 127.098, y: 127.098), radius: 121.598, startAngle: .degrees(start), endAngle: .degrees(390), clockwise: false)
        path = path.trimmedPath(from: 0, to: CGFloat(min(1, max(0, exposure / ExposurePreviewSample.maximumPSI))))
        return path.applying(CGAffineTransform(scaleX: rect.width / 249.695, y: rect.height / 193.397))
    }
}
