import Combine
import QuartzCore
import UIKit

/// A short, time-based sequence. Its display link only publishes nine quantized
/// ticks; the gauge sweep itself stays on SwiftUI's native animation engine.
@MainActor
final class BlastHaptics: NSObject, ObservableObject {
    private var displayLink: CADisplayLink?
    private var feedback: UIImpactFeedbackGenerator?
    private var continuation: CheckedContinuation<Void, Error>?
    private var activeID: UUID?
    private var startTime: CFTimeInterval = 0
    private var duration: CFTimeInterval = 1.3
    private var startValue = 0.0
    private var endValue = 0.0
    private var lastTick = 0
    private var allowsHaptics = false
    private var onTick: ((Double) -> Void)?
    private let tickCount = 9
#if DEBUG
    private var requestedRate = 60.0
    private var callbackCount = 0
    private var firstTimestamp: CFTimeInterval?
    private var previousTimestamp: CFTimeInterval?
    private var maxFrameGap: CFTimeInterval = 0
    private var gapsOverBudget = 0
    private var hapticRequests = 0
    private var emittedTicks = 0
#endif

    func prepare() {
        guard UIApplication.shared.applicationState == .active else { return }
        if feedback == nil { feedback = UIImpactFeedbackGenerator(style: .soft) }
        feedback?.prepare()
    }

    func animate(
        from startValue: Double,
        to endValue: Double,
        duration: TimeInterval = 1.3,
        hapticsEnabled: Bool,
        onTick: @escaping (Double) -> Void
    ) async throws {
        try Task.checkCancellation()
        let sequenceID = UUID()

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                let preparedFeedback = self.feedback
                stop()
                self.feedback = preparedFeedback
                self.activeID = sequenceID
                self.continuation = continuation
                self.startValue = startValue
                self.endValue = endValue
                self.duration = max(0.1, duration)
                self.startTime = CACurrentMediaTime()
                self.lastTick = 0
                self.allowsHaptics = hapticsEnabled
                self.onTick = onTick

                if hapticsEnabled { prepare() }
                let link = CADisplayLink(target: self, selector: #selector(advance(_:)))
                let windowScreen = UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .first { $0.activationState == .foregroundActive }?
                    .screen
                let maximumRate = Float(windowScreen?.maximumFramesPerSecond ?? 60)
#if DEBUG
                self.requestedRate = Double(maximumRate)
                self.callbackCount = 0
                self.firstTimestamp = nil
                self.previousTimestamp = nil
                self.maxFrameGap = 0
                self.gapsOverBudget = 0
                self.hapticRequests = 0
                self.emittedTicks = 0
#endif
                link.preferredFrameRateRange = CAFrameRateRange(
                    minimum: min(60, maximumRate),
                    maximum: maximumRate,
                    preferred: maximumRate
                )
                self.displayLink = link
                link.add(to: .main, forMode: .common)
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.stop(sequenceID: sequenceID)
            }
        }
    }

    func stop() {
        stop(sequenceID: nil)
    }

    private func stop(sequenceID: UUID?) {
        if let sequenceID, sequenceID != activeID { return }
#if DEBUG
        if activeID != nil, callbackCount > 0 { logSummary(reason: "cancelled") }
#endif
        displayLink?.invalidate()
        displayLink = nil
        feedback = nil
        allowsHaptics = false
        onTick = nil
        activeID = nil
        let pending = continuation
        continuation = nil
        pending?.resume(throwing: CancellationError())
    }

    @objc
    private func advance(_ link: CADisplayLink) {
        guard UIApplication.shared.applicationState == .active else {
            stop()
            return
        }
#if DEBUG
        callbackCount += 1
        if firstTimestamp == nil { firstTimestamp = link.timestamp }
        if let previousTimestamp {
            let gap = link.timestamp - previousTimestamp
            maxFrameGap = max(maxFrameGap, gap)
            if gap > 1.5 / requestedRate { gapsOverBudget += 1 }
        }
        previousTimestamp = link.timestamp
#endif
        let progress = min(1, max(0, (link.timestamp - startTime) / duration))
        let tick = min(tickCount, Int(progress * Double(tickCount)))
        if tick > lastTick {
            lastTick = tick
#if DEBUG
            emittedTicks += 1
#endif
            let fraction = Double(tick) / Double(tickCount)
            let eased = fraction * fraction * (3 - 2 * fraction)
            let value = (startValue + (endValue - startValue) * eased)
            onTick?((value * 10).rounded() / 10)
            if allowsHaptics {
                feedback?.impactOccurred(intensity: CGFloat(0.2 + 0.45 * fraction))
#if DEBUG
                hapticRequests += 1
#endif
                if tick < tickCount { feedback?.prepare() }
            }
        }
        guard progress >= 1 else { return }
#if DEBUG
        logSummary(reason: "completed")
#endif
        displayLink?.invalidate()
        displayLink = nil
        feedback = nil
        allowsHaptics = false
        onTick = nil
        activeID = nil
        let pending = continuation
        continuation = nil
        pending?.resume()
    }

#if DEBUG
    private func logSummary(reason: String) {
        let observedSpan = max(0.001, (previousTimestamp ?? startTime) - (firstTimestamp ?? startTime))
        let cadence = Double(max(0, callbackCount - 1)) / observedSpan
        print(String(format: "BlastGauge motion %@: targetMax=%.0fHz callbacks=%d cadence=%.1fHz maxGap=%.2fms gapsOver1.5xBudget=%d ticks=%d/9 hapticRequests=%d (display-link cadence only; hardware haptics unverified)", reason, requestedRate, callbackCount, cadence, maxFrameGap * 1000, gapsOverBudget, emittedTicks, hapticRequests))
    }
#endif

    deinit {
        displayLink?.invalidate()
    }
}
