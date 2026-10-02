import SwiftUI
import CoreMotion
import QuartzCore

/// Device samples set a target; a display-synchronized filter drives only Metal.
/// `start()` calibrates to the first sample; `stop()` releases sensors and recenters.
@MainActor
final class BackgroundMotion: ObservableObject {
    private(set) var offset: CGSize = .zero
    var onOffsetChange: ((CGSize) -> Void)?
    var maximumFramesPerSecond = 60 {
        didSet { configureCadence() }
    }

    private let manager = CMMotionManager()
    private var referenceAttitude: CMAttitude?
    private var displayLink: CADisplayLink?
    private var displayTarget: BackgroundMotionDisplayTarget?
    private var target: CGSize = .zero
    private var previousTimestamp: TimeInterval?
    private var previewStartedAt: TimeInterval?
    private var isRunning = false

    private static let maximumDisplacement: Double = 10
    private static let fullTiltRadians: Double = 0.28
    private static let smoothingTime: Double = 0.14
    private static let settleDistance: Double = 0.025

    func start() {
        guard !isRunning else { return }
        #if DEBUG && targetEnvironment(simulator)
        let preview = ProcessInfo.processInfo.arguments.contains("--preview-motion")
        #else
        let preview = false
        #endif
        guard preview || manager.isDeviceMotionAvailable else { return }
        isRunning = true
        referenceAttitude = nil
        previousTimestamp = nil
        target = offset
        let proxy = BackgroundMotionDisplayTarget(owner: self)
        let link = CADisplayLink(target: proxy, selector: #selector(BackgroundMotionDisplayTarget.step(_:)))
        displayTarget = proxy
        displayLink = link
        configureCadence()
        link.isPaused = !preview
        link.add(to: .main, forMode: .common)
        if preview {
            previewStartedAt = ProcessInfo.processInfo.systemUptime
            return
        }
        manager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] sample, error in
            MainActor.assumeIsolated {
                guard let self, self.isRunning else { return }
                guard error == nil, let sample else { self.stop(); return }
                self.consume(sample)
            }
        }
    }

    func stop() {
        isRunning = false
        manager.stopDeviceMotionUpdates()
        displayLink?.invalidate()
        displayLink = nil
        displayTarget = nil
        referenceAttitude = nil
        previewStartedAt = nil
        previousTimestamp = nil
        target = .zero
        publish(.zero)
    }

    private func configureCadence() {
        let maximum = Float(max(maximumFramesPerSecond, 1))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(
            minimum: min(60, maximum), maximum: maximum, preferred: maximum
        )
        manager.deviceMotionUpdateInterval = 1.0 / Double(max(maximumFramesPerSecond, 1))
    }

    private func consume(_ sample: CMDeviceMotion) {
        guard let attitude = sample.attitude.copy() as? CMAttitude else { return }
        guard let referenceAttitude else { self.referenceAttitude = attitude; return }
        attitude.multiply(byInverseOf: referenceAttitude)
        let scale = Self.maximumDisplacement / Self.fullTiltRadians
        let next = clamped(x: -attitude.pitch * scale, y: attitude.roll * scale)
        // A subpixel deadband prevents sensor jitter from rendering at rest.
        guard hypot(next.width - target.width, next.height - target.height) > Self.settleDistance else { return }
        target = next
        if displayLink?.isPaused == true {
            previousTimestamp = nil
            displayLink?.isPaused = false
        }
    }

    fileprivate func tick(_ link: CADisplayLink) {
        guard isRunning else { return }
        let now = link.targetTimestamp
        if let previewStartedAt {
            let phase = (ProcessInfo.processInfo.systemUptime - previewStartedAt) * (2 * Double.pi / 5)
            target = clamped(x: sin(phase) * 9, y: cos(phase) * 4)
        }
        let elapsed = min(max(now - (previousTimestamp ?? link.timestamp), 1.0 / 240.0), 0.1)
        previousTimestamp = now
        let alpha = 1 - exp(-elapsed / Self.smoothingTime)
        let next = CGSize(
            width: offset.width + (target.width - offset.width) * alpha,
            height: offset.height + (target.height - offset.height) * alpha
        )
        let distance = hypot(target.width - next.width, target.height - next.height)
        if distance <= Self.settleDistance && previewStartedAt == nil {
            publish(target)
            link.isPaused = true
            previousTimestamp = nil
        } else { publish(next) }
    }

    private func clamped(x: Double, y: Double) -> CGSize {
        guard x.isFinite, y.isFinite else { return target }
        let length = hypot(x, y)
        let factor = length > Self.maximumDisplacement ? Self.maximumDisplacement / length : 1
        return CGSize(width: x * factor, height: y * factor)
    }

    private func publish(_ next: CGSize) {
        guard hypot(next.width - offset.width, next.height - offset.height) > 0.001 else { return }
        offset = next
        // Direct view callback avoids rebuilding SwiftUI at display frequency.
        onOffsetChange?(next)
    }

    deinit {
        manager.stopDeviceMotionUpdates()
        displayLink?.invalidate()
    }
}

@MainActor
private final class BackgroundMotionDisplayTarget: NSObject {
    weak var owner: BackgroundMotion?
    init(owner: BackgroundMotion) { self.owner = owner }
    @objc func step(_ link: CADisplayLink) { owner?.tick(link) }
}
