import SwiftUI

/// Shared foundations used by the dashboard and its live component catalog.
enum PrototypeStyle {
    static let spacing: [CGFloat] = [4, 8, 12, 16, 20, 24, 32, 48]
    static let gridGap: CGFloat = 12
    static let cardRadius: CGFloat = 16
    static let cardBorderWidth: CGFloat = 0.5
    static let cardBorderOpacity = 0.24

    static func cardPadding(for size: PrototypeWidgetSize) -> CGFloat {
        size == .large ? 16 : 12
    }
}

struct PrototypeWidgetSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(PrototypeTheme.foreground)
            .background(PrototypeTheme.surface, in: RoundedRectangle(cornerRadius: PrototypeStyle.cardRadius))
            .overlay {
                RoundedRectangle(cornerRadius: PrototypeStyle.cardRadius)
                    .stroke(PrototypeTheme.foreground.opacity(PrototypeStyle.cardBorderOpacity),
                            lineWidth: PrototypeStyle.cardBorderWidth)
            }
    }
}

extension View {
    func prototypeWidgetSurface() -> some View {
        modifier(PrototypeWidgetSurface())
    }

    func prototypePrimaryAction() -> some View {
        labelStyle(.titleAndIcon)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
            .tint(PrototypeTheme.success)
    }

    func prototypeSecondaryAction() -> some View {
        font(PrototypeFont.inter(15, weight: .medium))
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
            .tint(PrototypeTheme.success)
            .foregroundStyle(PrototypeTheme.success)
            .frame(minHeight: 30)
    }
}

/// A living reference: previews instantiate the same views used on Today.
struct PrototypeDesignSystemView: View {
    @State private var appearance = PrototypeAppearance.shared
    @State private var previewMessage = "Try a control to preview its feedback."
    @State private var replay = 0
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let sample = ExposurePreviewSample.samples[0]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                introduction
                colors
                typography
                spacingAndShapes
                controls
                widgets
                motion
                Text("Living reference · Prototype 1.0\nSample readings. Components evolve with the app.")
                    .font(PrototypeFont.inter(12))
                    .foregroundStyle(PrototypeTheme.muted)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .background { PrototypeBackground() }
        .foregroundStyle(PrototypeTheme.foreground)
        .navigationTitle("Design System")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .tint(PrototypeTheme.success)
        .accessibilityIdentifier("design-system-screen")
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("FOUNDATIONS & COMPONENTS", systemImage: "square.stack.3d.up")
                .font(PrototypeFont.inter(11, weight: .medium))
                .tracking(1)
                .foregroundStyle(PrototypeTheme.success)
            Text("Built to feel alive.")
                .font(PrototypeFont.inter(28, weight: .medium))
                .tracking(-0.7)
            Text("A shared language for surfaces, data and motion. These are the same styles and components you see on Today.")
                .font(PrototypeFont.inter(15))
                .foregroundStyle(PrototypeTheme.muted)
            Picker("Appearance", selection: $appearance.selection) {
                ForEach(PrototypeThemeChoice.allCases) { theme in
                    Text(theme.title).tag(theme)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("design-system-theme-picker")
            Text("Appearance is shared across the app and saved on this device.")
                .font(PrototypeFont.inter(12))
                .foregroundStyle(PrototypeTheme.muted)
        }
    }

    private var colors: some View {
        PrototypeCatalogSection(title: "Colors", subtitle: "Semantic tokens · \(appearance.selection.title) theme") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                swatch("Canvas", token: "background", color: PrototypeTheme.background, detail: canvasValue)
                swatch("Text", token: "foreground", color: PrototypeTheme.foreground, detail: appearance.selection == .light ? "#1F1F1F" : "#FFFFFF")
                swatch("Secondary", token: "muted", color: PrototypeTheme.muted, detail: appearance.selection == .light ? "Text · 65%" : "Text · 55%")
                swatch("Widget", token: "surface", color: PrototypeTheme.surface, detail: surfaceValue)
                swatch("Exposure", token: "accent", color: PrototypeTheme.accent, detail: "#FF8D28")
                swatch("Action", token: "success", color: PrototypeTheme.success, detail: "#34C759")
                swatch("Attention", token: "Color.red", color: .red, detail: "System red")
                swatch("Sync", token: "Color.blue", color: .blue, detail: "System blue")
            }
            Text("Canvas is the base tone. The shared Metal background adds the gradient, grain and subtle tilt response.")
                .font(PrototypeFont.inter(12))
                .foregroundStyle(PrototypeTheme.muted)
        }
    }

    private func swatch(_ title: String, token: String, color: Color, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(height: 40)
                .overlay { RoundedRectangle(cornerRadius: 8).stroke(PrototypeTheme.foreground.opacity(0.2), lineWidth: 0.5) }
                .accessibilityHidden(true)
            Text(title).font(PrototypeFont.inter(14, weight: .medium))
            Text(token).font(.system(size: 11, design: .monospaced))
            Text(detail).font(PrototypeFont.inter(11)).foregroundStyle(PrototypeTheme.muted)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PrototypeTheme.listRow, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private var canvasValue: String {
        switch appearance.selection {
        case .gray: "#575754"
        case .dark: "#1F1F1F"
        case .light: "#DBDBD9"
        }
    }

    private var surfaceValue: String {
        switch appearance.selection {
        case .gray: "Black · 25%"
        case .dark: "White · 5.5%"
        case .light: "White · 48%"
        }
    }

    private var typography: some View {
        PrototypeCatalogSection(title: "Typography", subtitle: "Inter · native navigation uses the system font") {
            VStack(alignment: .leading, spacing: 18) {
                typeSample("Section title", sample: "Your daily overview", size: 24, weight: .medium)
                typeSample("Body", sample: "Complete your tests", size: 15, weight: .regular)
                typeSample("Caption", sample: "14-day avg", size: 12, weight: .regular)
                typeSample("Widget value", sample: "7.2", size: 34, weight: .medium, tracking: -1.1)
                Text("TODAY’S BLAST")
                    .font(PrototypeFont.inter(14, weight: .medium))
                    .tracking(2.1)
                Text("Gauge label · 14 pt / Medium / tracking +2.1")
                    .font(PrototypeFont.inter(11))
                    .foregroundStyle(PrototypeTheme.muted)
            }
        }
    }

    private func typeSample(_ title: String, sample: String, size: CGFloat, weight: Font.Weight, tracking: CGFloat = 0) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(sample).font(PrototypeFont.inter(size, weight: weight)).tracking(tracking)
            Text("\(title) · \(Int(size)) pt / \(weight == .medium ? "Medium" : "Regular")")
                .font(PrototypeFont.inter(11))
                .foregroundStyle(PrototypeTheme.muted)
        }
    }

    private var spacingAndShapes: some View {
        PrototypeCatalogSection(title: "Spacing & shapes", subtitle: "Points, soft corners and quiet borders") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(PrototypeStyle.spacing, id: \.self) { space in
                    HStack(spacing: 16) {
                        Text("\(Int(space)) pt").font(.system(size: 12, design: .monospaced)).frame(width: 42, alignment: .leading)
                        Capsule().fill(PrototypeTheme.success.opacity(0.65)).frame(width: space * 3, height: 6)
                    }
                }
                Rectangle().fill(PrototypeTheme.foreground.opacity(0.28)).frame(height: 1 / max(1, displayScale))
                Text("Hairline · 1 physical pixel")
                    .font(PrototypeFont.inter(12)).foregroundStyle(PrototypeTheme.muted)
                Text("Widget radius 16 pt · border 0.5 pt\nGrid gap 12 pt · inner padding 16 / 12 pt")
                    .font(PrototypeFont.inter(13))
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .prototypeWidgetSurface()
            }
        }
    }

    private var controls: some View {
        PrototypeCatalogSection(title: "Controls", subtitle: "Native interactions with shared action styles") {
            HStack(spacing: 12) {
                Button("Start", systemImage: "play.fill") { previewMessage = "Primary action previewed." }
                    .prototypePrimaryAction()
                    .accessibilityIdentifier("design-system-primary-action")
                Button("Report Now") { previewMessage = "Secondary action previewed." }
                    .prototypeSecondaryAction()
            }
            Button(role: .destructive) { previewMessage = "Destructive action previewed. No widget was removed." } label: {
                Label("Remove Widget", systemImage: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44)
            Text(previewMessage)
                .font(PrototypeFont.inter(12))
                .foregroundStyle(PrototypeTheme.muted)
                .accessibilityIdentifier("design-system-control-feedback")
        }
    }

    private var widgets: some View {
        PrototypeCatalogSection(title: "Widgets", subtitle: "A six-column grid · the actual dashboard components") {
            widgetCaption("Large", detail: "Full row · 14 days")
            BlastExposureCard(animateOnAppear: true)
            widgetCaption("Medium", detail: "Half row · 7 days")
            HStack(spacing: PrototypeStyle.gridGap) {
                PrototypeAuxiliaryWidgetCard(kind: .cognition, size: .medium)
                PrototypeAuxiliaryWidgetCard(kind: .sleep, size: .medium)
            }
            widgetCaption("Small", detail: "One third · value and trend")
            HStack(spacing: PrototypeStyle.gridGap) {
                PrototypeAuxiliaryWidgetCard(kind: .activity, size: .small)
                PrototypeAuxiliaryWidgetCard(kind: .heart, size: .small)
                PrototypeAuxiliaryWidgetCard(kind: .hrv, size: .small)
            }
            widgetCaption("Health Overview", detail: "Large · horizontal carousel")
            HealthSummaryWidgetCard(exposure: sample.blast, averageExposure: sample.average)
            Text("Touch or drag across Blast Exposure to highlight a column. Carousel metrics scroll horizontally.")
                .font(PrototypeFont.inter(12))
                .foregroundStyle(PrototypeTheme.muted)
        }
    }

    private func widgetCaption(_ title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(PrototypeFont.inter(13, weight: .medium))
            Spacer()
            Text(detail).font(PrototypeFont.inter(11)).foregroundStyle(PrototypeTheme.muted)
        }
        .padding(.top, 4)
    }

    private var motion: some View {
        PrototypeCatalogSection(title: "Motion", subtitle: "Gauge sweep → numeric morph → trend reveal") {
            BlastGaugeView(exposure: sample.blast, averageExposure: sample.average, onRefresh: { replay += 1 })
                .id(replay)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            Button("Replay motion", systemImage: "arrow.clockwise") { replay += 1 }
                .prototypeSecondaryAction()
                .accessibilityIdentifier("replay-design-system-motion")
            Text(reduceMotion ? "Reduce Motion is on. Values appear directly; parallax and entrance motion are disabled." : "A gentle sweep with haptic ticks on supported iPhones. The trend follows the final number. Enable Reduce Motion in iOS to preview the static alternative.")
                .font(PrototypeFont.inter(12))
                .foregroundStyle(PrototypeTheme.muted)
        }
    }
}

private struct PrototypeCatalogSection<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(PrototypeFont.inter(22, weight: .medium)).accessibilityAddTraits(.isHeader)
                Text(subtitle).font(PrototypeFont.inter(12)).foregroundStyle(PrototypeTheme.muted)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
