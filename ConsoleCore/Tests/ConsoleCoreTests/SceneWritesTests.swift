import Foundation
import Testing

@testable import ConsoleCore

/// `scene-saving`: each write's outcome reaches the drafts and the thumbnails.
@MainActor
struct SceneWritesTests {
    private static func writes(_ scenes: PanelScenes) -> SceneWrites {
        SceneWrites(scenes: scenes, drafts: SceneDrafts(), thumbnails: SceneThumbnails())
    }

    @Test func aSaveLeavesTheSceneNotUnsaved() async throws {
        let (scenes, transport) = try await PanelScenesTests.loadedWithMine()
        let writes = Self.writes(scenes)
        _ = try PanelScenesTests.movedDraft("u1", in: scenes, drafts: writes.drafts)
        await transport.answer(.writeScene("u1"), with: .status(200, PanelScenesTests.written))
        await transport.answer(.scene("u1"), with: PanelScenesTests.mine(rev: 4, col: 10))
        _ = try await writes.save("u1")
        #expect(writes.drafts.draft("u1")?.isUnsaved == false)
        #expect(writes.drafts.unsaved(scenes.scenes).isEmpty)
    }

    @Test func aFailedSaveKeepsTheEdits() async throws {
        let (scenes, transport) = try await PanelScenesTests.loadedWithMine()
        let writes = Self.writes(scenes)
        _ = try PanelScenesTests.movedDraft("u1", in: scenes, drafts: writes.drafts)
        await transport.answer(.writeScene("u1"), with: .failure(URLError(.timedOut)))
        await #expect(throws: HostFailure.unreachable) { _ = try await writes.save("u1") }
        #expect(writes.drafts.draft("u1")?.isUnsaved == true)
    }

    @Test func saveAllStopsAtTheFirstFailure() async throws {
        let (scenes, transport) = try await PanelScenesTests.loadedWithMine()
        let writes = Self.writes(scenes)
        _ = try PanelScenesTests.movedDraft("u1", in: scenes, drafts: writes.drafts)
        let body = #"{"detail": "invalid", "failures": [{"place": "", "message": "bad"}]}"#
        await transport.answer(.writeScene("u1"), with: .status(422, body))
        let failure = HostFailure.invalid([DocumentFailure(place: "", message: "bad")])
        await #expect(throws: SceneWrites.Failed(id: "u1", name: "Mine", failure: failure)) {
            try await writes.saveAll()
        }
    }

    @Test func applyWritesAnEditThenSwitches() async throws {
        let (scenes, transport) = try await PanelScenesTests.loadedWithMine()
        let writes = Self.writes(scenes)
        _ = try PanelScenesTests.movedDraft("u1", in: scenes, drafts: writes.drafts)
        await transport.answer(.writeScene("u1"), with: .status(200, PanelScenesTests.written))
        await transport.answer(.scene("u1"), with: PanelScenesTests.mine(rev: 4, col: 10))
        await transport.answer(.switchScene, with: .status(200, #"{"status": "done"}"#))
        let applied = try await writes.apply("u1")
        #expect(applied.id == "u1" && applied.outcome == .success(.done(nil)))
        let paths = await transport.requests.compactMap {
            "\($0.httpMethod ?? "") \($0.url?.path() ?? "")"
        }
        let write = try #require(paths.firstIndex(of: "PUT /v1/scenes/u1"))
        let switched = try #require(paths.firstIndex(of: "POST /v1/commands/switch"))
        #expect(write < switched)
        #expect(writes.drafts.draft("u1")?.isUnsaved == false)
    }

    @Test func applyOnlySwitchesAScenesWithNothingToSave() async throws {
        let (scenes, transport) = try await PanelScenesTests.loadedWithMine()
        let writes = Self.writes(scenes)
        let mine = try #require(scenes.scenes.last)
        _ = try writes.drafts.draft(for: mine, defaultGrid: CellSize(cols: 64, rows: 36))
        await transport.answer(.switchScene, with: .status(200, #"{"status": "done"}"#))
        _ = try await writes.apply("u1")
        #expect(await transport.requests(to: .writeScene("u1")).isEmpty)
        #expect(await transport.requests(to: .switchScene).count == 1)
    }

    @Test func aRefusedSaveSendsNoSwitch() async throws {
        let (scenes, transport) = try await PanelScenesTests.loadedWithMine()
        let writes = Self.writes(scenes)
        _ = try PanelScenesTests.movedDraft("u1", in: scenes, drafts: writes.drafts)
        let body = #"{"detail": "invalid", "failures": [{"place": "", "message": "bad"}]}"#
        await transport.answer(.writeScene("u1"), with: .status(422, body))
        await #expect(throws: HostFailure.invalid([DocumentFailure(place: "", message: "bad")])) {
            _ = try await writes.apply("u1")
        }
        #expect(await transport.requests(to: .switchScene).isEmpty)
    }

    @Test func aRefusedSwitchKeepsTheSave() async throws {
        let (scenes, transport) = try await PanelScenesTests.loadedWithMine()
        let writes = Self.writes(scenes)
        _ = try PanelScenesTests.movedDraft("u1", in: scenes, drafts: writes.drafts)
        await transport.answer(.writeScene("u1"), with: .status(200, PanelScenesTests.written))
        await transport.answer(.scene("u1"), with: PanelScenesTests.mine(rev: 4, col: 10))
        let refused = #"{"status": "refused", "reason": "a calibration has the panel"}"#
        await transport.answer(.switchScene, with: .status(409, refused))
        let applied = try await writes.apply("u1")
        #expect(applied.outcome == .success(.refused("a calibration has the panel")))
        #expect(writes.drafts.draft("u1")?.isUnsaved == false)
        #expect(scenes.scenes.last?.rev == 4)
    }

    @Test func aCopysApplyGivesTheHostsIDEvenWhenTheSwitchFails() async throws {
        let (scenes, transport) = try await PanelScenesTests.loadedWithMine()
        let writes = Self.writes(scenes)
        let mine = try #require(scenes.scenes.last)
        let copy = writes.drafts.duplicate(
            try writes.drafts.draft(for: mine, defaultGrid: CellSize(cols: 64, rows: 36)),
            among: scenes.scenes)
        let created = #"{"id": "u2", "rev": 1, "applies": "on_reload", "analysis_changed": false}"#
        await transport.answer(.createScene, with: .status(201, created))
        await transport.answer(
            .scene("u2"),
            with: .status(
                200, #"{"id": "u2", "name": "Mine copy", "built_in": false, "rev": 1, "doc": {}}"#))
        await transport.answer(.switchScene, with: .failure(URLError(.timedOut)))
        let applied = try await writes.apply(copy.id)
        #expect(applied.id == "u2")
        #expect(applied.outcome == .failure(.unreachable))
    }

    @Test func aCopyIsRenamedAndDeletedWithNoRequest() async throws {
        let (scenes, transport) = try await PanelScenesTests.loadedWithMine()
        let writes = Self.writes(scenes)
        let mine = try #require(scenes.scenes.last)
        let draft = try writes.drafts.draft(for: mine, defaultGrid: CellSize(cols: 64, rows: 36))
        let copy = writes.drafts.duplicate(draft, among: scenes.scenes)
        let before = await transport.requests.count
        try await writes.rename(copy.id, to: " Wide ")
        #expect(writes.drafts.copies.first?.name == "Wide")
        try await writes.delete(copy.id)
        #expect(writes.drafts.copies.isEmpty)
        #expect(await transport.requests.count == before)
    }

    @Test func discardMineReadsTheHostsSceneAgain() async throws {
        let (scenes, transport) = try await PanelScenesTests.loadedWithMine()
        let writes = Self.writes(scenes)
        _ = try PanelScenesTests.movedDraft("u1", in: scenes, drafts: writes.drafts)
        await transport.answer(.scene("u1"), with: PanelScenesTests.mine(rev: 4, col: 20))
        try await writes.discardMine("u1")
        #expect(writes.drafts.draft("u1") == nil)
        #expect(scenes.scenes.last?.rev == 4)
    }

    @Test func discardAllDropsEveryUnsavedScene() async throws {
        let (scenes, _) = try await PanelScenesTests.loadedWithMine()
        let writes = Self.writes(scenes)
        let draft = try PanelScenesTests.movedDraft("u1", in: scenes, drafts: writes.drafts)
        _ = writes.drafts.duplicate(draft, among: scenes.scenes)
        writes.discardAll()
        #expect(writes.drafts.unsaved(scenes.scenes).isEmpty)
        #expect(writes.drafts.copies.isEmpty)
    }
}
