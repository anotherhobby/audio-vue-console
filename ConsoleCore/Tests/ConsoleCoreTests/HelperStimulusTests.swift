import Foundation
import Testing

@testable import ConsoleCore

/// The helper's `stimulus` request and the app's stimulus made with it (design D4).
struct HelperStimulusTests {
    @Test func theRequestStatesTheRunAndThePath() async throws {
        let launcher = ScriptedLauncher { _ in .answer(#"{"ok": true}"#) }
        let run = StatedRun(kind: .characterization, rate: 96_000)
        try await RenderHelper(launcher: launcher).stimulus(run, to: URL(filePath: "/tmp/s.wav"))
        let request = try #require(launcher.requests.first)
        #expect(
            request
                == .object([
                    "op": .string("stimulus"), "kind": .string("characterization"),
                    "rate": .integer(96_000), "path": .string("/tmp/s.wav"),
                ]))
    }

    @Test func aRefusalIsThrownWithThePanelsWords() async throws {
        let message = "file_rate must be one of [44100, 48000, 88200, 96000, 192000]"
        let refusal = #"{"ok": false, "refused": "\#(message)"}"#
        let launcher = ScriptedLauncher { _ in .answer(refusal) }
        let stimulus = HelperStimulus(
            helper: RenderHelper(launcher: launcher), directory: Self.scratch())
        await #expect(throws: StimulusFailure.refused(message)) {
            _ = try await stimulus.file(for: StatedRun(rate: 22_050))
        }
    }

    @Test func anErrorIsAFailure() async throws {
        let launcher = ScriptedLauncher { _ in
            .answer(#"{"ok": false, "error": "PermissionError: denied"}"#)
        }
        let stimulus = HelperStimulus(
            helper: RenderHelper(launcher: launcher), directory: Self.scratch())
        await #expect(throws: StimulusFailure.failed("PermissionError: denied")) {
            _ = try await stimulus.file(for: StatedRun(rate: 96_000))
        }
    }

    @Test func aDoneFileIsInTheGivenDirectory() async throws {
        let directory = Self.scratch()
        let launcher = ScriptedLauncher { _ in .answer(#"{"ok": true}"#) }
        let file = try await HelperStimulus(
            helper: RenderHelper(launcher: launcher), directory: directory
        ).file(for: StatedRun(rate: 96_000))
        #expect(file.deletingLastPathComponent().lastPathComponent == directory.lastPathComponent)
        #expect(file.pathExtension == "wav")
    }

    private static func scratch() -> URL {
        FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    }
}
