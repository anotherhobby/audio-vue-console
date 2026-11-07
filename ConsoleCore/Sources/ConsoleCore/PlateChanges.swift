import Foundation

/// Which plates must be drawn again for a layout (design D5). A plate is a card in no group, or a
/// group, known by the cards it holds, so a group renamed or rebuilt from the same cards is the
/// same plate.
public struct PlateChanges: Sendable, Equatable {
    /// Plates to draw: new ones, and ones drawn at other cells than the layout's.
    public let redraw: Set<Set<UUID>>
    /// Plates drawn that the layout no longer has, whose layers go.
    public let removed: Set<Set<UUID>>

    /// Every plate of `layout`, as the cards it holds, with the cells it covers.
    public static func cells(of layout: SceneLayout) -> [Set<UUID>: CellRect] {
        var plates: [Set<UUID>: CellRect] = [:]
        for card in layout.cards where card.group == nil {
            plates[[card.id]] = card.cells
        }
        for members in layout.groups.values {
            plates[Set(members.map(\.id))] = CellRect(enclosing: members.map(\.cells))
        }
        return plates
    }

    /// What `layout` needs given plates `drawn` at the cells each was drawn for: every plate it has
    /// that was not drawn, or was drawn elsewhere or at another size, and every plate drawn that it
    /// no longer has.
    public static func needed(drawn: [Set<UUID>: CellRect], for layout: SceneLayout)
        -> PlateChanges
    {
        let wanted = cells(of: layout)
        let redraw = wanted.filter { drawn[$0.key] != $0.value }.keys
        return PlateChanges(
            redraw: Set(redraw), removed: Set(drawn.keys).subtracting(wanted.keys))
    }

    /// What changed between `old`, as drawn, and `new`.
    public static func between(_ old: SceneLayout, _ new: SceneLayout) -> PlateChanges {
        needed(drawn: cells(of: old), for: new)
    }
}
