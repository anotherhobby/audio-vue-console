import ConsoleCore
import SwiftUI

/// Capture Format (audio-vue): the host's formats, an installed one it does not offer marked, and a
/// 16-bit capture flagged (`capture-input`).
struct CaptureFormatRow: View {
    let shown: InputShown
    @Binding var selection: String?

    var body: some View {
        if !shown.formatChoices.isEmpty {
            Picker("Capture Format (audio-vue)", selection: $selection) {
                ForEach(shown.formatChoices, id: \.self) { name in
                    Text(Self.text(name, shown)).tag(String?.some(name))
                }
            }
        }
        if let format = shown.choice.format, FormatText.isShallowCapture(format) {
            ShallowRow(text: "Capturing 16 bits limits the noise floor the panel can read.")
        }
    }

    private static func text(_ name: String, _ shown: InputShown) -> String {
        let text = FormatText.capture(name)
        let isInstalledUnoffered = name == shown.choice.format && !shown.isFormatOffered
        return isInstalledUnoffered ? "\(text) (not offered by the host)" : text
    }
}

/// A format under 24 bits, flagged: it limits the noise floor the panel can read.
struct ShallowRow: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(.orange)
    }
}

/// The panel holding a calibration run's result: what it shows and when it returns, with Return to
/// Scene to end the hold now.
struct HoldRow: View {
    let rate: Int?
    let returnToScene: () -> Void

    var body: some View {
        LabeledContent {
            Button("Return to Scene", action: returnToScene)
        } label: {
            Text(Self.text(rate))
        }
    }

    static func text(_ rate: Int?) -> String {
        let at = rate.map { ", capturing at \(RateText.text($0))" } ?? ""
        return "The panel is showing the last calibration's result\(at). It returns to its scene "
            + "and input when audio plays."
    }
}

/// What the last write came to, in words.
struct InputNoteRow: View {
    let note: PanelInput.Note

    var body: some View {
        switch note {
        case .written(let calibration?):
            Label(calibration, systemImage: "info.circle")
        case .written(nil):
            Label("The panel's input is changed.", systemImage: "checkmark.circle")
        case .changedElsewhere:
            warning("The input was changed elsewhere. These are its values now.")
        case .refused(let reason):
            warning("The host refused the change: \(reason)")
        case .unanswered:
            warning("The host didn't answer while the panel restarted. These are its values now.")
        case .failed(let failure):
            warning("The input wasn't changed: \(ReadFailureText.text(failure))")
        }
    }

    private func warning(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
    }
}
