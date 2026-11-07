import CoreGraphics
import Foundation
import Testing

@testable import ConsoleCore

/// The real render helper, from `local/` as `tools/refresh-render-bundle.sh` builds it, run only
/// when `RENDER_HELPER_LIVE=1` (`commands.md`). It prints its timings.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["RENDER_HELPER_LIVE"] == "1"))
struct LiveHelperTests {
    private static let root = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()
    private static let local = root.appending(path: "local")
    private static let fixture = URL(filePath: #filePath).deletingLastPathComponent()
        .appending(path: "Fixtures/rta-scene.json")

    private static func helper() -> RenderHelper {
        RenderHelper(
            launcher: FoundationHelperLauncher(
                executable: local.appending(path: "python-runtime/bin/python3"),
                arguments: [local.appending(path: "render-bundle/src/render_service.py").path],
                caches: FileManager.default.temporaryDirectory.appending(path: "LiveHelperTests"),
                errorLine: { print("helper: \($0)") }))
    }

    /// The render request for the RTA scene at 1920 x 720, with `extra` fields.
    static func request(_ extra: [String: JSONValue] = [:]) throws -> JSONValue {
        let scene = try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: fixture))
        var fields: [String: JSONValue] = [
            "op": .string("render"), "scene": scene, "built_in": .bool(true),
            "display": .array([.integer(1920), .integer(720)]), "fonts": .object([:]),
            "rate": .integer(48000), "images": .string(NSTemporaryDirectory()),
            "fallback": .object(["color": .string("#223344")]),
        ]
        fields.merge(extra) { $1 }
        return .object(fields)
    }

    private static func timed<Value>(_ label: String, _ work: () async throws -> Value)
        async rethrows -> Value
    {
        let clock = ContinuousClock()
        let start = clock.now
        let value = try await work()
        print("\(label): \(clock.now - start)")
        return value
    }

    @Test func theHelperDrawsTheRTAScene() async throws {
        let helper = Self.helper()
        defer { Task { await helper.stop() } }
        let manifest = try JSONDecoder().decode(
            JSONValue.self,
            from: Data(contentsOf: Self.local.appending(path: "render-bundle/manifest.json")))
        let digest = try await Self.timed("hello") { try await helper.hello() }
        #expect(digest == manifest["digest"]?.stringValue)

        let whole = try await Self.timed("render, whole scene") {
            try await helper.ask(try Self.request())
        }
        let layers = try #require(whole.header["layers"]?.arrayValue)
        #expect(layers.first?["kind"] == .string("backdrop"))
        #expect(layers.count >= 2)

        let plate = try await Self.timed("render, one plate") {
            try await helper.ask(
                try Self.request(["plates": .array([.integer(0)]), "backdrop": .bool(false)]))
        }
        #expect(plate.header["layers"]?.arrayValue?.count == 1)
    }

    /// The app's compositing, `Thumbnail.flatten` at the display's own width, against audio-vue's
    /// stacking formula, `out = rgb + under * (1 - a / 255)`, in floating point (task 9.2).
    @Test func theAppsStackingIsTheFormulasWithinOneStep() async throws {
        let helper = Self.helper()
        defer { Task { await helper.stop() } }
        let answer = try await helper.ask(try Self.request())
        let layers = try RenderedLayer.layers(of: answer, cardIDs: [UUID()])
        let display = PixelSize(width: 1920, height: 720)
        let stacked = try #require(Thumbnail.flatten(layers: layers, display: display, width: 1920))
        let app = try #require(stacked.dataProvider?.data as Data?)
        let formula = Stacking.formula(layers, display: display)
        var worst = 0
        var overOne = 0
        for y in 0..<display.height {
            for x in 0..<display.width {
                for channel in 0..<3 {
                    let got = Int(app[y * stacked.bytesPerRow + x * 4 + channel])
                    let want = formula[(y * display.width + x) * 3 + channel]
                    let step = abs(got - want)
                    worst = max(worst, step)
                    if step > 1 { overOne += 1 }
                }
            }
        }
        print("stacking: worst \(worst) steps, \(overOne) channel values over one step")
        #expect(worst <= 1)
    }
}

/// audio-vue's `scene_layers.stack`, in Swift, for the comparison: premultiplied "over" in floating
/// point, rounded once at the end.
enum Stacking {
    static func formula(_ layers: [RenderedLayer], display: PixelSize) -> [Int] {
        var out = [Double](repeating: 0, count: display.width * display.height * 3)
        for layer in layers { over(layer, into: &out, width: display.width) }
        return out.map { Int(min(max($0.rounded(), 0), 255)) }
    }

    /// `layer` composited over what `out`, a display `width` pixels wide, holds.
    private static func over(_ layer: RenderedLayer, into out: inout [Double], width: Int) {
        guard let data = layer.image.dataProvider?.data as Data? else { return }
        let (left, top) = (Int(layer.rect.minX), Int(layer.rect.minY))
        for y in 0..<layer.image.height {
            for x in 0..<layer.image.width {
                let pixel = y * layer.image.bytesPerRow + x * 4
                let keep = 1 - Double(data[pixel + 3]) / 255
                let target = ((top + y) * width + left + x) * 3
                for channel in 0..<3 {
                    out[target + channel] =
                        Double(data[pixel + channel]) + out[target + channel] * keep
                }
            }
        }
    }
}
