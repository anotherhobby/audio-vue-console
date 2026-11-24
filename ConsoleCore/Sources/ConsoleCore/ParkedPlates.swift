import Foundation

/// The plates of cards parked off the panel, each a layer kept from the grid or drawn alone
/// (`scene-rendering`, "A parked card keeps its plate" and "A parked plate is drawn again on its
/// own"; `card-parking` design D7).
public struct ParkedPlates: Sendable {
    /// Each parked plate's layer by its cards, with the cells and settings it was drawn for. The
    /// canvas slides it from those cells to where the plate is parked.
    public private(set) var layers: [Set<UUID>: SceneRendering.PlacedLayer] = [:]

    /// Sorts the layers for `content`: a plate whose cards are all parked moves here from
    /// `plates`, one back on the grid moves back there, and one no longer parked goes. Answers
    /// the parked plates to draw alone: those with no layer, other settings or another size, or
    /// every one where the scene is `restyled` (`card-parking`, design D11).
    mutating func sort(
        _ content: SceneContent, plates: inout [Set<UUID>: SceneRendering.PlacedLayer],
        restyled: Bool
    ) -> [Set<UUID>] {
        let wanted = Self.plates(of: content)
        let onGrid = PlateChanges.drawn(of: content.layout)
        for (members, placed) in plates where wanted[members] != nil {
            layers[members] = placed
            plates[members] = nil
        }
        for (members, placed) in layers where wanted[members] == nil {
            if onGrid[members] != nil { plates[members] = placed }
            layers[members] = nil
        }
        return wanted.filter { members, state in
            guard !restyled, let held = layers[members] else { return true }
            return held.settings != state.settings || !held.cells.sameSize(as: state.cells)
        }.map(\.key)
    }

    /// The parked plate `members` of `content` as a layout of its own: its cards moved together to
    /// the grid's top-left, as a library tile's card is drawn, or nil where none is parked.
    static func alone(_ members: Set<UUID>, of content: SceneContent) -> SceneLayout? {
        let cards = content.parked.filter { members.contains($0.id) }
        guard let block = CellRect(enclosing: cards.map(\.cells)) else { return nil }
        let toCorner = CellOffset(cols: -block.col, rows: -block.row)
        let moved = cards.map { card in
            var moved = card
            moved.cells = card.cells.offset(by: toCorner)
            return moved
        }
        return SceneLayout(checked: content.layout.grid, cards: moved)
    }

    /// Keeps `layer`, drawn for `drawn`, a plate alone, where that plate is still parked in
    /// `content`.
    mutating func take(
        _ layer: RenderedLayer, drawnFor drawn: SceneLayout, in content: SceneContent
    ) {
        let members = Set(layer.cardIDs)
        guard layer.kind != .backdrop, Self.plates(of: content)[members] != nil,
            let state = PlateChanges.drawn(of: drawn)[members]
        else { return }
        layers[members] = SceneRendering.PlacedLayer(
            layer: layer, cells: state.cells, settings: state.settings)
    }

    mutating func clear() {
        layers = [:]
    }

    /// The parked plates of `content`, by their cards, with their cells and settings. Parked cards
    /// form plates as a layout's cards do, though their cells lie off its grid.
    private static func plates(of content: SceneContent) -> [Set<UUID>: PlateState] {
        PlateChanges.drawn(of: SceneLayout(checked: content.layout.grid, cards: content.parked))
    }
}

extension CellRect {
    /// Whether this block has `other`'s columns and rows, wherever each lies.
    fileprivate func sameSize(as other: CellRect) -> Bool {
        cols == other.cols && rows == other.rows
    }
}
