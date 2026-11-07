import Testing

@testable import ConsoleCore

/// `card-code`: the entries that differ, and which cards that makes plain boxes, each card's family
/// read from the manifest's card map.
struct CardDriftTests {
    private static let cards = [
        "waveform": "src/cards/waveform", "peak_rms": "src/cards/peak_rms",
        "peak_rms_vertical": "src/cards/peak_rms", "meter": "src/cards/meter",
    ]
    private static let bundled = CardManifest(
        digest: "app",
        entries: [
            "src/cards/waveform": "w1", "src/cards/peak_rms": "p1", "src/cards/meter": "m1",
            "src/cards/axes.py": "a1", "src/glass.py": "g1",
            "vendor/inter/Inter-Medium.ttf": "f1",
        ], cards: cards)

    private static func drift(_ changes: [String: String]) -> CardDrift {
        var entries = bundled.entries
        for (key, value) in changes { entries[key] = value }
        return CardDrift.between(
            bundled: bundled, host: CardManifest(digest: "host", entries: entries, cards: cards),
            source: .panel)
    }

    @Test func oneFamilyDiffering() {
        let drift = Self.drift(["src/cards/waveform": "w2"])
        #expect(drift.families == ["waveform"])
        #expect(drift.shared.isEmpty)
        #expect(drift.boxes("waveform"))
        #expect(!drift.boxes("meter"))
    }

    @Test func aCardDeclaredInAnotherFamilyFollowsIt() {
        let drift = Self.drift(["src/cards/peak_rms": "p2"])
        #expect(drift.boxes("peak_rms_vertical"))
        #expect(drift.boxes("peak_rms"))
        #expect(!drift.boxes("meter") && !drift.boxes("waveform"))
    }

    @Test func aSharedCardModuleIsShared() {
        let drift = Self.drift(["src/cards/axes.py": "a2"])
        #expect(drift.families.isEmpty)
        #expect(drift.shared == ["src/cards/axes.py"])
        #expect(drift.sharesNothing)
    }

    @Test func aFontDifferingIsShared() {
        #expect(Self.drift(["vendor/inter/Inter-Medium.ttf": "f2"]).sharesNothing)
    }

    @Test func aCardNeitherManifestDeclaresIsABox() {
        #expect(Self.drift(["src/cards/waveform": "w2"]).boxes("radar"))
    }

    @Test func theHostsFilesAreSaid() {
        let drift = CardDrift.between(
            bundled: Self.bundled,
            host: CardManifest(digest: "h", entries: Self.bundled.entries, cards: Self.cards),
            source: .host)
        #expect(drift.source == .host)
    }

    @Test func aLongListIsCounted() {
        #expect(CardDrift.listed(["a", "b"]) == "a, b")
        #expect(CardDrift.listed(["a", "b", "c"]) == "a, b, c")
        #expect(CardDrift.listed(["a", "b", "c", "d", "e"]) == "a, b, c and 2 more")
    }
}
