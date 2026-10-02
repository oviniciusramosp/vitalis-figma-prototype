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

    /// Reflow the actual cards while a local drag passes over another card.
    mutating func move(id: UUID, over targetID: UUID) {
        guard id != targetID,
              let source = items.firstIndex(where: { $0.widget?.id == id }),
              let target = items.firstIndex(where: { $0.widget?.id == targetID }) else { return }
        items.move(fromOffsets: IndexSet(integer: source), toOffset: source < target ? target + 1 : target)
    }

    mutating func moveToEnd(id: UUID, aboveBlast: Bool) {
        guard let source = items.firstIndex(where: { $0.widget?.id == id }) else { return }
        let item = items.remove(at: source)
        let destination = aboveBlast ? (items.firstIndex(where: \.isTodayBlast) ?? 0) : items.count
        items.insert(item, at: destination)
    }

    /// VoiceOver offers the same ordering without requiring a drag gesture.
    mutating func moveOnePosition(id: UUID, earlier: Bool) {
        guard let source = items.firstIndex(where: { $0.widget?.id == id }) else { return }
        let destination = earlier ? source - 1 : source + 1
        guard items.indices.contains(destination) else { return }
        items.swapAt(source, destination)
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
