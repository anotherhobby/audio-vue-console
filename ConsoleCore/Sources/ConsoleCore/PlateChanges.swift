import Foundation

/// What a plate was drawn from: the cells it covered and each of its cards' settings, by card id.
/// A plate is drawn again when either differs (`card-settings`, design D6).
public struct PlateState: Sendable, Equatable {
    public let cells: CellRect
    public let settings: [UUID: [String: JSONValue]]

    public init(cells: CellRect, settings: [UUID: [String: JSONValue]]) {
        self.cells = cells
        self.settings = settings
    }
}

/// Which plates must be drawn again for a layout (design D5). A plate is a card in no group, or a
/// group, known by the cards it holds, so a group renamed or rebuilt from the same cards is the
/// same plate.
public struct PlateChanges: Sendable, Equatable {
    /// Plates to draw: new ones, and ones drawn at other cells or with other settings than the
    /// layout's.
    public let redraw: Set<Set<UUID>>
    /// Plates drawn that the layout no longer has, whose layers go.
    public let removed: Set<Set<UUID>>

    /// Every plate of `layout`, as the cards it holds, with the cells it covers.
    public static func cells(of layout: SceneLayout) -> [Set<UUID>: CellRect] {
        drawn(of: layout).mapValues(\.cells)
    }

    /// Every plate of `layout`, as the cards it holds, with its cells and its cards' settings.
    public static func drawn(of layout: SceneLayout) -> [Set<UUID>: PlateState] {
        var plates: [Set<UUID>: PlateState] = [:]
        for card in layout.cards where card.group == nil {
            plates[[card.id]] = PlateState(cells: card.cells, settings: [card.id: card.settings])
        }
        for members in layout.groups.values {
            guard let cells = CellRect(enclosing: members.map(\.cells)) else { continue }
            let settings = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0.settings) })
            plates[Set(members.map(\.id))] = PlateState(cells: cells, settings: settings)
        }
        return plates
    }

    /// What `layout` needs given plates `drawn` as each was drawn: every plate it has that was not
    /// drawn, or was drawn elsewhere, at another size or with other settings, and every plate drawn
    /// that it no longer has.
    public static func needed(drawn: [Set<UUID>: PlateState], for layout: SceneLayout)
        -> PlateChanges
    {
        let wanted = Self.drawn(of: layout)
        let redraw = wanted.filter { drawn[$0.key] != $0.value }.keys
        return PlateChanges(
            redraw: Set(redraw), removed: Set(drawn.keys).subtracting(wanted.keys))
    }

    /// What changed between `old`, as drawn, and `new`.
    public static func between(_ old: SceneLayout, _ new: SceneLayout) -> PlateChanges {
        needed(drawn: drawn(of: old), for: new)
    }
}
