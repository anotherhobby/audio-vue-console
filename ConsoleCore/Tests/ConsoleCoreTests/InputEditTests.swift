import Testing

@testable import ConsoleCore

/// Design D2: a write keeps the block's other keys, and the default device is the key unset.
struct InputEditTests {
    private static let pair = JSONValue.array([.integer(2), .integer(3)])

    @Test func theBlocksOtherKeysAreKept() {
        let block: [String: JSONValue] = ["pair": Self.pair, "rate": .integer(48_000)]
        let doc = InputEdit.doc(block: block, device: "hw:CARD=D10s,DEV=0", rate: 96_000)
        #expect(
            doc == [
                "pair": Self.pair, "rate": .integer(96_000),
                "device": .string("hw:CARD=D10s,DEV=0"),
            ])
    }

    @Test func theDefaultDeviceRemovesTheKey() {
        let block: [String: JSONValue] = ["device": .string("hw:CARD=D10s,DEV=0")]
        let doc = InputEdit.doc(block: block, device: nil, rate: 48_000)
        #expect(doc == ["rate": .integer(48_000)])
    }

    @Test func anEmptyBlockGainsOnlyTheRate() {
        #expect(InputEdit.doc(block: [:], device: nil, rate: 44_100) == ["rate": .integer(44_100)])
    }
}
