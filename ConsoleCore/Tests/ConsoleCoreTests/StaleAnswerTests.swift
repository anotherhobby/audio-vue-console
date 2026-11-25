import Foundation
import Synchronization
import Testing

@testable import ConsoleCore

/// `scene-rendering`, "A resize draws the plate again at each cell step": each step's redraw is sent
/// from its own task, and the tasks reach the queue in no set order, so an older request can
/// replace a newer one under their shared key and land last. The plate it leaves out of date is
/// drawn again at the cells now shown.
@MainActor
struct StaleAnswerTests {
    /// Whether the fixture holds its next plate request: off while the scene is first drawn.
    private final class Armed: Sendable {
        private let state = Mutex(false)

        func arm() { state.withLock { $0 = true } }

        /// True once armed, for the first call after.
        func fire() -> Bool {
            state.withLock { armed in
                defer { armed = false }
                return armed
            }
        }
    }

    /// A fixture whose first request for one plate alone, on the grid or parked, after `armed` is
    /// armed, is held until released.
    private static func holdingFirstPlate(_ armed: Armed) throws -> RenderingFixture {
        try RenderingFixture { request in
            let reply = FakeRender.reply(to: request)
            guard request["plates"] != nil, case .answer(let header, let payload) = reply,
                armed.fire()
            else { return reply }
            return .heldWith(header, payload: payload)
        }
    }

    /// Lets the newer show's request be replaced by one sent later under `key`, as an older
    /// request reaching the queue last would, then releases the held answer.
    private static func replaceTheNewer(
        _ fixture: RenderingFixture, key: String, newer: Task<Void, Never>
    ) async throws {
        for _ in 0..<pollLimit where fixture.queue.waiting < 1 {
            try await Task.sleep(for: .milliseconds(pollMilliseconds))
        }
        let late = Task { await fixture.queue.submit(.object([:]), lane: .canvas, key: key) }
        await newer.value
        fixture.launcher.releaseHeld()
        _ = await late.value
    }

    private static let pollLimit = 2_000
    private static let pollMilliseconds = 5

    @Test func aPlateLeftAtAnOlderSizeIsDrawnAgain() async throws {
        let armed = Armed()
        let fixture = try Self.holdingFirstPlate(armed)
        await fixture.rendering.attach(fixture.queue)
        armed.arm()
        let meter = try #require(fixture.layout.cards.first)
        let grown = { (rows: Int) throws -> SceneLayout in
            try fixture.layout.resizing(
                meter.id, edges: .bottom, by: CellOffset(cols: 0, rows: rows))
        }
        let (older, newest) = (try grown(2), try grown(4))
        let olderShow = Task { await fixture.rendering.show(fixture.content(older)) }
        try await fixture.launcher.untilHolding()
        let newerShow = Task { await fixture.rendering.show(fixture.content(newest)) }
        try await Self.replaceTheNewer(
            fixture, key: "plate:" + meter.id.uuidString, newer: newerShow)
        await olderShow.value
        #expect(fixture.rendering.plates[[meter.id]]?.cells == newest.card(meter.id)?.cells)
    }

    @Test func aParkedPlateLeftAtAnOlderSizeIsDrawnAgain() async throws {
        let armed = Armed()
        let fixture = try Self.holdingFirstPlate(armed)
        let tiny = try #require(fixture.layout.cards.last)
        let parked = try fixture.content(fixture.layout).dragging(
            [tiny.id], by: CellOffset(cols: 0, rows: 40), within: testPane)
        await fixture.rendering.show(parked)
        await fixture.rendering.attach(fixture.queue)
        armed.arm()
        let grown = { (cols: Int) throws -> SceneContent in
            try parked.resizing(
                tiny.id, edges: .right, by: CellOffset(cols: cols, rows: 0), floor: .oneCell,
                within: testPane)
        }
        let (older, newest) = (try grown(2), try grown(4))
        let olderShow = Task { await fixture.rendering.show(older) }
        try await fixture.launcher.untilHolding()
        let newerShow = Task { await fixture.rendering.show(newest) }
        try await Self.replaceTheNewer(
            fixture, key: "parked:" + tiny.id.uuidString, newer: newerShow)
        await olderShow.value
        let held = try #require(fixture.rendering.parked.layers[[tiny.id]])
        #expect(held.cells.cols == newest.card(tiny.id)?.cells.cols)
    }
}
