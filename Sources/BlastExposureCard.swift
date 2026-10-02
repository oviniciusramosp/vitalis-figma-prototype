import SwiftUI

struct BlastExposureCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedAverage = 0.0
    @State private var animatedToday = 0.0
    @State private var animatedHeights = Array(repeating: 0.0, count: 14)
    @State private var selectedDay: Int?
    @State private var hasAppeared = false

    let averageExposure: Double
    let historyHeights: [Double]
    let animateOnAppear: Bool
    let widgetSize: PrototypeWidgetSize

    init(
        averageExposure: Double = ExposurePreviewSample.samples[0].average,
        historyHeights: [Double] = ExposurePreviewSample.samples[0].history,
        animateOnAppear: Bool = true,
        widgetSize: PrototypeWidgetSize = .large
    ) {
        self.averageExposure = averageExposure
        self.historyHeights = historyHeights
        self.animateOnAppear = animateOnAppear
        self.widgetSize = widgetSize
    }

    private var chartDays: Int { widgetSize == .small ? 0 : widgetSize == .medium ? 7 : 14 }
    private var averageDays: Int { widgetSize == .medium ? 7 : 14 }
    private var chartHeight: CGFloat { widgetSize == .large ? 76 : 64 }
    private var normalizedHeights: [Double] {
        let recent = Array(historyHeights.suffix(14)).map { $0.isFinite ? max(0, $0) : 0 }
        return Array(repeating: 0, count: max(0, 14 - recent.count)) + recent
    }
    private var readings: [Double] {
        normalizedHeights.map { $0 / ExposurePreviewSample.chartHeight * ExposurePreviewSample.maximumPSI }
    }
    private var todayExposure: Double { readings.last ?? 0 }
    private var rangeAverage: Double {
        guard widgetSize == .medium else { return averageExposure }
        let week = readings.suffix(7)
        return week.reduce(0, +) / Double(week.count)
    }
    private var displayedAverage: Double { animateOnAppear ? animatedAverage : rangeAverage }
    private var displayedToday: Double { animateOnAppear ? animatedToday : todayExposure }
    private var history: [ExposureDay] {
        let heights = animateOnAppear ? animatedHeights : normalizedHeights
        return (14 - chartDays..<14).map { ExposureDay(id: $0, height: heights[$0]) }
    }
    private var selectedExposure: ExposureDay? {
        guard let selectedDay else { return nil }
        return history.first { $0.id == selectedDay }
    }
    private var latestComparison: ExposureComparison {
        ExposureComparison.compare(exposure: todayExposure, average: rangeAverage)
    }
    private var latestComparisonColor: Color {
        switch latestComparison {
        case .above: .red
        case .below: PrototypeTheme.success
        case .equal: PrototypeTheme.muted
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: widgetSize == .large ? 8 : 6) {
            HStack(spacing: 4) {
                Image("exposure-card-icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: widgetSize == .small ? 12 : 16, height: widgetSize == .small ? 12 : 16)
                    .accessibilityHidden(true)
                Text("BLAST EXPOSURE")
                    .font(PrototypeFont.inter(widgetSize == .small ? 9 : widgetSize == .medium ? 11 : 15))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(height: widgetSize == .large ? 18 : 16, alignment: .leading)

            if widgetSize == .small {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    numberValue(displayedToday, fontSize: 31, unitSize: 10)
                    comparisonArrow
                }
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(height: 64, alignment: .center)
            } else {
                GeometryReader { geometry in
                    HStack(alignment: .bottom, spacing: widgetSize == .large ? 0 : 6) {
                        average
                            .frame(width: widgetSize == .large ? min(123, geometry.size.width * 0.45) : geometry.size.width * 0.45, alignment: .leading)
                        historyChart
                            .frame(maxWidth: .infinity)
                    }
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(PrototypeTheme.accent)
                            .frame(height: 2)
                            .offset(y: averageLineY(for: displayedAverage) - 1)
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.7), value: displayedAverage)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .frame(height: chartHeight)
            }
        }
        .padding(widgetSize == .large ? 16 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: widgetSize.height, alignment: .topLeading)
        .foregroundStyle(PrototypeTheme.foreground)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(PrototypeTheme.foreground.opacity(0.24), lineWidth: 0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("blast-exposure-card")
        .accessibilityLabel("Blast Exposure")
        .accessibilityValue(accessibilityDescription)
        .task(id: animationInput) { await animateData() }
        .onDisappear { hasAppeared = false }
    }

    private var average: some View {
        GeometryReader { _ in
            let labelHeight: CGFloat = widgetSize == .large ? 18 : 12
            VStack(alignment: .leading, spacing: 10) {
                Text("Average Exposure")
                    .font(PrototypeFont.inter(widgetSize == .large ? 10 : 9))
                    .foregroundStyle(PrototypeTheme.foreground.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(height: labelHeight, alignment: .topLeading)
                numberValue(displayedAverage, fontSize: widgetSize == .large ? 34 : 28, unitSize: widgetSize == .large ? 14 : 10)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(height: widgetSize == .large ? 41.25 : 34, alignment: .leading)
            }
            .offset(y: averageLineY(for: rangeAverage) - labelHeight - 5)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.7), value: rangeAverage)
        }
        .frame(height: chartHeight)
    }

    private func averageLineY(for value: Double) -> CGFloat {
        chartHeight * CGFloat(1 - min(ExposurePreviewSample.maximumPSI, max(0, value)) / ExposurePreviewSample.maximumPSI)
    }

    private func numberValue(_ value: Double, fontSize: CGFloat, unitSize: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(psi(value))
                .font(PrototypeFont.inter(fontSize, weight: .medium))
                .tracking(-1.1)
                .contentTransition(.numericText(value: value))
            Text("PSI")
                .font(PrototypeFont.inter(unitSize))
                .foregroundStyle(PrototypeTheme.muted)
        }
    }

    private var comparisonArrow: some View {
        Group {
            if latestComparison == .equal {
                Image(systemName: "minus").font(.system(size: 11, weight: .semibold))
            } else {
                Image("trend-down")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 12)
                    .rotationEffect(.degrees(latestComparison == .above ? 180 : 0))
            }
        }
        .foregroundStyle(latestComparisonColor)
        .accessibilityHidden(true)
    }

    private var historyChart: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: widgetSize == .large ? 4 : 3) {
                ForEach(history) { day in
                    let isSelected = selectedDay == day.id
                    let tint = day.isToday ? latestComparisonColor : PrototypeTheme.foreground
                    RoundedRectangle(cornerRadius: 3)
                        .fill(tint.opacity(isSelected ? 0.95 : day.isToday ? 0.5 : 0.2))
                        .frame(maxWidth: .infinity)
                        .frame(height: min(chartHeight, max(0, day.height) / ExposurePreviewSample.chartHeight * chartHeight))
                        .overlay(alignment: .bottom) {
                            Text(day.label)
                                .font(PrototypeFont.inter(8))
                                .foregroundStyle(isSelected ? Color.black.opacity(0.65) : day.isToday ? latestComparisonColor : PrototypeTheme.foreground.opacity(0.6))
                                .frame(height: 12.485)
                                .accessibilityHidden(true)
                        }
                        .clipped()
                        .shadow(color: tint.opacity(isSelected ? 0.35 : 0), radius: 4)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: isSelected)
                        .frame(height: chartHeight, alignment: .bottom)
                        .animation(reduceMotion ? nil : .spring(duration: 0.72, bounce: 0.08).delay(Double(day.id - (14 - chartDays)) * 0.045), value: day.height)
                        .accessibilityLabel("\(day.longName), \(day.id < 7 ? "previous week" : "this week")")
                        .accessibilityValue("\(psi(readings[day.id])) PSI, simulated reading")
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    selectDay(at: location.x, width: geometry.size.width)
                case .ended:
                    selectedDay = nil
                }
            }
            .overlay {
                ChartSelectionGesture { x, width in
                    selectDay(at: x, width: width)
                }
                .accessibilityHidden(true)
            }
            .overlay(alignment: .topTrailing) {
                if let selectedExposure {
                    Text("\(selectedExposure.label) · \(psi(readings[selectedExposure.id])) PSI")
                        .font(PrototypeFont.inter(9, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.regularMaterial, in: Capsule())
                        .offset(y: -18)
                }
            }
        }
        .accessibilityLabel("Exposure history over the last \(chartDays) days")
        .accessibilityValue(historyTrendDescription)
    }

    private func selectDay(at x: CGFloat, width: CGFloat) {
        guard chartDays > 0, width > 0 else { return }
        let spacing: CGFloat = widgetSize == .large ? 4 : 3
        let columnStride = (width + spacing) / CGFloat(chartDays)
        let index = min(chartDays - 1, max(0, Int((x + spacing / 2) / columnStride)))
        let day = 14 - chartDays + index
        guard selectedDay != day else { return }
        selectedDay = day
    }

    private var historyTrendDescription: String {
        let relation: String
        switch latestComparison {
        case .above: relation = "above"
        case .below: relation = "below"
        case .equal: relation = "equal to"
        }
        return "Today's reading is \(relation) the \(averageDays)-day average, including today"
    }

    private var accessibilityDescription: String {
        let values = readings.suffix(chartDays).map(psi).joined(separator: ", ")
        let selected = selectedExposure.map { "Selected reading, \(psi(readings[$0.id])) PSI" } ?? "No day selected"
        return "Widget size: \(widgetSize.title). \(averageDays)-day average: \(psi(rangeAverage)) PSI. Today: \(psi(todayExposure)) PSI. Chart days: \(chartDays). Visible readings: \(chartDays). Chart values: \(values). \(historyTrendDescription). \(selected)"
    }

    private func psi(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "en_US")))
    }

    @MainActor
    private func animateData() async {
        if chartDays == 0 || !(14 - chartDays..<14).contains(selectedDay ?? -1) { selectedDay = nil }
        guard animateOnAppear else { return }
        let isEntry = !hasAppeared
        hasAppeared = true
        if reduceMotion || isEntry {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                animatedAverage = reduceMotion ? rangeAverage : 0
                animatedToday = reduceMotion ? todayExposure : 0
                animatedHeights = reduceMotion ? normalizedHeights : Array(repeating: 0, count: 14)
            }
        }
        guard !reduceMotion else { return }
        do {
            try await Task.sleep(for: .milliseconds(isEntry ? 260 : 60))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.7)) {
                animatedAverage = rangeAverage
                animatedToday = todayExposure
            }
            // Each native bar receives a compositor delay; no frame-by-frame chart work.
            animatedHeights = normalizedHeights
        } catch { return }
    }

    private var animationInput: AnimationInput {
        AnimationInput(average: rangeAverage, heights: historyHeights, size: widgetSize, reduceMotion: reduceMotion, enabled: animateOnAppear)
    }
    private struct AnimationInput: Hashable {
        let average: Double
        let heights: [Double]
        let size: PrototypeWidgetSize
        let reduceMotion: Bool
        let enabled: Bool
    }
}

private struct ExposureDay: Identifiable {
    let id: Int
    let height: Double
    var label: String { ["M", "T", "W", "T", "F", "S", "S"][id % 7] }
    var isToday: Bool { id == 13 }
    var longName: String { ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][id % 7] }
}
