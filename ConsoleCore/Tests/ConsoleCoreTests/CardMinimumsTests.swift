import Foundation
import Testing

@testable import ConsoleCore

/// `card-minimum`, "The console asks the helper for a card's minimum": one request per card and
/// settings, held and shared (design D2).
@MainActor
struct CardMinimumsTests {
    /// A 64 × 36 scene in `colours` holding two meters with the same settings.
    private static func draft(colours: String = "a") throws -> Draft {
        let meter: (Int) -> JSONValue = { col in
            .object([
                "card": .string("meter"), "col": .integer(col), "row": .integer(10),
                "colspan": .integer(8), "rowspan": .integer(6),
                "params": .object(["ticks": .string("5")]),
            ])
        }
        let doc: JSONValue = .object([
            "name": .string("A"), "colors": .string(colours),
            "cards": .array([meter(0), meter(20)]),
        ])
        let document = SceneDocument(id: "A", name: "A", builtIn: false, fixed: false, doc: doc)
        return Draft(try LaidOutScene(document, panel: CellSize(cols: 64, rows: 36)))
    }

    private static func source(_ fixture: RenderingFixture) -> LibraryTiles.Source {
        LibraryTiles.Source(
            cards: [], drift: nil, context: RenderRequestTests.context, queue: fixture.queue)
    }

    private static func asked(_ fixture: RenderingFixture) -> [JSONValue] {
        fixture.launcher.requests.filter { $0["op"] == .string("minimum") }
    }

    private static func ask(
        _ minimums: CardMinimums, _ card: LayoutCard, _ draft: Draft, _ fixture: RenderingFixture
    ) async -> CardMinimum? {
        await minimums.ask(
            for: card, in: draft, from: source(fixture), lane: .library, key: "minimum:test")
    }

    @Test func oneRequestPerCardAndSettings() async throws {
        let fixture = try RenderingFixture()
        let (minimums, draft) = (CardMinimums(), try Self.draft())
        let card = try #require(draft.layout.cards.first)
        let answer = await Self.ask(minimums, card, draft, fixture)
        #expect(answer == CardMinimum(whole: [8: 6], readable: [8: 6]))
        _ = await Self.ask(minimums, card, draft, fixture)
        #expect(Self.asked(fixture).count == 1)
        let request = try #require(Self.asked(fixture).first)
        #expect(request["placement"] == .integer(0))
        let sent = request["scene"]?["cards"]?.arrayValue?.first
        #expect(sent?["col"] == .integer(0) && sent?["params"]?["ticks"] == .string("5"))
    }

    /// "Moving a card" and "Two cards alike".
    @Test func aMovedCardAndItsTwinAskNothing() async throws {
        let fixture = try RenderingFixture()
        var (minimums, draft) = (CardMinimums(), try Self.draft())
        let (first, second) = (draft.layout.cards[0], draft.layout.cards[1])
        _ = await Self.ask(minimums, first, draft, fixture)
        #expect(minimums.answer(for: second, in: draft) != nil)
        draft.content.layout = try draft.layout.moving([first.id], by: CellOffset(cols: 0, rows: 5))
        let moved = try #require(draft.content.card(first.id))
        #expect(minimums.answer(for: moved, in: draft) != nil)
        _ = await Self.ask(minimums, moved, draft, fixture)
        #expect(Self.asked(fixture).count == 1)
    }

    /// "Turning ticks on", and a scene setting.
    @Test func aChangedSettingAsksAgain() async throws {
        let fixture = try RenderingFixture()
        var (minimums, draft) = (CardMinimums(), try Self.draft())
        let card = draft.layout.cards[0]
        _ = await Self.ask(minimums, card, draft, fixture)
        draft.content = draft.content.setting("ticks", to: .string("10"), on: [card.id])
        let changed = try #require(draft.content.card(card.id))
        #expect(minimums.answer(for: changed, in: draft) == nil)
        _ = await Self.ask(minimums, changed, draft, fixture)
        let recoloured = try Self.draft(colours: "b")
        _ = await Self.ask(minimums, recoloured.layout.cards[0], recoloured, fixture)
        #expect(Self.asked(fixture).count == 3)
    }

    /// A tile and the selected card alike, asked about at once in their own lanes.
    private static func askTwiceAtOnce(
        _ minimums: CardMinimums, _ card: LayoutCard, _ draft: Draft, _ fixture: RenderingFixture
    ) async -> (CardMinimum?, CardMinimum?) {
        let tile = Task { await ask(minimums, card, draft, fixture) }
        let selected = Task {
            await minimums.ask(
                for: card, in: draft, from: source(fixture), lane: .canvas, key: "minimum:selected")
        }
        return (await tile.value, await selected.value)
    }

    @Test func twoAsksAtOnceShareOneRequest() async throws {
        let fixture = try RenderingFixture()
        let (minimums, draft) = (CardMinimums(), try Self.draft())
        let (tile, selected) = await Self.askTwiceAtOnce(
            minimums, draft.layout.cards[0], draft, fixture)
        #expect(tile == CardMinimum(whole: [8: 6], readable: [8: 6]))
        #expect(selected == tile)
        #expect(Self.asked(fixture).count == 1)
    }

    @Test func aWaiterWhoseRequestComesBackEmptyAsksItself() async throws {
        let fixture = try RenderingFixture { request in
            request["op"] == .string("minimum")
                ? .answer(#"{"ok": false, "refused": "no"}"#) : FakeRender.reply(to: request)
        }
        let (minimums, draft) = (CardMinimums(), try Self.draft())
        let (tile, selected) = await Self.askTwiceAtOnce(
            minimums, draft.layout.cards[0], draft, fixture)
        #expect(tile == nil && selected == nil)
        #expect(Self.asked(fixture).count == 2)
    }

    @Test func aRefusedAnswerIsNoAnswerAndIsAskedAgain() async throws {
        let fixture = try RenderingFixture { request in
            request["op"] == .string("minimum")
                ? .answer(#"{"ok": false, "refused": "no"}"#) : FakeRender.reply(to: request)
        }
        let (minimums, draft) = (CardMinimums(), try Self.draft())
        let card = draft.layout.cards[0]
        #expect(await Self.ask(minimums, card, draft, fixture) == nil)
        #expect(minimums.answer(for: card, in: draft) == nil)
        _ = await Self.ask(minimums, card, draft, fixture)
        #expect(Self.asked(fixture).count == 2)
    }
}
