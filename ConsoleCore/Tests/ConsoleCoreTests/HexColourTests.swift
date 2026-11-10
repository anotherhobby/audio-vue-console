import Foundation
import Testing

@testable import ConsoleCore

/// `card-settings`, "A colour is picked with the system colour panel": a colour's hex survives the
/// trip through sRGB components (design D8).
struct HexColourTests {
    @Test func aHexRoundTripsUpperCased() throws {
        let colour = try #require(HexColour("#2a3550"))
        #expect(colour.hex == "#2A3550")
        #expect(colour.red == 0x2A / 255.0)
    }

    /// 4,096 colours: every component at each of 16 levels, 17 apart, from 00 to FF.
    @Test func everySampledHexRoundTripsUnchanged() {
        let samples = (0..<4_096).map { index in
            let bytes = [index >> 8, index >> 4, index].map { ($0 & 15) * 17 }
            return "#" + bytes.map { String(format: "%02X", $0) }.joined()
        }
        #expect(Set(samples).count == 4_096)
        let changed = samples.contains { text in HexColour(text)?.hex != text }
        #expect(!changed)
    }

    @Test func componentsOutOfRangeAreClamped() {
        #expect(HexColour(red: 0.999, green: -0.01, blue: 1.5).hex == "#FF00FF")
    }

    @Test func anythingButSixHexDigitsIsRefused() {
        #expect(HexColour("#2a355") == nil)
        #expect(HexColour("2a3550") == nil)
        #expect(HexColour("#2a355g") == nil)
        #expect(HexColour("#+2a355") == nil)
    }
}
