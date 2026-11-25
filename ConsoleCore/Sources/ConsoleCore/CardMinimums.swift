import Foundation
import Observation

/// The helper's `minimum` answers, held by the card's settings and the scene's settings, so a drag
/// reads a held answer and never waits (`card-minimum`, design D2). A card's place and group do not
/// change its answer, so a moved card asks nothing and two cards alike share one.
@MainActor @Observable
public final class CardMinimums {
    /// What an answer is held for: the scene's settings, as a tile is drawn in, and the card's
    /// entry without its cells or group.
    public struct Key: Hashable, Sendable {
        let settings: LibraryTiles.Key
        let card: JSONValue
    }

    private var answers: [Key: CardMinimum] = [:]
    /// The request in flight for each key, which a second ask for it waits on.
    private var asking: [Key: Task<CardMinimum?, Never>] = [:]
    /// The scene settings answers are held for, the least recently asked first.
    private var recent: [LibraryTiles.Key] = []

    public init() {}

    /// `card`'s held answer in `draft`'s settings, or nil where none is held. Asks nothing.
    public func answer(for card: LayoutCard, in draft: Draft) -> CardMinimum? {
        answers[Self.key(for: card, in: draft)]
    }

    /// Asks the helper for `card`'s minimum in `draft`'s settings, in `lane` under `key`, unless an
    /// answer is held, and answers what is then held. Where the same card is already being asked
    /// about, this waits for that answer, and asks itself only where that one comes back empty, so
    /// a tile and a selected card alike both get the answer. A refusal, a failure or a request
    /// replaced by a newer one under `key` holds nothing, so a later ask tries again.
    @discardableResult
    public func ask(
        for card: LayoutCard, in draft: Draft, from source: LibraryTiles.Source,
        lane: RenderQueue.Lane, key tag: String
    ) async -> CardMinimum? {
        let key = Self.key(for: card, in: draft)
        if let held = answers[key] { return held }
        if let pending = asking[key], let answer = await pending.value { return answer }
        guard let message = Self.message(for: card, in: draft, source) else { return nil }
        touch(key.settings)
        let pending = Task { () -> CardMinimum? in
            let result = await source.queue.submit(message, lane: lane, key: tag)
            guard case .success(let answer)? = result else { return nil }
            return CardMinimum(answer: answer.header)
        }
        asking[key] = pending
        let minimum = await pending.value
        if asking[key] == pending { asking[key] = nil }
        guard let minimum, recent.contains(key.settings) else { return nil }
        answers[key] = minimum
        return minimum
    }

    /// Forgets every answer, as when another panel is shown.
    public func forget() {
        answers = [:]
        asking = [:]
        recent = []
    }

    /// The key `card` is held under in `draft`'s settings.
    static func key(for card: LayoutCard, in draft: Draft) -> Key {
        var entry = draft.laidOut.entries(of: [card], in: draft.content).first?.objectValue ?? [:]
        for field in ["col", "row", "colspan", "rowspan", "group"] { entry[field] = nil }
        return Key(settings: LibraryTiles.Key(draft.laidOut, draft.content), card: .object(entry))
    }

    /// A `minimum` request for `card` alone at the grid's top-left in `draft`'s settings, as its
    /// tile is drawn, keeping its id so its whole entry goes with it; nil where it is off the grid.
    private static func message(
        for card: LayoutCard, in draft: Draft, _ source: LibraryTiles.Source
    ) -> JSONValue? {
        var corner = card
        corner.cells = CellRect(col: 0, row: 0, cols: card.cells.cols, rows: card.cells.rows)
        corner.group = nil
        guard let request = LibraryTiles.request(for: draft, card: corner, context: source.context)
        else { return nil }
        var fields = source.context.fields(for: request.doc, builtIn: request.builtIn)
        fields["op"] = .string("minimum")
        fields["placement"] = .integer(0)
        return .object(fields)
    }

    /// Notes `settings` as asked about last, dropping the answers of those asked about longest ago
    /// beyond `LibraryTiles.kept`.
    private func touch(_ settings: LibraryTiles.Key) {
        recent.removeAll { $0 == settings }
        recent.append(settings)
        while recent.count > LibraryTiles.kept {
            let old = recent.removeFirst()
            answers = answers.filter { $0.key.settings != old }
        }
    }
}
