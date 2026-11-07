/// Why an edit to a layout was refused, as the canvas says it.
public enum LayoutRefusal: Error, Sendable, Hashable, CustomStringConvertible {
    /// A card would run off the grid. Only a layout read in can be refused this way; an edit
    /// keeps its cards on the grid.
    case offGrid
    /// A card in a scene read in has no name, or a cell that is not a whole number.
    case unreadableCard
    case spaceTaken
    case largerThanGrid
    case cardIsGrouped
    case tooFewCards
    case alreadyAGroup
    case notARectangle
    case cardInTheWay
    case readOnly(ReadOnlyReason)

    public var description: String {
        switch self {
        case .offGrid: "A card runs off the scene's grid."
        case .unreadableCard: "A card in this scene can't be read."
        case .spaceTaken: "That space is taken."
        case .largerThanGrid: "That card is larger than this scene's grid."
        case .cardIsGrouped: "A grouped card can't be resized. Ungroup it first (⇧⌘G)."
        case .tooFewCards: "A group needs at least two cards."
        case .alreadyAGroup: "These cards are already a group."
        case .notARectangle: "These cards don't fill a rectangle."
        case .cardInTheWay: "Another card is in the way."
        case .readOnly(let reason): reason.description
        }
    }
}

/// Why a scene cannot be edited where it is.
public enum ReadOnlyReason: Sendable, Hashable, CustomStringConvertible {
    case builtIn
    /// The scene's shape and the panel's, such as `16:9` and `8:3`.
    case shape(scene: String, panel: String)

    public var description: String {
        switch self {
        case .builtIn:
            "Built-in scenes can't be edited. Duplicate it to edit."
        case .shape(let scene, let panel):
            "This scene is \(scene) and the panel is \(panel). Duplicate it for this panel to edit."
        }
    }
}
