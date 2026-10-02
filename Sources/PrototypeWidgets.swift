import SwiftUI

enum PrototypeWidgetSize: String, CaseIterable, Identifiable, Hashable, Codable {
    case small
    case medium
    case large

    var id: Self { self }
    var title: String { rawValue.capitalized }
    var height: CGFloat { self == .large ? 134 : 110 }
    var symbol: String { "widget.\(rawValue)" }
    var columnSpan: Int {
        switch self {
        case .small: 2
        case .medium: 3
        case .large: 6
        }
    }

    func width(in availableWidth: CGFloat, spacing: CGFloat = 12) -> CGFloat {
        switch self {
        case .small: max(0, (availableWidth - spacing * 2) / 3)
        case .medium: max(0, (availableWidth - spacing) / 2)
        case .large: max(0, availableWidth)
        }
    }
}

enum PrototypeWidgetKind: String, CaseIterable, Identifiable, Hashable, Codable {
    case blastExposure
    case cognition
    case sleep
    case activity
    case heart
    case hrv
    case respiration
    case healthSummary

    var id: Self { self }

    var title: String {
        switch self {
        case .blastExposure: "Blast Exposure"
        case .cognition: "Cognition"
        case .sleep: "Sleep"
        case .activity: "Activity"
        case .heart: "Heart"
        case .hrv: "HRV"
        case .respiration: "Respiration"
        case .healthSummary: "Health Overview"
        }
    }

    var symbol: String {
        switch self {
        case .blastExposure: "dot.radiowaves.left.and.right"
        case .cognition: "brain.head.profile"
        case .sleep: "moon"
        case .activity: "flame"
        case .heart: "heart"
        case .hrv: "waveform.path.ecg"
        case .respiration: "lungs"
        case .healthSummary: "heart.text.clipboard"
        }
    }

    var subtitle: String {
        switch self {
        case .blastExposure: "Recent readings and average exposure"
        case .cognition: "Your simulated cognitive score and recent history"
        case .sleep: "Sleep duration and your recent sleep pattern"
        case .activity: "Today's activity and recent daily readings"
        case .heart: "Heart rate in beats per minute and recent history"
        case .hrv: "Simulated heart rate variability in milliseconds"
        case .respiration: "Simulated breaths per minute and recent history"
        case .healthSummary: "A horizontal overview of your daily metrics"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .blastExposure: "blast-exposure-card"
        case .cognition: "cognition-widget"
        case .sleep: "sleep-widget"
        case .activity: "activity-widget"
        case .heart: "heart-widget"
        case .hrv: "hrv-widget"
        case .respiration: "respiration-widget"
        case .healthSummary: "health-summary-widget"
        }
    }
}

struct PrototypeWidget: Identifiable, Equatable, Codable {
    let id: UUID
    var kind: PrototypeWidgetKind
    var size: PrototypeWidgetSize

    init(id: UUID = UUID(), kind: PrototypeWidgetKind, size: PrototypeWidgetSize = .large) {
        self.id = id
        self.kind = kind
        self.size = size
    }
}

struct WidgetGalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedKind: PrototypeWidgetKind
    @State private var selectedSize: PrototypeWidgetSize

    let onAdd: (PrototypeWidgetKind, PrototypeWidgetSize) -> Void

    init(
        initialKind: PrototypeWidgetKind = .blastExposure,
        initialSize: PrototypeWidgetSize = .large,
        onAdd: @escaping (PrototypeWidgetKind, PrototypeWidgetSize) -> Void
    ) {
        _selectedKind = State(initialValue: initialKind)
        _selectedSize = State(initialValue: initialSize)
        self.onAdd = onAdd
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Available widgets") {
                    ForEach(PrototypeWidgetKind.allCases) { kind in
                        Button {
                            withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) {
                                selectedKind = kind
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: kind.symbol)
                                    .font(.system(size: 20))
                                    .foregroundStyle(PrototypeTheme.success)
                                    .frame(width: 26)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(kind.title)
                                        .font(PrototypeFont.inter(15, weight: .medium))
                                        .foregroundStyle(PrototypeTheme.foreground)
                                    Text(kind.subtitle)
                                        .font(PrototypeFont.inter(11))
                                        .foregroundStyle(PrototypeTheme.muted)
                                }

                                Spacer(minLength: 4)

                                if selectedKind == kind {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(PrototypeTheme.success)
                                        .accessibilityHidden(true)
                                }
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(kind.title)
                        .accessibilityAddTraits(selectedKind == kind ? .isSelected : [])
                        .accessibilityIdentifier("widget-kind-\(kind.rawValue)")
                    }
                }
                .listRowBackground(Color.white.opacity(0.045))

                Section {
                    Picker("Widget size", selection: $selectedSize) {
                        ForEach(PrototypeWidgetSize.allCases) { size in
                            Text(size.title).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("widget-size-picker")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 12, trailing: 0))

                    GeometryReader { geometry in
                        preview
                            .frame(width: selectedSize.width(in: geometry.size.width), height: selectedSize.height)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .allowsHitTesting(false)
                    }
                    .frame(height: selectedSize.height)
                    .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: selectedSize)
                    .accessibilityIdentifier("widget-gallery-preview")
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 12, trailing: 0))

                    Button("Add Widget", systemImage: "plus") {
                        onAdd(selectedKind, selectedSize)
                        dismiss()
                    }
                    .font(PrototypeFont.inter(16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .tint(PrototypeTheme.success)
                    .accessibilityIdentifier("confirm-add-widget")
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                } header: {
                    Text(selectedKind.title)
                } footer: {
                    Text("Preview uses simulated data. You can change a widget’s size after adding it.")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(PrototypeTheme.background)
            .navigationTitle("Widgets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                }
            }
        }
        .tint(PrototypeTheme.success)
        .preferredColorScheme(PrototypeTheme.colorScheme)
        .accessibilityIdentifier("widget-gallery")
    }

    @ViewBuilder
    private var preview: some View {
        switch selectedKind {
        case .blastExposure:
            BlastExposureCard(animateOnAppear: false, widgetSize: selectedSize)
        case .healthSummary:
            HealthSummaryWidgetCard(
                exposure: ExposurePreviewSample.samples[0].blast,
                averageExposure: ExposurePreviewSample.samples[0].average,
                size: selectedSize,
                animateOnAppear: false
            )
        case .cognition, .sleep, .activity, .heart, .hrv, .respiration:
            PrototypeAuxiliaryWidgetCard(kind: selectedKind, size: selectedSize, animateOnAppear: false)
        }
    }
}
