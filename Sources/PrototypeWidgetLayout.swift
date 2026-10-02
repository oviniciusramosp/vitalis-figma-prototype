import SwiftUI

enum PrototypeDashboardItem: Codable, Equatable, Identifiable {
    case widget(PrototypeWidget)
    case todayBlast

    var id: String {
        switch self {
        case .widget(let widget): widget.id.uuidString
        case .todayBlast: "today-blast"
        }
    }

    var widget: PrototypeWidget? {
        if case .widget(let widget) = self { return widget }
        return nil
    }

    var isTodayBlast: Bool {
        if case .todayBlast = self { return true }
        return false
    }
}

struct PrototypeWidgetLayout: Codable, Equatable {
    static let storageKey = "prototype.widget-layout.v1"

    var items: [PrototypeDashboardItem]
    private var persistenceEnabled = true

    init(widgets: [PrototypeWidget]) {
        var identifiers = Set<UUID>()
        let uniqueWidgets = widgets.filter { identifiers.insert($0.id).inserted }
        items = [.todayBlast] + uniqueWidgets.map(PrototypeDashboardItem.widget)
    }

    var widgets: [PrototypeWidget] { items.compactMap(\.widget) }

    var aboveBlastWidgets: [PrototypeWidget] {
        guard let anchor = items.firstIndex(where: \.isTodayBlast) else { return [] }
        return items.prefix(anchor).compactMap(\.widget)
    }

    var belowBlastWidgets: [PrototypeWidget] {
        guard let anchor = items.firstIndex(where: \.isTodayBlast) else { return [] }
        return items.dropFirst(anchor + 1).compactMap(\.widget)
    }

    mutating func append(_ widget: PrototypeWidget) {
        guard !widgets.contains(where: { $0.id == widget.id }) else { return }
        items.append(.widget(widget))
    }

    mutating func remove(id: UUID) {
        items.removeAll { $0.widget?.id == id }
    }

    mutating func resize(id: UUID, to size: PrototypeWidgetSize) {
        guard let index = items.firstIndex(where: { $0.widget?.id == id }),
              case .widget(var widget) = items[index] else { return }
        widget.size = size
        items[index] = .widget(widget)
    }

    /// Quick placement puts the widget immediately above or below the main gauge.
    mutating func move(id: UUID, aboveBlast: Bool) {
        guard items.contains(where: \.isTodayBlast),
              let index = items.firstIndex(where: { $0.widget?.id == id }) else { return }
        let item = items.remove(at: index)
        guard let anchor = items.firstIndex(where: \.isTodayBlast) else { return }
        items.insert(item, at: aboveBlast ? anchor : anchor + 1)
    }

    mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let validSource = IndexSet(source.filter { items.indices.contains($0) })
        guard !validSource.isEmpty else { return }
        items.move(fromOffsets: validSource, toOffset: min(items.count, max(0, destination)))
    }

    static func load(defaultWidgets: [PrototypeWidget], persist: Bool = true) -> Self {
        var fallback = Self(widgets: defaultWidgets)
        let enabled = persist && !isFixtureRun
        fallback.persistenceEnabled = enabled
        // Fixtures start from their requested layout and neither read nor write user settings.
        guard enabled,
              let data = UserDefaults.standard.data(forKey: storageKey),
              var decoded = try? JSONDecoder().decode(Self.self, from: data) else { return fallback }
        decoded.persistenceEnabled = enabled
        return decoded
    }

    func save() {
        guard persistenceEnabled, !Self.isFixtureRun, Self.valid(items),
              let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.items == rhs.items
    }

    private static var isFixtureRun: Bool {
        ProcessInfo.processInfo.arguments.contains {
            $0.hasPrefix("--preview-") || $0.hasPrefix("--ui-testing")
        }
    }

    private static func valid(_ items: [PrototypeDashboardItem]) -> Bool {
        items.filter(\.isTodayBlast).count == 1 && Set(items.map(\.id)).count == items.count
    }

    private enum CodingKeys: String, CodingKey { case items }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedItems = try container.decode([PrototypeDashboardItem].self, forKey: .items)
        guard Self.valid(decodedItems) else {
            throw DecodingError.dataCorruptedError(
                forKey: .items,
                in: container,
                debugDescription: "Dashboard layout needs exactly one TODAY'S BLAST anchor and unique widget identifiers."
            )
        }
        items = decodedItems
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(items, forKey: .items)
    }
}

struct WidgetLayoutEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var layout: PrototypeWidgetLayout
    var onChange: () -> Void = {}

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(layout.items) { item in
                        row(for: item)
                    }
                    .onMove { source, destination in
                        layout.move(fromOffsets: source, toOffset: destination)
                        onChange()
                    }
                } header: {
                    Text("Drag widgets above or below TODAY’S BLAST.")
                        .textCase(nil)
                } footer: {
                    Text("Your widgets keep their size when you move them.")
                }
                .listRowBackground(Color.white.opacity(0.045))
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(PrototypeTheme.background)
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Reorder Widgets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("widget-layout-done")
                }
            }
        }
        .tint(PrototypeTheme.success)
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("widget-layout-editor")
    }

    @ViewBuilder
    private func row(for item: PrototypeDashboardItem) -> some View {
        let position = (layout.items.firstIndex(where: { $0.id == item.id }) ?? 0) + 1
        switch item {
        case .widget(let widget):
            HStack(spacing: 12) {
                Image(systemName: widget.kind.symbol)
                    .font(.system(size: 19))
                    .foregroundStyle(PrototypeTheme.foreground)
                    .frame(width: 26)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(widget.kind.title)
                        .font(PrototypeFont.inter(15, weight: .medium))
                        .foregroundStyle(PrototypeTheme.foreground)
                    Text("\(widget.size.title) · \(placement(of: item))")
                        .font(PrototypeFont.inter(11))
                        .foregroundStyle(PrototypeTheme.muted)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 5)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("widget-layout-row-\(widget.kind.rawValue)")
            .accessibilityLabel(widget.kind.title)
            .accessibilityValue("Widget size: \(widget.size.title). Position: \(position) of \(layout.items.count). \(placement(of: item)).")
            .accessibilityHint("Use the reorder control to change this widget’s position.")
        case .todayBlast:
            HStack(spacing: 12) {
                Image(systemName: "gauge.with.dots.needle.50percent")
                    .font(.system(size: 19))
                    .foregroundStyle(PrototypeTheme.accent)
                    .frame(width: 26)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("TODAY’S BLAST")
                        .font(PrototypeFont.inter(12, weight: .semibold))
                        .foregroundStyle(PrototypeTheme.foreground)
                    Text("Place widgets above or below this section")
                        .font(PrototypeFont.inter(11))
                        .foregroundStyle(PrototypeTheme.muted)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 5)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("widget-layout-blast-anchor")
            .accessibilityLabel("TODAY’S BLAST")
            .accessibilityValue("Main gauge. Position: \(position) of \(layout.items.count).")
            .accessibilityHint("Use the reorder control to change the main gauge’s position.")
        }
    }

    private func placement(of item: PrototypeDashboardItem) -> String {
        guard let itemIndex = layout.items.firstIndex(where: { $0.id == item.id }),
              let anchorIndex = layout.items.firstIndex(where: \.isTodayBlast) else { return "" }
        return itemIndex < anchorIndex ? "Above TODAY’S BLAST" : "Below TODAY’S BLAST"
    }
}
