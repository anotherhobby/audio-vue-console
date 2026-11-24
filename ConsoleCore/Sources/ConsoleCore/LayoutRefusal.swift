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
    /// A drag off the panel with no room in the pane beyond the edge it crosses (`card-parking`).
    case noRoomOffPanel
    /// An arrow key that would take a parked card onto the panel or out of the pane.
    case dragToCross
    /// A group asked of cards on the panel and cards parked off it.
    case acrossPanelEdge
    /// A paste with no room for the copied cards on the panel or off it (`card-clipboard`).
    case noRoomToPaste
    /// A paste holding a card, by name, that the panel's schema does not mark placeable.
    case notPlaceable(String)
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
        case .noRoomOffPanel: "There's no room for that off the panel."
        case .dragToCross: "Drag a card to move it onto or off the panel."
        case .acrossPanelEdge: "A group is wholly on the panel or wholly off it."
        case .noRoomToPaste: "There's no room to paste the copied cards."
        case .notPlaceable(let card): "This panel can't place the copied card “\(card)”."
        case .readOnly(let reason): reason.description
        }
    }
}

/// Why a scene cannot be edited where it is.
public enum ReadOnlyReason: Sendable, Hashable, CustomStringConvertible {
    case builtIn

    public var description: String {
        switch self {
        case .builtIn:
            "Built-in scenes can't be edited. Duplicate it to edit."
        }
    }
}
