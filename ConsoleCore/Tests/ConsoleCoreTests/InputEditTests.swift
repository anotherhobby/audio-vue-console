import Testing

@testable import ConsoleCore

/// Design D2: a write keeps the block's other keys, and the default device is the key unset.
/// `mac-output` design D1: the format is written beside them, and its default is the key unset.
/// `input-channels`: so is the pair.
struct InputEditTests {
    private static let pair = JSONValue.array([.integer(2), .integer(3)])

    private static func doc(_ block: [String: JSONValue], _ choice: InputChoice)
        -> [String: JSONValue]
    {
        InputEdit.doc(block: block, choice: choice, defaultPair: [0, 1])
    }

    @Test func theBlocksOtherKeysAreKept() {
        let block: [String: JSONValue] = ["extra": .bool(true), "rate": .integer(48_000)]
        let doc = Self.doc(block, InputChoice(device: "hw:CARD=D10s,DEV=0", rate: 96_000))
        #expect(
            doc == [
                "extra": .bool(true), "rate": .integer(96_000),
                "device": .string("hw:CARD=D10s,DEV=0"),
            ])
    }

    @Test func theDefaultDeviceRemovesTheKey() {
        let block: [String: JSONValue] = ["device": .string("hw:CARD=D10s,DEV=0")]
        #expect(Self.doc(block, InputChoice(rate: 48_000)) == ["rate": .integer(48_000)])
    }

    @Test func anEmptyBlockGainsOnlyTheRate() {
        #expect(Self.doc([:], InputChoice(rate: 44_100)) == ["rate": .integer(44_100)])
    }

    @Test func theFormatIsSetBesideThePair() {
        let block: [String: JSONValue] = ["pair": Self.pair, "rate": .integer(96_000)]
        let doc = Self.doc(block, InputChoice(rate: 96_000, format: "S32_LE", pair: [2, 3]))
        #expect(
            doc == ["pair": Self.pair, "rate": .integer(96_000), "fmt": .string("S32_LE")])
    }

    @Test func theDefaultFormatRemovesTheKey() {
        let block: [String: JSONValue] = ["fmt": .string("S32_LE"), "rate": .integer(48_000)]
        #expect(Self.doc(block, InputChoice(rate: 48_000)) == ["rate": .integer(48_000)])
    }

    @Test func theDefaultPairRemovesTheKey() {
        let block: [String: JSONValue] = ["pair": Self.pair, "rate": .integer(48_000)]
        #expect(Self.doc(block, InputChoice(rate: 48_000)) == ["rate": .integer(48_000)])
    }
}

/// `input-channels`: what a device streams narrows what is offered, and a choice is fitted to it.
struct CaptureDeviceTests {
    /// The miniDSP 2x4HD: 24 bits in 32, four channels.
    private static let four = CaptureDevice(
        name: "hw:CARD=m2x4HD,DEV=0",
        streams: [.init(format: "S32_LE", channels: 4, rates: [44_100, 48_000, 96_000, 192_000])])
    /// A UCA202: 16 bits and a format the panel does not capture, one or two channels, to 48 kHz.
    private static let two = CaptureDevice(
        name: "hw:CARD=CODEC,DEV=0",
        streams: [
            .init(format: "S16_LE", channels: 2, rates: [8_000, 44_100, 48_000]),
            .init(format: "S16_LE", channels: 1, rates: [44_100, 48_000]),
            .init(format: "S8", channels: 2, rates: [8_000, 48_000]),
        ])
    private static let formats = ["S16_LE", "S32_LE"]
    private static let rates = [44_100, 48_000, 88_200, 96_000, 192_000]

    @Test func theFormatsOfferedAreThoseTheDeviceAndThePanelShare() {
        #expect(Self.four.formats(among: Self.formats) == ["S32_LE"])
        #expect(Self.two.formats(among: Self.formats) == ["S16_LE"])
    }

    @Test func theRatesOfferedAreThoseTheDeviceTakesInTheFormat() {
        #expect(Self.two.rates(among: Self.rates, format: "S16_LE") == [44_100, 48_000])
        #expect(Self.four.rates(among: Self.rates, format: "S32_LE").count == 4)
        #expect(Self.four.rates(among: Self.rates, format: "S16_LE").isEmpty)
    }

    @Test func theChannelsAreTheMostAmongTheWaysTakingTheFormatAndRate() {
        #expect(Self.four.channels(format: "S32_LE", rate: 96_000) == 4)
        #expect(Self.two.channels(format: "S16_LE", rate: 48_000) == 2)
        #expect(Self.two.channels(format: "S16_LE", rate: 96_000) == nil)
    }

    @Test func aDeviceWhoseWaysAreNotKnownOffersEverything() {
        let unknown = CaptureDevice(name: "hw:CARD=X,DEV=0")
        #expect(unknown.formats(among: Self.formats) == Self.formats)
        #expect(unknown.rates(among: Self.rates, format: "S16_LE") == Self.rates)
        #expect(unknown.channels(format: "S16_LE", rate: 48_000) == nil)
    }

    @Test func aChoiceIsFittedToTheFourChannelDevice() {
        let picked = InputChoice(device: Self.four.name, rate: 96_000, format: "S16_LE")
        let fitted = picked.fitted(to: Self.four, formats: Self.formats, rates: Self.rates)
        #expect(fitted == InputChoice(device: Self.four.name, rate: 96_000, format: "S32_LE"))
    }

    @Test func aChoiceBeyondTheDeviceTakesItsNearestRateAndFirstPair() {
        let picked = InputChoice(
            device: Self.two.name, rate: 96_000, format: "S32_LE", pair: [2, 3])
        let fitted = picked.fitted(to: Self.two, formats: Self.formats, rates: Self.rates)
        #expect(fitted == InputChoice(device: Self.two.name, rate: 48_000, format: "S16_LE"))
    }

    @Test func aPairWithinTheChannelsIsKept() {
        let picked = InputChoice(
            device: Self.four.name, rate: 96_000, format: "S32_LE", pair: [3, 2])
        #expect(picked.fitted(to: Self.four, formats: Self.formats, rates: Self.rates) == picked)
    }

    @Test func theDefaultDeviceChangesNothing() {
        let picked = InputChoice(rate: 96_000, format: "S16_LE", pair: [2, 3])
        #expect(picked.fitted(to: nil, formats: Self.formats, rates: Self.rates) == picked)
    }
}
