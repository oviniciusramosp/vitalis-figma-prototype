import SwiftUI
import UIKit

/// A horizontal chart scrub that lets its ancestor scroll view handle vertical movement.
struct ChartSelectionGesture: UIViewRepresentable {
    let onSelect: (CGFloat, CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.isAccessibilityElement = false
        view.accessibilityElementsHidden = true

        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.selectFromPan(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        pan.cancelsTouchesInView = false
        pan.delegate = context.coordinator

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.selectFromTap(_:)))
        tap.cancelsTouchesInView = false
        tap.delegate = context.coordinator
        tap.require(toFail: pan)

        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onSelect = onSelect
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        for recognizer in uiView.gestureRecognizers ?? [] {
            uiView.removeGestureRecognizer(recognizer)
        }
        coordinator.onSelect = { _, _ in }
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onSelect: (CGFloat, CGFloat) -> Void

        init(onSelect: @escaping (CGFloat, CGFloat) -> Void) {
            self.onSelect = onSelect
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
            let movement = pan.translation(in: pan.view)
            // Fail the vertical pan before the chart can claim a scrolling gesture.
            return abs(movement.x) > abs(movement.y)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        @objc func selectFromTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended else { return }
            select(at: recognizer.location(in: recognizer.view), in: recognizer.view)
        }

        @objc func selectFromPan(_ recognizer: UIPanGestureRecognizer) {
            guard recognizer.state == .began || recognizer.state == .changed || recognizer.state == .ended else { return }
            select(at: recognizer.location(in: recognizer.view), in: recognizer.view)
        }

        private func select(at point: CGPoint, in view: UIView?) {
            guard let view, view.bounds.width > 0 else { return }
            onSelect(point.x, view.bounds.width)
        }
    }
}
