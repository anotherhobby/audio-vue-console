/// Why Render with Track cannot be used on a scene, or nil where it can (`track-render`, "Render
/// with Track says why it cannot be used" and "Nothing is rendered where the card code differs";
/// design D8). The toolbar button and the File menu read the same answer.
public enum TrackRenderAvailability {
    /// What decides it, gathered by the editor.
    public struct Facts: Sendable {
        public var isPaired: Bool
        public var carriesRenderer: Bool
        /// The rates the panel runs at, from the host's schema.
        public var rates: [Int]?
        public var isTooWide: Bool
        /// The kinds of the cards the scene holds on the panel, parked cards left out.
        public var cards: [String]
        /// How the helper's code compares with the panel's, or nil before it is checked.
        public var verdict: CardCodeVerdict?

        public init(
            isPaired: Bool, carriesRenderer: Bool, rates: [Int]?, isTooWide: Bool,
            cards: [String], verdict: CardCodeVerdict?
        ) {
            self.isPaired = isPaired
            self.carriesRenderer = carriesRenderer
            self.rates = rates
            self.isTooWide = isTooWide
            self.cards = cards
            self.verdict = verdict
        }
    }

    /// Why not, or nil where a track can be rendered. `title` names a card kind as the canvas does.
    public static func reason(_ facts: Facts, title: (String) -> String = { $0 }) -> String? {
        guard facts.isPaired else { return "Pair with a panel to render from a track" }
        guard facts.carriesRenderer else { return "This build carries no renderer" }
        guard facts.rates?.isEmpty == false else { return "The panel's rates can't be read" }
        guard !facts.cards.isEmpty else { return "Add a card to render from a track" }
        guard !facts.isTooWide else { return "This scene is too wide for the panel" }
        guard let verdict = facts.verdict else { return "Checking the renderer's code…" }
        return codeReason(verdict, cards: facts.cards, title: title)
    }

    /// Why the code stops a render: any difference the scene would draw through, since a still has
    /// no place for a box.
    private static func codeReason(
        _ verdict: CardCodeVerdict, cards: [String], title: (String) -> String
    ) -> String? {
        if let none = verdict.noCardsReason { return none }
        guard case .differs(let drift) = verdict else { return nil }
        var boxed: [String] = []
        for kind in cards where drift.boxes(kind) && !boxed.contains(title(kind)) {
            boxed.append(title(kind))
        }
        guard !boxed.isEmpty else { return nil }
        return "This app's code for \(CardDrift.listed(boxed)) differs from the panel's, "
            + "so this scene can't be rendered from a track"
    }
}
