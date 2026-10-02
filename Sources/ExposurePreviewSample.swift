/// Comparison uses the same one-decimal precision visible in the prototype.
enum ExposureComparison: String {
    case above, below, equal

    static func compare(exposure: Double, average: Double) -> ExposureComparison {
        let displayedExposure = (exposure * 10).rounded()
        let displayedAverage = (average * 10).rounded()
        if displayedExposure > displayedAverage { return .above }
        if displayedExposure < displayedAverage { return .below }
        return .equal
    }
}

/// Local, simulated readings shared by the dashboard and its exposure chart.
struct ExposurePreviewSample {
    static let maximumPSI = 8.0
    static let chartHeight = 76.0
    static let demoPromptThresholdPSI = 4.0

    let readings: [Double]

    var blast: Double { readings.last ?? 0 }
    var recentReadings: [Double] { Array(readings.suffix(14)) }
    var comparison: ExposureComparison {
        ExposureComparison.compare(exposure: blast, average: average)
    }
    var average: Double {
        let window = recentReadings
        guard !window.isEmpty else { return 0 }
        return window.reduce(0, +) / Double(window.count)
    }
    var history: [Double] {
        recentReadings.map { $0 / Self.maximumPSI * Self.chartHeight }
    }

    private static let precedingReadings: [Double] = [
        4.2, 4.8, 3.6, 5.5, 4.1, 6.0, 3.8, 5.0, 6.8, 4.7, 5.6, 6.2, 7.8
    ]

    // Only today's value changes; the previous thirteen days remain consistent.
    // The rolling fourteen-day average includes the latest (today's) reading.
    static let samples = [7.2, 3.2, 8.0].map {
        ExposurePreviewSample(readings: precedingReadings + [$0])
    }
}
