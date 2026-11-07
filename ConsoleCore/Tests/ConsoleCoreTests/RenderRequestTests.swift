import CoreGraphics
import Foundation
import Testing

@testable import ConsoleCore

/// `scene-rendering`: what a request carries, and how an answer's layers are read.
struct RenderRequestTests {
    static let context = RenderContext(
        display: PixelSize(width: 1920, height: 720), fonts: .object(["value_px": .integer(80)]),
        images: URL(filePath: "/tmp/images"), fallback: .object(["color": .string("#223344")]))

    @Test func theRequestCarriesTheHelpersFields() {
        let doc = JSONValue.object(["cards": .array([])])
        let message = RenderRequest(doc: doc, builtIn: true, context: Self.context).message
        #expect(message["op"] == .string("render"))
        #expect(message["scene"] == doc)
        #expect(message["built_in"] == .bool(true))
        #expect(message["display"] == .array([.integer(1920), .integer(720)]))
        #expect(message["fonts"]?["value_px"] == .integer(80))
        #expect(message["rate"] == .integer(48_000))
        #expect(message["images"] == .string("/tmp/images"))
        #expect(message["fallback"]?["color"] == .string("#223344"))
        #expect(message["backdrop"] == .bool(true))
        #expect(message["plates"] == nil)
    }

    @Test func namedPlatesWithoutTheBackdrop() {
        let message = RenderRequest(
            doc: .object([:]), builtIn: false, context: Self.context, plates: [2, 0],
            backdrop: false
        ).message
        #expect(message["plates"] == .array([.integer(2), .integer(0)]))
        #expect(message["backdrop"] == .bool(false))
    }
}

struct RenderedLayerTests {
    private static let pixels = Data([
        255, 0, 0, 255, 0, 128, 0, 128,
        0, 0, 0, 0, 10, 20, 30, 40,
    ])

    @Test func aLayerIsReadWithItsPixels() throws {
        let ids = [UUID(), UUID()]
        let header =
            #"{"ok": true, "layers": [{"kind": "plate", "placements": [1], "rect": [10, 20, 2, 2], "#
            + #""unfit": ["waveform"], "bytes": 16}]}"#
        let answer = HelperAnswer(
            header: try JSONDecoder().decode(JSONValue.self, from: Data(header.utf8)),
            payload: Self.pixels)
        let layer = try #require(try RenderedLayer.layers(of: answer, cardIDs: ids).first)
        #expect(layer.kind == .plate)
        #expect(layer.cardIDs == [ids[1]])
        #expect(layer.rect == CGRect(x: 10, y: 20, width: 2, height: 2))
        #expect(layer.unfit == ["waveform"])
        #expect(layer.image.width == 2 && layer.image.height == 2)
        #expect(layer.image.alphaInfo == .premultipliedLast)
        #expect(layer.image.dataProvider?.data as Data? == Self.pixels)
    }

    @Test func aLayerWhoseBytesDoNotFitItsRect() throws {
        let header =
            #"{"layers": [{"kind": "backdrop", "placements": [], "rect": [0, 0, 3, 3], "#
            + #""unfit": [], "bytes": 16}]}"#
        let answer = HelperAnswer(
            header: try JSONDecoder().decode(JSONValue.self, from: Data(header.utf8)),
            payload: Self.pixels)
        #expect(throws: RenderFailure.ended) { try RenderedLayer.layers(of: answer, cardIDs: []) }
    }
}
