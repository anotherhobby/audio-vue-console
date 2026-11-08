import ConsoleCore
import SwiftUI

/// What the editor's banner says (design D7): the last Apply's or Reset's outcome, or, where the
/// scene was saved while on screen, that the panel shows an earlier version (`scene-apply`).
enum EditorBannerText {
    static let behind =
        "The panel shows an earlier version of this scene. Apply puts this one up."

    static func text(_ note: EditorNote) -> String {
        switch (note.kind, note.result) {
        case (.apply, .success(let outcome)): applied(outcome)
        case (.reset, .success(let outcome)): reset(outcome)
        case (.apply, .failure(let failure)):
            "The panel couldn't be asked to switch. \(failed(failure))"
        case (.reset, .failure(let failure)):
            "The panel couldn't be asked to reset. \(failed(failure))"
        }
    }

    /// Why a command couldn't be sent. Unlike a write's failure, it says nothing of edits: Apply
    /// has saved by then, and Reset touches none.
    private static func failed(_ failure: HostFailure) -> String {
        switch failure {
        case .unreachable: "The host couldn't be reached."
        case .tokenRefused: "The host no longer takes this app's pairing. Pair again."
        default: "The host answered in a way this app didn't expect."
        }
    }

    private static func applied(_ outcome: CommandOutcome) -> String {
        switch outcome {
        case .done(nil): "The scene is on the panel."
        case .done(let result?): "The scene is on the panel. " + cost(result)
        case .refused(let reason): "The panel didn't switch: \(reason)"
        case .noPanel: "No panel answered, so it didn't switch. The scene is saved."
        case .expired(let reason), .unknown(let reason):
            "The panel may or may not have switched: \(reason)"
        }
    }

    /// What a done switch cost: capture kept, or rebuilt and why, and a start not recorded.
    private static func cost(_ result: SwitchResult) -> String {
        let capture =
            switch result.capture {
            case .kept: "Capture was kept."
            case .rebuilt:
                "Capture was rebuilt, so history restarted"
                    + (result.why.map { ": \($0)." } ?? ".")
            }
        return result.recorded ? capture : capture + " The panel won't start on this scene."
    }

    static func reset(_ outcome: CommandOutcome) -> String {
        switch outcome {
        case .done: "The panel's measurement was reset."
        case .refused(let reason): "The panel didn't reset: \(reason)"
        case .noPanel: "No panel answered, so nothing was reset."
        case .expired(let reason), .unknown(let reason):
            "The panel may or may not have reset: \(reason)"
        }
    }
}

/// One line under the editor's toolbar.
struct EditorBanner: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "info.circle")
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, SceneMetrics.tilePadding)
            .background(.bar)
    }
}

#Preview("Banner, each outcome") {
    let notes: [EditorNote] = [
        EditorNote(kind: .apply, result: .success(.done(nil))),
        EditorNote(
            kind: .apply,
            result: .success(.done(SwitchResult(capture: .kept, why: nil, recorded: true)))),
        EditorNote(
            kind: .apply,
            result: .success(
                .done(
                    SwitchResult(
                        capture: .rebuilt, why: "a card wants 60 s of history, 30 s is running",
                        recorded: true)))),
        EditorNote(
            kind: .apply,
            result: .success(.done(SwitchResult(capture: .kept, why: nil, recorded: false)))),
        EditorNote(kind: .apply, result: .success(.refused("a calibration has the panel"))),
        EditorNote(kind: .apply, result: .success(.noPanel)),
        EditorNote(kind: .apply, result: .success(.expired("the panel didn't answer in time"))),
        EditorNote(kind: .apply, result: .failure(.unreachable)),
        EditorNote(kind: .reset, result: .success(.done(nil))),
        EditorNote(kind: .reset, result: .failure(.unexpectedAnswer)),
    ]
    VStack(spacing: 1) {
        EditorBanner(text: EditorBannerText.behind)
        ForEach(notes.indices, id: \.self) { EditorBanner(text: EditorBannerText.text(notes[$0])) }
    }
    .frame(width: 720)
}
