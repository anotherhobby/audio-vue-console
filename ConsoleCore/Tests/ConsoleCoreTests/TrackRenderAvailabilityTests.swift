import Testing

@testable import ConsoleCore

/// `track-render`, "Render with Track says why it cannot be used" and "Nothing is rendered where
/// the card code differs".
struct TrackRenderAvailabilityTests {
    private static let cards = ["meter": "src/cards/meter", "rta_bars": "src/cards/rta_bars"]
    private static let bundled = CardManifest(
        digest: "a",
        entries: ["src/frame.py": "1", "src/cards/meter": "1", "src/cards/rta_bars": "1"],
        cards: cards)

    /// The drift where `entry` differs on the panel.
    private static func drift(_ entry: String) -> CardCodeVerdict {
        var entries = bundled.entries
        entries[entry] = "2"
        let host = CardManifest(digest: "b", entries: entries, cards: cards)
        return .differs(CardDrift.between(bundled: bundled, host: host, source: .panel))
    }

    /// A scene that can be rendered; each test changes one fact of it.
    private static let ready = TrackRenderAvailability.Facts(
        isPaired: true, carriesRenderer: true, rates: [48_000], isTooWide: false, cards: ["meter"],
        verdict: .same)

    /// `ready` with `change` made to it.
    private static func facts(
        _ change: (inout TrackRenderAvailability.Facts) -> Void = { _ in }
    ) -> TrackRenderAvailability.Facts {
        var facts = ready
        change(&facts)
        return facts
    }

    private static func reason(_ facts: TrackRenderAvailability.Facts) -> String? {
        TrackRenderAvailability.reason(facts) { $0 == "meter" ? "Meter" : $0 }
    }

    @Test func aSceneThePanelRunsTheCodeForCanBeRendered() {
        #expect(Self.reason(Self.facts()) == nil)
    }

    @Test func notPaired() {
        #expect(
            Self.reason(Self.facts { $0.isPaired = false })
                == "Pair with a panel to render from a track")
    }

    @Test func noRenderer() {
        #expect(
            Self.reason(Self.facts { $0.carriesRenderer = false })
                == "This build carries no renderer")
    }

    @Test func noRates() {
        #expect(Self.reason(Self.facts { $0.rates = nil }) == "The panel's rates can't be read")
    }

    @Test func noCard() {
        #expect(Self.reason(Self.facts { $0.cards = [] }) == "Add a card to render from a track")
    }

    @Test func tooWide() {
        #expect(
            Self.reason(Self.facts { $0.isTooWide = true })
                == "This scene is too wide for the panel")
    }

    @Test func notYetChecked() {
        #expect(Self.reason(Self.facts { $0.verdict = nil }) == "Checking the renderer's code…")
    }

    @Test func sharedCodeThatDiffers() {
        let reason = Self.reason(Self.facts { $0.verdict = Self.drift("src/frame.py") })
        #expect(reason?.hasPrefix("This app's code for src/frame.py differs") == true)
    }

    @Test func aCardTheSceneHoldsWhoseCodeDiffers() {
        #expect(
            Self.reason(
                Self.facts {
                    $0.cards = ["meter", "meter"]
                    $0.verdict = Self.drift("src/cards/meter")
                })
                == "This app's code for Meter differs from the panel's, "
                + "so this scene can't be rendered from a track")
    }

    @Test func aCardTheSceneDoesNotHoldMayDiffer() {
        #expect(Self.reason(Self.facts { $0.verdict = Self.drift("src/cards/rta_bars") }) == nil)
    }

    @Test func aDamagedOrUnreadableBundle() {
        #expect(
            Self.reason(Self.facts { $0.verdict = .damagedBundle })
                == CardCodeVerdict.damagedBundle.noCardsReason)
        #expect(
            Self.reason(Self.facts { $0.verdict = .unreadable })
                == CardCodeVerdict.unreadable.noCardsReason)
    }
}
