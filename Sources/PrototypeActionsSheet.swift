import SwiftUI

struct PrototypeDashboardScrollState: Equatable {
    enum Zone { case top, middle, bottom }
    let blurProgress: CGFloat
    let zone: Zone

    init(offset: CGFloat, displayScale: CGFloat) {
        let points = (max(0, offset) * displayScale).rounded() / max(1, displayScale)
        blurProgress = min(1, points / 80)
        zone = points >= 96 ? .bottom : points <= 24 ? .top : .middle
    }
}

/// Two resting positions. Only a direct handle drag follows the user's finger.
struct PrototypeActionsSheet: View {
    @Binding var collapsed: Bool
    let height: CGFloat
    let bottomInset: CGFloat
    let onStartTest: () -> Void
    let onReport: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale
    @GestureState(resetTransaction: Transaction(animation: .spring(duration: 0.48, bounce: 0.09)))
    private var dragTranslation: CGFloat = 0

    private var travel: CGFloat { max(0, height - 18) }
    private var position: CGFloat {
        min(travel, max(0, (collapsed ? travel : 0) + dragTranslation))
    }
    private var panelShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 38, topTrailingRadius: 38)
    }

    var body: some View {
        actionRows
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .frame(maxWidth: .infinity, alignment: .top)
            .frame(height: height, alignment: .top)
            .background {
                panelShape
                    .fill(.ultraThinMaterial)
                    .overlay { panelShape.fill(PrototypeTheme.panelTint) }
                    .padding(.bottom, -bottomInset)
            }
            .overlay {
                panelShape
                    .stroke(PrototypeTheme.foreground.opacity(0.24), lineWidth: 0.5)
                    .padding(.bottom, -bottomInset)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .top) { handle }
            .offset(y: position)
            .animation(reduceMotion ? nil : .spring(duration: 0.48, bounce: 0.09), value: collapsed)
            .transaction { transaction in
                if reduceMotion { transaction.animation = nil }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("today-actions-panel")
            .accessibilityValue(collapsed ? "Collapsed" : "Expanded")
    }

    private var handle: some View {
        Button {
            collapsed.toggle()
        } label: {
            Capsule()
                .fill(PrototypeTheme.foreground.opacity(0.3))
                .frame(width: 60, height: 4)
                .frame(width: 112, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .offset(y: -7)
        .highPriorityGesture(
            DragGesture(minimumDistance: 5)
                .updating($dragTranslation) { value, translation, transaction in
                    translation = value.translation.height
                    transaction.animation = nil
                }
                .onEnded { value in
                    let projected = (collapsed ? travel : 0) + value.predictedEndTranslation.height
                    if value.translation.height > 22 {
                        collapsed = true
                    } else if value.translation.height < -22 {
                        collapsed = false
                    } else {
                        collapsed = projected > travel / 2
                    }
                }
        )
        .accessibilityLabel("Actions panel handle")
        .accessibilityIdentifier("actions-panel-handle")
        .accessibilityValue(collapsed ? "Collapsed" : "Expanded")
        .accessibilityHint("Drag or double-tap to expand or collapse the actions")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: collapsed = false
            case .decrement: collapsed = true
            @unknown default: break
            }
        }
    }

    private var actionRows: some View {
        PrototypeActionRows(onStartTest: onStartTest, onReport: onReport)
            .opacity(collapsed && dragTranslation == 0 ? 0 : 1)
            .allowsHitTesting(!collapsed)
            .accessibilityHidden(collapsed)
    }
}

/// Shared contents for the original panel and the native sheet experiment.
struct PrototypeActionRows: View {
    let onStartTest: () -> Void
    let onReport: () -> Void
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image("cognition")
                    .renderingMode(.template)
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
                    .prototypePrimaryAction()
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
                    .prototypeSecondaryAction()
                    .accessibilityLabel("Report how you feel today")
            }
            .padding(.vertical, 12)
        }
        .foregroundStyle(PrototypeTheme.foreground)
    }
}

/// Native backdrop blur fades toward the content, under a separate gray gradient.
struct PrototypeHeaderBackdrop: View {
    let scrollProgress: CGFloat

    var body: some View {
        ZStack {
            PrototypeBackdropBlur(
                progress: 1,
                style: PrototypeTheme.blurStyle
            )
            .opacity(0.55 + 0.45 * scrollProgress)
            .mask {
                LinearGradient(stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.48),
                    .init(color: .black.opacity(0.65), location: 0.73),
                    .init(color: .clear, location: 1)
                ], startPoint: .top, endPoint: .bottom)
            }

            LinearGradient(stops: [
                .init(color: PrototypeTheme.headerGray.opacity(0.86), location: 0),
                .init(color: PrototypeTheme.headerGray.opacity(0.62), location: 0.5),
                .init(color: PrototypeTheme.headerGray.opacity(0.22), location: 0.78),
                .init(color: .clear, location: 1)
            ], startPoint: .top, endPoint: .bottom)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
