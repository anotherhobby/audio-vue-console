import Foundation
import Testing

@testable import ConsoleCore

/// The render helper's framing (audio-vue `scene-render`, "The helper speaks over its standard
/// streams").
struct HelperFrameTests {
    /// An answer as the helper writes it: the framed header, then `payload`.
    static func framed(_ header: String, payload: Data = Data()) -> Data {
        let body = Data(header.utf8)
        let length = UInt32(body.count).bigEndian
        return withUnsafeBytes(of: length) { Data($0) } + body + payload
    }

    private static let layered =
        #"{"ok": true, "layers": [{"kind": "backdrop", "bytes": 4}, {"kind": "plate", "bytes": 8}]}"#

    @Test func aRequestIsFramed() throws {
        let data = try HelperFrame.encode(.object(["op": .string("hello")]))
        #expect(data.prefix(4) == Data([0, 0, 0, 14]))
        #expect(String(bytes: data.dropFirst(4), encoding: .utf8) == #"{"op":"hello"}"#)
    }

    @Test func anAnswerArrivingWhole() throws {
        var reader = HelperAnswerReader()
        reader.append(Self.framed(#"{"ok": true, "cards": "d"}"#))
        let answer = try #require(try reader.next())
        #expect(answer.header["cards"] == .string("d"))
        #expect(answer.payload.isEmpty)
        #expect(try reader.next() == nil)
    }

    @Test func aHeaderSplitAcrossChunks() throws {
        let whole = Self.framed(#"{"ok": true}"#)
        var reader = HelperAnswerReader()
        reader.append(whole.prefix(2))
        #expect(try reader.next() == nil)
        reader.append(whole.dropFirst(2).prefix(5))
        #expect(try reader.next() == nil)
        reader.append(whole.dropFirst(7))
        #expect(try reader.next()?.header["ok"] == .bool(true))
    }

    @Test func aPayloadSplitMidLayer() throws {
        let payload = Data((0..<12).map(UInt8.init))
        let whole = Self.framed(Self.layered, payload: payload)
        var reader = HelperAnswerReader()
        reader.append(whole.dropLast(6))
        #expect(try reader.next() == nil)
        reader.append(whole.suffix(6))
        #expect(try reader.next()?.payload == payload)
    }

    @Test func twoAnswersInOneChunk() throws {
        var reader = HelperAnswerReader()
        reader.append(Self.framed(#"{"n": 1}"#) + Self.framed(#"{"n": 2}"#))
        #expect(try reader.next()?.header["n"] == .integer(1))
        #expect(try reader.next()?.header["n"] == .integer(2))
    }

    @Test func aHeaderThatIsNotJSON() {
        var reader = HelperAnswerReader()
        reader.append(Self.framed("not json"))
        #expect(throws: HelperFrameError.malformed) { try reader.next() }
    }
}
