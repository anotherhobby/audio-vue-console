import Testing

@testable import ConsoleCore

/// Design D2: a write keeps the block's other keys, and the default device is the key unset.
/// `mac-output` design D1: the format is written beside them, and its default is the key unset.
struct InputEditTests {
    private static let pair = JSONValue.array([.integer(2), .integer(3)])

    @Test func theBlocksOtherKeysAreKept() {
        let block: [String: JSONValue] = ["pair": Self.pair, "rate": .integer(48_000)]
        let doc = InputEdit.doc(
            block: block, device: "hw:CARD=D10s,DEV=0", rate: 96_000, format: nil)
        #expect(
            doc == [
                "pair": Self.pair, "rate": .integer(96_000),
                "device": .string("hw:CARD=D10s,DEV=0"),
            ])
    }

    @Test func theDefaultDeviceRemovesTheKey() {
        let block: [String: JSONValue] = ["device": .string("hw:CARD=D10s,DEV=0")]
        let doc = InputEdit.doc(block: block, device: nil, rate: 48_000, format: nil)
        #expect(doc == ["rate": .integer(48_000)])
    }

    @Test func anEmptyBlockGainsOnlyTheRate() {
        let doc = InputEdit.doc(block: [:], device: nil, rate: 44_100, format: nil)
        #expect(doc == ["rate": .integer(44_100)])
    }

    @Test func theFormatIsSetBesideThePair() {
        let block: [String: JSONValue] = ["pair": Self.pair, "rate": .integer(96_000)]
        let doc = InputEdit.doc(block: block, device: nil, rate: 96_000, format: "S32_LE")
        #expect(
            doc == ["pair": Self.pair, "rate": .integer(96_000), "fmt": .string("S32_LE")])
    }

    @Test func theDefaultFormatRemovesTheKey() {
        let block: [String: JSONValue] = ["fmt": .string("S32_LE"), "rate": .integer(48_000)]
        let doc = InputEdit.doc(block: block, device: nil, rate: 48_000, format: nil)
        #expect(doc == ["rate": .integer(48_000)])
    }
}
