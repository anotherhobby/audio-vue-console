import Foundation
import Testing

@testable import ConsoleCore

/// `card-code` and `render-runtime`: the verdict, and what the canvas draws for it.
@MainActor
struct CardCodeCheckTests {
    private static let bundled = CardManifest(
        digest: "app", entries: ["src/cards/meter": "m1", "src/glass.py": "g1"],
        cards: ["meter": "src/cards/meter"])

    private static func verdict(bundled: CardManifest?, host: String, entries: [String: String])
        async throws -> CardCodeVerdict
    {
        try await CardCodeCheck.verdict(
            helperDigest: "app", bundled: bundled,
            version: CardCode(digest: host, source: .panel)
        ) { () throws(HostFailure) in
            (
                CardManifest(digest: host, entries: entries, cards: ["meter": "src/cards/meter"]),
                .panel
            )
        }
    }

    @Test func theSameCode() async throws {
        let verdict = try await Self.verdict(bundled: Self.bundled, host: "app", entries: [:])
        #expect(verdict == .same)
    }

    @Test func aBundleThatIsNotItsManifest() async throws {
        let damaged = CardManifest(digest: "other", entries: [:])
        #expect(
            try await Self.verdict(bundled: damaged, host: "app", entries: [:]) == .damagedBundle)
        #expect(try await Self.verdict(bundled: nil, host: "app", entries: [:]) == .damagedBundle)
    }

    @Test func aFamilyDiffering() async throws {
        let verdict = try await Self.verdict(
            bundled: Self.bundled, host: "host",
            entries: ["src/cards/meter": "m2", "src/glass.py": "g1"])
        guard case .differs(let drift) = verdict else {
            Issue.record("expected a difference, got \(verdict)")
            return
        }
        #expect(drift.families == ["meter"])
    }

    @Test func theBundledManifestIsRead() throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).json")
        let json =
            #"{"digest": "d", "entries": {"src/glass.py": "g"}, "cards": {"logo": "src/cards/logo"}}"#
        try Data(json.utf8).write(to: file)
        let manifest = try CardCodeCheck.bundledManifest(at: file)
        #expect(
            manifest
                == CardManifest(
                    digest: "d", entries: ["src/glass.py": "g"], cards: ["logo": "src/cards/logo"]))
    }

    @Test func aDriftedFamilysCardIsABoxAndTheRestDraw() async throws {
        let fixture = try RenderingFixture()
        await fixture.rendering.attach(fixture.queue)
        let cards = [
            "meter": "src/cards/meter", "waveform": "src/cards/waveform", "tiny": "src/cards/tiny",
        ]
        let families = ["src/cards/waveform": "w", "src/cards/tiny": "t"]
        let drift = CardDrift.between(
            bundled: CardManifest(
                digest: "a", entries: families.merging(["src/cards/meter": "1"]) { $1 },
                cards: cards),
            host: CardManifest(
                digest: "b", entries: families.merging(["src/cards/meter": "2"]) { $1 },
                cards: cards),
            source: .panel)
        fixture.rendering.apply(.differs(drift))
        let meter = try #require(fixture.layout.cards.first { $0.kind == "meter" })
        #expect(fixture.rendering.boxedCards == [meter.id])
        #expect(fixture.rendering.plates.count == 3)
        #expect(fixture.rendering.messages.contains { $0.contains("meter") })
    }

    @Test func sharedCodeDifferingDrawsNothing() async throws {
        let fixture = try RenderingFixture()
        let drift = CardDrift.between(
            bundled: CardManifest(digest: "a", entries: ["src/glass.py": "1"]),
            host: CardManifest(digest: "b", entries: ["src/glass.py": "2"]), source: .host)
        fixture.rendering.apply(.differs(drift))
        await fixture.rendering.attach(fixture.queue)
        #expect(fixture.rendering.status == .codeDiffers(["src/glass.py"]))
        #expect(fixture.rendering.showsBoxes)
        #expect(fixture.launcher.requests.isEmpty)
        #expect(fixture.rendering.messages.first?.contains("next start") == true)
    }

    @Test func aDrawUnderWayWhenSharedCodeIsFoundToDifferIsDropped() async throws {
        let fixture = try RenderingFixture { request in
            request["op"] == .string("render")
                ? Self.held(FakeRender.reply(to: request)) : FakeRender.reply(to: request)
        }
        let drawing = Task { await fixture.rendering.attach(fixture.queue) }
        for _ in 0..<200 where fixture.launcher.requests.isEmpty {
            try await Task.sleep(for: .milliseconds(5))
        }
        let drift = CardDrift.between(
            bundled: CardManifest(digest: "a", entries: ["src/frame.py": "1"]),
            host: CardManifest(digest: "b", entries: ["src/frame.py": "2"]), source: .panel)
        fixture.rendering.apply(.differs(drift))
        fixture.launcher.releaseHeld()
        await drawing.value
        #expect(fixture.rendering.status == .codeDiffers(["src/frame.py"]))
        #expect(fixture.rendering.backdrop == nil)
        #expect(fixture.rendering.plates.isEmpty)
        #expect(fixture.rendering.showsBoxes)
    }

    /// `reply` held back until the launcher releases it.
    nonisolated private static func held(_ reply: ScriptedReply) -> ScriptedReply {
        guard case .answer(let header, let payload) = reply else { return reply }
        return .heldWith(header, payload: payload)
    }

    @Test func theGallerySaysWhyNoCardIsDrawn() {
        let drift = CardDrift.between(
            bundled: CardManifest(digest: "a", entries: ["src/frame.py": "1"]),
            host: CardManifest(digest: "b", entries: ["src/frame.py": "2"]), source: .panel)
        let reason = CardCodeVerdict.differs(drift).noCardsReason
        #expect(reason?.contains("src/frame.py") == true)
        #expect(reason?.contains("Deploy audio-vue") == true)
        #expect(CardCodeVerdict.same.noCardsReason == nil)
    }

    @Test func aDamagedBundleDrawsNothing() async throws {
        let fixture = try RenderingFixture()
        await fixture.rendering.attach(fixture.queue)
        fixture.rendering.apply(.damagedBundle)
        #expect(fixture.rendering.showsBoxes)
        guard case .noRenderer = fixture.rendering.status else {
            Issue.record("expected no renderer, got \(fixture.rendering.status)")
            return
        }
    }
}
