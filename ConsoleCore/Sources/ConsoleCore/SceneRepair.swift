import Foundation

/// The smallest edit that gives a scene the shape the host's schema asks for, and what it changes
/// (`scene-repair`, design D3).
public struct SceneRepair: Sendable, Equatable {
    /// The scene as it was checked.
    public let original: JSONValue
    /// The scene repaired, or nil where no edit gives it the shape: a scene left with no card the
    /// host has.
    public let doc: JSONValue?
    public let changes: [RepairChange]

    public var canRepair: Bool { doc != nil }

    /// The index, in the scene as checked, of each card the repair removes.
    public var removedCards: Set<Int> {
        Set(
            changes.compactMap { change in
                guard case .removedItem = change.outcome, change.path.count == 2,
                    change.path.first == .key(Self.cards), case .index(let index) = change.path[1]
                else { return nil }
                return index
            })
    }

    /// Each change as the canvas lists it, such as "Analysis: rta_hold_s removed".
    public var lines: [String] { changes.map { $0.line(in: original) } }

    static let cards = "cards"
}

/// One change a repair makes: where, and what becomes of the value there.
public struct RepairChange: Sendable, Equatable {
    public enum Step: Sendable, Equatable {
        case key(String)
        case index(Int)
    }

    public enum Outcome: Sendable, Equatable {
        /// A key the schema does not declare, removed.
        case removed
        /// A declared value that does not fit, removed so that it takes its default.
        case unset(was: JSONValue)
        /// A number past a bound, set to that bound.
        case clamped(from: JSONValue, to: JSONValue)
        /// A list's item that cannot be made whole, removed: a card the host does not have.
        case removedItem(was: JSONValue)
    }

    public let path: [Step]
    public let outcome: Outcome

    public init(path: [Step], outcome: Outcome) {
        self.path = path
        self.outcome = outcome
    }

    /// The change in words, naming a card by its kind and number in `scene`, the scene as checked,
    /// and a block by its section's title.
    func line(in scene: JSONValue) -> String {
        let (place, rest) = Self.place(of: path, in: scene)
        let what = rest.map(Self.name).joined(separator: " › ")
        switch outcome {
        case .removed:
            return "\(place): \(what) removed"
        case .unset(let was):
            if was.objectValue != nil || was.arrayValue != nil {
                return "\(place): \(what) removed"
            }
            return "\(place): \(what) \(was.text) → default"
        case .clamped(let from, let to):
            return "\(place): \(what) \(from.text) → \(to.text)"
        case .removedItem:
            return rest.isEmpty ? "\(place) removed" : "\(place): \(what) removed"
        }
    }

    /// Where `path` starts, as a person names it, and the steps after it: a card, a block, else the
    /// scene itself. A card's `params` is the card's own, so it is not named.
    private static func place(of path: [Step], in scene: JSONValue) -> (String, [Step]) {
        switch path.first {
        case .key(SceneRepair.cards):
            guard case .index(let index) = path.dropFirst().first else { return ("Scene", path) }
            let kind = scene[SceneRepair.cards]?.arrayValue?[safe: index]?["card"]?.stringValue
            let label = "\(SceneSettingsTab.title(ofCard: kind ?? "card")) (card \(index + 1))"
            let rest = path.dropFirst(2).filter { $0 != .key("params") }
            return (label, Array(rest))
        case .key(let block) where path.count > 1:
            return (SceneSettingsTab.title(ofBlock: block), Array(path.dropFirst()))
        default:
            return ("Scene", path)
        }
    }

    private static func name(_ step: Step) -> String {
        switch step {
        case .key(let key): key
        case .index(let index): "item \(index + 1)"
        }
    }
}

extension Array {
    fileprivate subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
