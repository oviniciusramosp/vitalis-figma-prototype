import SwiftUI
import UniformTypeIdentifiers
import UIKit
import os

enum WidgetDragDiagnostics {
    private static let logger = Logger(subsystem: "com.example.vitalisprototype", category: "WidgetGridDrag")

    static func event(_ name: String, source: UUID?, target: String = "") {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--ui-testing") || arguments.contains("--reset-widget-layout") else { return }
        let sourceID = source?.uuidString ?? "pending"
        logger.notice("\(name, privacy: .public) source=\(sourceID, privacy: .public) target=\(target, privacy: .public)")
        #endif
    }
}

struct WidgetColumnSpanKey: LayoutValueKey {
    static let defaultValue = 6
}

/// A single ForEach keeps card identity across row changes during a drag.
struct PrototypeWidgetGrid: Layout {
    var spacing: CGFloat = 12

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = max(0, proposal.width ?? 350)
        let frames = frames(width: width, subviews: subviews)
        return CGSize(width: width, height: frames.map(\.maxY).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = frames(width: bounds.width, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            let frame = frames[index]
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func frames(width: CGFloat, subviews: Subviews) -> [CGRect] {
        var result: [CGRect] = []
        var rowSpan = 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let span = subview[WidgetColumnSpanKey.self]
            if rowSpan + span > 6 {
                y += rowHeight + spacing
                x = 0
                rowSpan = 0
                rowHeight = 0
            }
            let cardWidth: CGFloat
            switch span {
            case 2: cardWidth = max(0, (width - spacing * 2) / 3)
            case 3: cardWidth = max(0, (width - spacing) / 2)
            default: cardWidth = width
            }
            let size = subview.sizeThatFits(ProposedViewSize(width: cardWidth, height: nil))
            result.append(CGRect(x: x, y: y, width: cardWidth, height: size.height))
            rowSpan += span
            rowHeight = max(rowHeight, size.height)
            x += cardWidth + spacing
        }
        return result
    }
}

/// Native drag factories can create and discard probe providers during a reflow.
/// Provider release is balanced by WidgetDragLifecycle, rather than ending the drag itself.
final class WidgetDragItemProvider: NSItemProvider, @unchecked Sendable {
    private let widgetID: UUID
    private let onDragEnd: () -> Void

    init(id: UUID, onDragEnd: @escaping () -> Void) {
        widgetID = id
        self.onDragEnd = onDragEnd
        super.init()
        registerObject(id.uuidString as NSString, visibility: .ownProcess)
    }

    deinit {
        WidgetDragDiagnostics.event("provider-released", source: widgetID)
        let cleanup = onDragEnd
        DispatchQueue.main.async { cleanup() }
    }
}

/// Main-queue reference state deliberately avoids triggering SwiftUI re-renders
/// every time UIKit probes the source factory for another item provider.
final class WidgetDragLifecycle {
    private final class Group {
        let generation = UUID()
        let widgetID: UUID
        let onEnd: () -> Void
        var providerTokens = Set<UUID>()

        init(widgetID: UUID, onEnd: @escaping () -> Void) {
            self.widgetID = widgetID
            self.onEnd = onEnd
        }
    }

    private var group: Group?
    private var pendingCleanup: DispatchWorkItem?

    func makeProvider(
        for widgetID: UUID,
        onBegin: () -> Void,
        onEnd: @escaping () -> Void
    ) -> NSItemProvider {
        pendingCleanup?.cancel()
        pendingCleanup = nil
        let active: Group
        if let current = group, current.widgetID == widgetID {
            active = current
        } else {
            finish()
            active = Group(widgetID: widgetID, onEnd: onEnd)
            group = active
            onBegin()
        }
        let providerToken = UUID()
        let generation = active.generation
        active.providerTokens.insert(providerToken)
        WidgetDragDiagnostics.event("provider-create", source: widgetID, target: "live=\(active.providerTokens.count)")
        return WidgetDragItemProvider(id: widgetID) { [weak self] in
            self?.releaseProvider(providerToken, generation: generation)
        }
    }

    func finish() {
        pendingCleanup?.cancel()
        pendingCleanup = nil
        guard let ending = group else { return }
        group = nil
        ending.onEnd()
    }

    private func releaseProvider(_ token: UUID, generation: UUID) {
        // A late release from an earlier drag must not end a new drag of the same card.
        guard let current = group, current.generation == generation else { return }
        current.providerTokens.remove(token)
        WidgetDragDiagnostics.event("provider-live", source: current.widgetID, target: "live=\(current.providerTokens.count)")
        guard current.providerTokens.isEmpty else { return }
        pendingCleanup?.cancel()
        let cleanup = DispatchWorkItem { [weak self] in
            guard let self, let latest = self.group,
                  latest.generation == generation,
                  latest.providerTokens.isEmpty else { return }
            self.finish()
        }
        pendingCleanup = cleanup
        // Bridge the short gaps between discarded probes and their replacement.
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100), execute: cleanup)
    }
}

struct WidgetEditingMotion: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tilted = false
    let enabled: Bool
    let phase: Bool

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(enabled && !reduceMotion ? (tilted ? 0.65 : -0.65) : 0))
            .task(id: enabled && !reduceMotion) {
                tilted = false
                guard enabled && !reduceMotion else { return }
                if phase { try? await Task.sleep(for: .milliseconds(85)) }
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.16).repeatForever(autoreverses: true)) {
                    tilted = true
                }
            }
    }
}

enum WidgetDropPosition {
    case card(UUID)
    case blast(above: Bool)
    case end(aboveBlast: Bool)

    var key: String {
        switch self {
        case .card(let id): id.uuidString
        case .blast(let above): above ? "before-blast" : "after-blast"
        case .end(let above): above ? "above-grid-end" : "below-grid-end"
        }
    }
}

struct WidgetGridDropDelegate: DropDelegate {
    let position: WidgetDropPosition
    @Binding var layout: PrototypeWidgetLayout
    @Binding var draggedWidgetID: UUID?
    @Binding var lastReorderTarget: String?
    let dragLifecycle: WidgetDragLifecycle
    let reduceMotion: Bool
    let onChange: () -> Void

    func validateDrop(info: DropInfo) -> Bool {
        // Native destinations validate as the lift begins, before the source's
        // SwiftUI state update has necessarily reached this destination.
        WidgetDragDiagnostics.event("validate", source: draggedWidgetID, target: position.key)
        return info.hasItemsConforming(to: [UTType.text])
    }

    private var hasLocalDragSource: Bool {
        draggedWidgetID.map { id in layout.widgets.contains { $0.id == id } } ?? false
    }

    func dropEntered(info: DropInfo) {
        guard hasLocalDragSource,
              let id = draggedWidgetID,
              lastReorderTarget != position.key else { return }
        if case .card(let targetID) = position, id == targetID { return }
        WidgetDragDiagnostics.event("enter", source: id, target: position.key)
        lastReorderTarget = position.key
        let previousItems = layout.items
        withAnimation(reduceMotion ? nil : .spring(duration: 0.26, bounce: 0.06)) {
            switch position {
            case .card(let target): layout.move(id: id, over: target)
            case .blast(let above): layout.move(id: id, aboveBlast: above)
            case .end(let above): layout.moveToEnd(id: id, aboveBlast: above)
            }
        }
        if layout.items != previousItems {
            WidgetDragDiagnostics.event("reorder", source: id, target: position.key)
            UISelectionFeedbackGenerator().selectionChanged()
            onChange()
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        // Keep a supported destination active while the local source propagates.
        guard hasLocalDragSource else { return nil }
        if lastReorderTarget != position.key, position.key != draggedWidgetID?.uuidString {
            WidgetDragDiagnostics.event("update", source: draggedWidgetID, target: position.key)
        }
        // SwiftUI can deliver enter while the source's state update is still propagating.
        // Retry once it is visible; the target key prevents repeated swaps during reflow.
        dropEntered(info: info)
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        // External text drops never alter the local dashboard.
        guard hasLocalDragSource else { return false }
        WidgetDragDiagnostics.event("drop", source: draggedWidgetID, target: position.key)
        dropEntered(info: info)
        dragLifecycle.finish()
        draggedWidgetID = nil
        lastReorderTarget = nil
        onChange()
        return true
    }
}
