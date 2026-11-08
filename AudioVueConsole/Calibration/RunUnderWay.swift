import AppKit
import ConsoleCore

/// The question before a calibration under way is cut off, by a quit or a switch to another panel
/// (`calibration-run`, "A run under way is not ended without asking"). Going on cancels the run as
/// Cancel does; a run cut off mid-file would be measured as a stimulus missing.
@MainActor enum RunUnderWay {
    /// Runs `proceed` at once with no run under way; otherwise asks, and on going on cancels the run
    /// first.
    static func settle(
        _ session: CalibrationSession?, before action: String, then proceed: () -> Void
    ) {
        guard let session, session.isUnderWay else { return proceed() }
        guard confirm(action) else { return }
        session.cancel()
        proceed()
    }

    /// Whether the user chose to cancel the run and go on with `action`, such as "Quit".
    static func confirm(_ action: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = "A Calibration Is Under Way"
        alert.informativeText =
            "\(action) cancels the run: playback stops and the panel is told to cancel, writing no "
            + "record."
        alert.addButton(withTitle: "Cancel the Run and \(action)")
        alert.addButton(withTitle: "Keep Running")
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// How long a quit waits for the cancel to reach the panel: the host's own 5 s request timeout.
    private static let cancelWait = Duration.seconds(cancelWaitSeconds)
    private static let cancelWaitSeconds: Int64 = 5
    private static let pollStep = Duration.milliseconds(pollStepMilliseconds)
    private static let pollStepMilliseconds: Int64 = 50

    /// Waits for the session's cancel to reach the panel, for at most `limit`.
    static func waitForEnd(of session: CalibrationSession, limit: Duration = cancelWait) async {
        let step = pollStep
        var waited = Duration.zero
        while session.isUnderWay, waited < limit {
            do {
                try await Task.sleep(for: step)
            } catch {
                return
            }
            waited += step
        }
    }
}
