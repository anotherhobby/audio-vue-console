import Foundation

/// A library card's tile drawn in its setup (`library-setup`, "Changing a tile's setting redraws the
/// tile"; design D7): the plain tiles' ladder search with the setup on its card, every probe in the
/// library's lane under one key per card, so a newer setup replaces the probes still waiting.
extension LibraryTiles {
    /// A tile drawn in a card's setup, with the settings it was drawn in.
    struct SetupTile: Sendable {
        let settings: [String: JSONValue]
        let tile: Tile

        /// The same tile stacked over `backdrop`.
        func over(_ backdrop: RenderedLayer) -> SetupTile {
            SetupTile(
                settings: settings, tile: Tile(layer: tile.layer, size: tile.size, over: backdrop))
        }
    }

    /// The tile of the card `name` in its setup, in the shown scene's settings, the last drawn
    /// until its replacement arrives; nil where none is drawn.
    public func setupTile(_ name: String) -> Tile? {
        key.flatMap { sets[$0]?.setups[name]?.tile }
    }

    /// Draws `card`'s tile with `settings` on it, in `draft`'s settings, at the smallest size on
    /// the ladder whose reading fits, else at its declared minimum, kept once drawn while those are
    /// still the settings wanted. The same setup is not drawn again; empty settings drop the set-up
    /// tile. A card the drift boxes is not drawn, and nothing is drawn before the draft's tiles are.
    public func drawSetup(
        _ card: SchemaFacts.Card, settings: [String: JSONValue], for draft: Draft,
        from source: Source
    ) async {
        let key = Key(draft.laidOut, draft.content)
        guard var set = sets[key] else { return }
        set.wantedSetups[card.name] = settings.isEmpty ? nil : settings
        if settings.isEmpty { set.setups[card.name] = nil }
        sets[key] = set
        guard !settings.isEmpty, source.drift?.boxes(card.name) != true,
            set.setups[card.name]?.settings != settings,
            let (plate, size) = await fitted(card, settings, draft, source),
            var held = sets[key], held.wantedSetups[card.name] == settings
        else { return }
        held.setups[card.name] = SetupTile(
            settings: settings, tile: Tile(layer: plate, size: size, over: held.backdrop))
        sets[key] = held
    }

    /// `card`'s plate with `settings`, and the size drawn at: the smallest on the ladder whose
    /// reading fits, else the declared minimum. Nil where a probe failed or was replaced, or the
    /// settings stopped being the ones wanted, so an older search never replaces a newer one's
    /// probes under their shared key.
    private func fitted(
        _ card: SchemaFacts.Card, _ settings: [String: JSONValue], _ draft: Draft,
        _ source: Source
    ) async -> (RenderedLayer, CellSize)? {
        let key = Key(draft.laidOut, draft.content)
        let plate: (CellSize) async -> RenderedLayer? = { size in
            guard self.sets[key]?.wantedSetups[card.name] == settings,
                let request = Self.request(
                    for: draft, card: .tile(card.name, at: size, settings: settings),
                    context: source.context)
            else { return nil }
            let result = await source.queue.submit(
                request.message, lane: .library, key: "tile-setup:\(card.name)")
            return Self.plate(of: result)
        }
        guard let top = Ladder.top(card, grid: draft.laidOut.panel) else { return nil }
        let search = await Ladder.smallestFitting(
            top: top, probe: { step in await plate(Ladder.size(card, step: step)) },
            fits: { $0.unfit.isEmpty })
        switch search {
        case .found(let step, let found): return (found, Ladder.size(card, step: step))
        case .none: return await plate(card.minimum).map { ($0, card.minimum) }
        case .failed: return nil
        }
    }
}
