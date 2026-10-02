import SwiftUI

/// All formats use the same local series. These are demonstration readings, not measurements.
private struct WidgetMetricData: Hashable {
    let kind: PrototypeWidgetKind
    let readings: [Double]
    let maximum: Double

    static func metric(_ kind: PrototypeWidgetKind) -> Self {
        switch kind {
        case .cognition:
            Self(kind: kind, readings: [52, 58, 54, 62, 61, 56, 59, 57, 60, 55, 58, 56, 54, 50], maximum: 100)
        case .sleep:
            Self(kind: kind, readings: [420, 435, 450, 415, 430, 425, 440, 420, 435, 450, 410, 430, 415, 390], maximum: 600)
        case .activity:
            Self(kind: kind, readings: [1750, 1600, 1900, 1500, 1850, 1650, 1800, 1550, 1700, 1650, 1600, 1450, 1350, 1200], maximum: 2500)
        case .heart:
            // Heart's current 90 bpm is from the supplied reference; its history is local demo data.
            Self(kind: kind, readings: [86, 88, 84, 92, 85, 87, 89, 83, 91, 86, 88, 87, 85, 90], maximum: 120)
        case .hrv:
            // These physiological readings extend the prototype UX; they are not Figma scores.
            Self(kind: kind, readings: [52, 49, 53, 51, 50, 54, 52, 48, 51, 50, 49, 52, 47, 48], maximum: 80)
        case .respiration:
            Self(kind: kind, readings: [16, 15, 17, 16, 16, 15, 17, 16, 16, 15, 17, 16, 16, 16], maximum: 24)
        case .blastExposure, .healthSummary:
            blast(exposure: ExposurePreviewSample.samples[0].blast)
        }
    }

    static func blast(exposure: Double) -> Self {
        let earlier = Array(ExposurePreviewSample.samples[0].recentReadings.dropLast())
        return Self(kind: .blastExposure, readings: earlier + [exposure], maximum: ExposurePreviewSample.maximumPSI)
    }

    var today: Double { readings.last ?? 0 }
    var chartUnit: String {
        switch kind {
        case .sleep: "minutes"
        case .activity: "steps"
        case .cognition: "score"
        case .heart: "bpm"
        case .hrv: "ms"
        case .respiration: "breaths/min"
        case .blastExposure, .healthSummary: "PSI"
        }
    }

    func average(days: Int) -> Double {
        let window = readings.suffix(days)
        return window.isEmpty ? 0 : window.reduce(0, +) / Double(window.count)
    }

    func comparison(days: Int) -> ExposureComparison {
        ExposureComparison.compare(exposure: today, average: average(days: days))
    }

    func trendColor(for comparison: ExposureComparison) -> Color {
        // Above/below a personal average is a variation, not a clinical interpretation.
        if kind == .heart || kind == .hrv || kind == .respiration {
            return PrototypeTheme.foreground.opacity(0.75)
        }
        return switch comparison {
        case .above: kind == .blastExposure ? .red : PrototypeTheme.success
        case .below: kind == .blastExposure ? PrototypeTheme.success : .red
        case .equal: PrototypeTheme.muted
        }
    }

    func formatted(_ value: Double) -> String {
        switch kind {
        case .sleep:
            let minutes = max(0, Int(value.rounded()))
            return "\(minutes / 60)h\(String(format: "%02d", minutes % 60))"
        case .blastExposure, .healthSummary:
            return value.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "en_US")))
        case .cognition, .activity, .heart, .hrv, .respiration:
            return String(Int(value.rounded()))
        }
    }

    var displayUnit: String? {
        switch kind {
        case .blastExposure: "PSI"
        case .heart: "bpm"
        case .hrv: "ms"
        case .respiration: "/min"
        case .cognition, .sleep, .activity, .healthSummary: nil
        }
    }

    var accessibleValue: String {
        formatted(today) + (displayUnit == nil ? "" : " \(chartUnit)")
    }

    func trendDescription(days: Int, overrideAverage: Double? = nil) -> String {
        let mean = overrideAverage ?? average(days: days)
        let relation: String
        switch ExposureComparison.compare(exposure: today, average: mean) {
        case .above: relation = "above"
        case .below: relation = "below"
        case .equal: relation = "equal to"
        }
        let formattedMean = mean.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "en_US")))
        return "Today's reading is \(relation) the \(days)-day average \(formattedMean) \(chartUnit), including today"
    }
}

/// Callback parameters are retained for dashboard integration; metric cards have no test CTA.
struct PrototypeAuxiliaryWidgetCard: View {
    let kind: PrototypeWidgetKind
    let size: PrototypeWidgetSize
    var onStartTest: () -> Void = {}
    var onShowDevices: () -> Void = {}
    var animateOnAppear: Bool = true

    var body: some View {
        switch kind {
        case .blastExposure:
            BlastExposureCard(animateOnAppear: animateOnAppear, widgetSize: size)
        case .healthSummary:
            HealthSummaryWidgetCard(
                exposure: ExposurePreviewSample.samples[0].blast,
                averageExposure: ExposurePreviewSample.samples[0].average,
                size: size,
                animateOnAppear: animateOnAppear
            )
        case .cognition, .sleep, .activity, .heart, .hrv, .respiration:
            MetricWidgetCard(data: .metric(kind), size: size, animateOnAppear: animateOnAppear)
        }
    }
}

private struct MetricWidgetCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedValue = 0.0
    @State private var animatedReadings = Array(repeating: 0.0, count: 14)
    @State private var hasAppeared = false

    let data: WidgetMetricData
    let size: PrototypeWidgetSize
    var animateOnAppear = true
    var titleOverride: String?
    var identifierOverride: String?
    var averageOverride: Double?

    private var chartDays: Int { size == .small ? 0 : size == .medium ? 7 : 14 }
    private var averageDays: Int { size == .medium ? 7 : 14 }
    private var displayedValue: Double { animateOnAppear ? animatedValue : data.today }
    private var comparison: ExposureComparison {
        ExposureComparison.compare(exposure: data.today, average: size == .medium ? data.average(days: 7) : averageOverride ?? data.average(days: 14))
    }
    private var trendColor: Color { data.trendColor(for: comparison) }

    var body: some View {
        VStack(alignment: .leading, spacing: size == .large ? 8 : 6) {
            WidgetMetricHeader(kind: data.kind, title: titleOverride ?? data.kind.title, size: size)
                .frame(height: size == .large ? 18 : 16, alignment: .leading)
            if size == .small {
                valueColumn
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 64, alignment: .center)
            } else {
                GeometryReader { geometry in
                    HStack(alignment: .bottom, spacing: 6) {
                        valueColumn
                            .frame(width: size == .large ? min(123, geometry.size.width * 0.45) : geometry.size.width * 0.55, alignment: .leading)
                            .frame(maxHeight: .infinity, alignment: .center)
                        WidgetMetricChart(
                            data: data,
                            values: animateOnAppear ? animatedReadings : data.readings,
                            days: chartDays,
                            height: size == .large ? 76 : 64,
                            color: trendColor,
                            reduceMotion: reduceMotion
                        )
                    }
                }
                .frame(height: size == .large ? 76 : 64)
            }
        }
        .padding(size == .large ? 16 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: size.height, alignment: .topLeading)
        .foregroundStyle(PrototypeTheme.foreground)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(PrototypeTheme.foreground.opacity(0.24), lineWidth: 0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifierOverride ?? data.kind.accessibilityIdentifier)
        .accessibilityLabel(titleOverride ?? data.kind.title)
        .accessibilityValue(accessibilityDescription)
        .task(id: MotionInput(data: data, size: size, reduceMotion: reduceMotion, enabled: animateOnAppear)) { await animateData() }
        .onDisappear { hasAppeared = false }
    }

    private var valueColumn: some View {
        VStack(alignment: .leading, spacing: 3) {
            if titleOverride != nil {
                Text("Blast")
                    .font(PrototypeFont.inter(9))
                    .foregroundStyle(PrototypeTheme.muted)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(data.formatted(displayedValue))
                    .font(PrototypeFont.inter(size == .large ? 34 : 31, weight: .medium))
                    .tracking(-1.1)
                    .contentTransition(.numericText(value: displayedValue))
                if let unit = data.displayUnit {
                    Text(unit)
                        .font(PrototypeFont.inter(10))
                        .foregroundStyle(PrototypeTheme.muted)
                }
                WidgetTrendArrow(comparison: comparison, color: trendColor, diameter: 12)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.65)
        }
    }

    private var accessibilityDescription: String {
        let readings = data.readings.suffix(chartDays).map { data.kind == .blastExposure ? $0.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "en_US"))) : String(Int($0)) }.joined(separator: ", ")
        let average = averageDays == 14 ? averageOverride : nil
        return "Widget size: \(size.title). Value: \(data.accessibleValue). Chart days: \(chartDays). Visible readings: \(chartDays). Chart unit: \(data.chartUnit). Chart values: \(readings). \(data.trendDescription(days: averageDays, overrideAverage: average))"
    }

    @MainActor
    private func animateData() async {
        guard animateOnAppear else { return }
        let isEntry = !hasAppeared
        hasAppeared = true
        if reduceMotion || isEntry {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                animatedValue = reduceMotion ? data.today : 0
                animatedReadings = reduceMotion ? data.readings : Array(repeating: 0, count: 14)
            }
        }
        guard !reduceMotion else { return }
        do {
            try await Task.sleep(for: .milliseconds(isEntry ? 220 : 60))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.7)) { animatedValue = data.today }
            animatedReadings = data.readings
        } catch { return }
    }

    private struct MotionInput: Hashable {
        let data: WidgetMetricData
        let size: PrototypeWidgetSize
        let reduceMotion: Bool
        let enabled: Bool
    }
}

private struct WidgetMetricHeader: View {
    let kind: PrototypeWidgetKind
    let title: String
    let size: PrototypeWidgetSize

    var body: some View {
        HStack(spacing: 4) {
            WidgetMetricIcon(kind: kind)
                .frame(width: size == .small ? 12 : 16, height: size == .small ? 12 : 16)
                .accessibilityHidden(true)
            Text(size == .small && title == "Health Overview" ? "HEALTH" : title.uppercased())
                .font(PrototypeFont.inter(size == .small ? 9 : size == .medium ? 11 : 15))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

private struct WidgetMetricIcon: View {
    let kind: PrototypeWidgetKind
    var body: some View {
        Group {
            switch kind {
            case .blastExposure:
                Image("exposure-card-icon").resizable().scaledToFit()
            case .cognition:
                Image("cognition").resizable().scaledToFit()
            case .sleep, .activity, .heart, .hrv, .respiration, .healthSummary:
                Image(systemName: kind.symbol).resizable().scaledToFit()
            }
        }
        .foregroundStyle(PrototypeTheme.foreground)
    }
}

private struct WidgetTrendArrow: View {
    let comparison: ExposureComparison
    let color: Color
    let diameter: CGFloat
    var body: some View {
        Group {
            if comparison == .equal {
                Image(systemName: "minus").font(.system(size: diameter, weight: .semibold))
            } else {
                Image("trend-down")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .rotationEffect(.degrees(comparison == .above ? 180 : 0))
            }
        }
        .frame(width: diameter, height: diameter)
        .foregroundStyle(color)
        .accessibilityHidden(true)
    }
}

private struct WidgetMetricChart: View {
    let data: WidgetMetricData
    let values: [Double]
    let days: Int
    let height: CGFloat
    let color: Color
    let reduceMotion: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: days == 14 ? 4 : 3) {
            ForEach(14 - days..<14, id: \.self) { index in
                let reading = values.indices.contains(index) ? values[index] : 0
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(index == 13 ? color.opacity(0.5) : PrototypeTheme.foreground.opacity(0.2))
                    .frame(maxWidth: .infinity)
                    .frame(height: CGFloat(min(1, max(0, reading / data.maximum))) * height)
                    .frame(height: height, alignment: .bottom)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.65).delay(Double(index - (14 - days)) * 0.045), value: reading)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

struct HealthSummaryWidgetCard: View {
    let exposure: Double
    let averageExposure: Double
    var size: PrototypeWidgetSize = .large
    var animateOnAppear = true

    private var metrics: [WidgetMetricData] {
        [.blast(exposure: exposure), .metric(.sleep), .metric(.cognition), .metric(.activity), .metric(.heart), .metric(.hrv), .metric(.respiration)]
    }

    var body: some View {
        VStack(spacing: 0) {
            if size == .large {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(metrics, id: \.kind) { metric in
                            HealthMetricCircle(data: metric, averageOverride: metric.kind == .blastExposure ? averageExposure : nil, animateOnAppear: animateOnAppear)
                        }
                    }
                    .padding(12)
                }
                .scrollIndicators(.hidden)
                .frame(height: size.height)
                .contentShape(RoundedRectangle(cornerRadius: 16))
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Daily health metrics")
            } else {
                MetricWidgetCard(
                    data: .blast(exposure: exposure),
                    size: size,
                    animateOnAppear: animateOnAppear,
                    titleOverride: "Health Overview",
                    identifierOverride: "health-summary-compact-metric",
                    averageOverride: averageExposure
                )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: size.height)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("health-summary-widget")
        .accessibilityLabel("Health Overview")
        .accessibilityValue(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        let days = size == .medium ? 7 : 0
        let data = WidgetMetricData.blast(exposure: exposure)
        let values = data.readings.suffix(days).map { $0.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "en_US"))) }.joined(separator: ", ")
        let summary = size == .large
            ? metrics.map { "\($0.kind == .blastExposure ? "Blast" : $0.kind.title): \($0.accessibleValue)." }.joined(separator: " ")
            : "Blast: \(data.accessibleValue)."
        return "Widget size: \(size.title). \(summary) Chart days: \(days). Visible readings: \(days). Chart values: \(values). Simulated data"
    }
}

private struct HealthMetricCircle: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedValue = 0.0
    @State private var hasAppeared = false
    let data: WidgetMetricData
    let averageOverride: Double?
    let animateOnAppear: Bool

    private var value: Double { animateOnAppear ? animatedValue : data.today }
    private var comparison: ExposureComparison {
        ExposureComparison.compare(exposure: data.today, average: averageOverride ?? data.average(days: 14))
    }
    private var color: Color { data.trendColor(for: comparison) }
    private var itemID: String {
        switch data.kind {
        case .blastExposure: "blast"
        default: data.kind.rawValue
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            VStack(spacing: 5) {
                WidgetMetricIcon(kind: data.kind)
                    .frame(width: 17, height: 17)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(data.formatted(value))
                        .font(PrototypeFont.inter(data.kind == .sleep || data.kind == .activity ? 20 : 24, weight: .medium))
                        .tracking(-0.7)
                        .contentTransition(.numericText(value: value))
                    WidgetTrendArrow(comparison: comparison, color: color, diameter: 10)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                if data.displayUnit != nil {
                    Text(data.chartUnit).font(PrototypeFont.inter(8)).foregroundStyle(PrototypeTheme.muted)
                }
            }
            .padding(7)
            .frame(width: 80, height: 80)
            .background {
                Circle().fill(LinearGradient(colors: [Color.white.opacity(0.12), Color.black.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .overlay { Circle().stroke(PrototypeTheme.foreground.opacity(0.24), lineWidth: 0.5) }
            Text(data.kind == .blastExposure ? "Blast" : data.kind.title)
                .font(PrototypeFont.inter(12, weight: .medium))
                .frame(height: 17)
        }
        .frame(width: 80)
        .foregroundStyle(PrototypeTheme.foreground)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("health-summary-\(itemID)")
        .accessibilityLabel(data.kind == .blastExposure ? "Blast" : data.kind.title)
        .accessibilityValue("\(data.accessibleValue). \(data.trendDescription(days: 14, overrideAverage: averageOverride)). Simulated reading")
        .task(id: MotionInput(value: data.today, reduceMotion: reduceMotion, enabled: animateOnAppear)) { await animateValue() }
        .onDisappear { hasAppeared = false }
    }

    @MainActor
    private func animateValue() async {
        guard animateOnAppear else { return }
        let entry = !hasAppeared
        hasAppeared = true
        if reduceMotion || entry {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { animatedValue = reduceMotion ? data.today : 0 }
        }
        guard !reduceMotion else { return }
        do {
            try await Task.sleep(for: .milliseconds(entry ? 220 : 60))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.7)) { animatedValue = data.today }
        } catch { return }
    }

    private struct MotionInput: Hashable {
        let value: Double
        let reduceMotion: Bool
        let enabled: Bool
    }
}
