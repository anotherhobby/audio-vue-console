import ConsoleCore
import SwiftUI

/// The open scene's library tiles: the plain ones in its settings as edited, where the panel's code
/// lets cards be drawn, as the gallery's thumbnails are (`library-render` design D4), and each
/// set-up card's tile with its setup (`library-setup`, design D7). Where no card can be drawn, the
/// tiles are boxes.
@MainActor
struct EditorTiles {
    let store: SceneStore
    let renderer: Renderer
    let scenes: PanelScenes
    let verdict: CardCodeVerdict?
    /// The open scene, by id.
    let id: String

    /// Draws the plain tiles, then every set-up card's tile in `setups`, as when the scene's
    /// settings change.
    func draw(setups: [String: [String: JSONValue]]) async {
        guard let (draft, source) = source() else { return }
        await store.tiles.draw(for: draft, from: source)
        await drawSetups(setups.keys, as: setups, draft, source)
    }

    /// Draws the set-up tile of each card whose setup differs between `old` and `new`, or drops
    /// it where the card has none left.
    func drawChanged(from old: [String: [String: JSONValue]], to new: [String: [String: JSONValue]])
        async
    {
        guard let (draft, source) = source() else { return }
        let changed = Set(old.keys).union(new.keys).filter { old[$0] != new[$0] }
        await drawSetups(changed, as: new, draft, source)
    }

    /// The size a card of `kind` is dropped at: its set-up tile's where it is `setUp` and that tile
    /// is drawn, else `minimum`, its declared one (`library-setup`, "A set-up card is dropped at its
    /// tile's size").
    func dropSize(of kind: String, setUp: Bool, minimum: CellSize?) -> CellSize? {
        guard setUp, let tile = store.tiles.setupTile(kind) else { return minimum }
        return tile.size
    }

    /// The tiles the library shows: each set-up card's tile in place of its plain one, once drawn.
    func shown(setUp: some Sequence<String>) -> [String: LibraryTiles.Tile] {
        var tiles = store.tiles.tiles
        for name in setUp {
            if let tile = store.tiles.setupTile(name) { tiles[name] = tile }
        }
        return tiles
    }

    private func drawSetups(
        _ names: some Sequence<String>, as setups: [String: [String: JSONValue]], _ draft: Draft,
        _ source: LibraryTiles.Source
    ) async {
        for card in source.cards where names.contains(card.name) {
            await store.tiles.drawSetup(
                card, settings: setups[card.name] ?? [:], for: draft, from: source)
        }
    }

    /// The draft and what its tiles are drawn from, or nil where no tile is to be drawn: the
    /// tiles are forgotten where the card code lets no card be drawn.
    private func source() -> (Draft, LibraryTiles.Source)? {
        guard let draft = store.drafts.draft(id), let queue = renderer.queue,
            let cards = scenes.facts?.placeable
        else { return nil }
        let drift: CardDrift?
        switch verdict {
        case .same?: drift = nil
        case .differs(let differs)? where !differs.sharesNothing: drift = differs
        case nil: return nil
        default:
            store.tiles.forget()
            return nil
        }
        return (
            draft,
            LibraryTiles.Source(cards: cards, drift: drift, context: scenes.context, queue: queue)
        )
    }
}
