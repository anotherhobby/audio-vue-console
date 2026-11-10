import ConsoleCore
import SwiftUI

/// Calibrate…: the output device chosen for the panel in Input and Output, and the run: a
/// calibration, or a calibration with a characterization, at the installed rate or, for a
/// calibration, at every rate the host declares (`calibration-run`, `calibration-pass`).
struct CalibrateSheet: View {
    /// The panel's installed capture rate, the rate a one-rate run plays and captures at.
    let rate: Int
    /// The rates the host's schema declares for the input, or nil where it declares none.
    let hostRates: [Int]?
    /// The output chosen in Input and Output, nil where none is (`mac-output` design D8).
    let device: OutputDevice?
    let start: (StatedRun.Kind, PassPlan, OutputDevice) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var kind = StatedRun.Kind.calibration
    @State private var everyRate = false

    static let whereItPlays =
        "Calibration plays from this Mac, so it works only from the machine whose output feeds "
        + "the panel."
    private static let width: CGFloat = 460

    var body: some View {
        VStack(spacing: 0) {
            Form {
                CalibrateFields(
                    device: device, kind: $kind, everyRate: $everyRate, rate: rate,
                    hostRates: hostRates)
            }
            .formStyle(.grouped)
            PlaybackWarning().padding(.horizontal)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Start") { begin() }.keyboardShortcut(.defaultAction)
                    .disabled(plan?.runs.isEmpty ?? true)
            }
            .padding()
        }
        .frame(width: Self.width)
    }

    /// The rates the run covers on the chosen output, or nil until an output is chosen.
    private var plan: PassPlan? {
        device.map {
            CalibrateFields.plan(
                everyRate: everyRate, rate: rate, hostRates: hostRates, output: $0)
        }
    }

    private func begin() {
        guard let device, let plan, !plan.runs.isEmpty else { return }
        start(everyRate ? .calibration : kind, plan, device)
        dismiss()
    }
}

/// What to set before a run plays, above Start: the run plays full-scale tones (maintainer,
/// 2026-11-08).
struct PlaybackWarning: View {
    private static let lineSpacing: CGFloat = 6

    var body: some View {
        VStack(alignment: .leading, spacing: Self.lineSpacing) {
            Text("1. Your computer volume should be set to maximum.")
            Text(
                "2. Mute your external amplifier or speakers downstream from your computer, or turn "
                    + "your volume down very low. This calibration plays full scale tones that "
                    + "will damage your speakers! You have been warned.")
        }
        .foregroundStyle(.orange)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The sheet's fields, for given values, so previews can show each.
struct CalibrateFields: View {
    let device: OutputDevice?
    @Binding var kind: StatedRun.Kind
    @Binding var everyRate: Bool
    let rate: Int
    let hostRates: [Int]?

    var body: some View {
        Section {
            LabeledContent("Output (this Mac)") {
                Text(device.map(OutputFields.name) ?? "None")
            }
            if device == nil {
                Text("Choose this Mac's output in Input and Output.").foregroundStyle(.secondary)
            }
            Picker("Run", selection: $kind) {
                ForEach(StatedRun.Kind.allCases, id: \.self) {
                    Text(RunKindText.text($0.rawValue)).tag($0)
                }
            }
            Picker("Rate", selection: $everyRate) {
                Text("At the installed rate, \(RateText.text(rate))").tag(false)
                Text("At every rate").tag(true)
            }
            .disabled(kind == .characterization || hostRates == nil)
            .onChange(of: kind) { _, kind in if kind == .characterization { everyRate = false } }
            if let note = rateNote { Text(note).foregroundStyle(.secondary) }
            if let note = formatNote { ShallowRow(text: note) }
        } footer: {
            Text(CalibrateSheet.whereItPlays)
        }
    }

    /// What the rate choice comes to: why every rate can't be chosen, or the rates the chosen
    /// output skips.
    private var rateNote: String? {
        guard let hostRates else { return "The host declares no rates, so only its own is run." }
        guard everyRate, let device else { return nil }
        let plan = Self.plan(everyRate: true, rate: rate, hostRates: hostRates, output: device)
        if plan.runs.isEmpty {
            return "This output offers none of the host's rates."
        }
        guard !plan.skipped.isEmpty else { return nil }
        let skipped = plan.skipped.map(RateText.text).formatted(.list(type: .and))
        let them = plan.skipped.count == 1 ? "it" : "them"
        return "This output can't play \(skipped), so the pass skips \(them)."
    }

    /// Where the output plays under 24 bits at a rate the run covers: the record's noise floor will
    /// be the output's, not the chain's (`calibration-player`).
    private var formatNote: String? {
        guard let device else { return nil }
        let plan = Self.plan(everyRate: everyRate, rate: rate, hostRates: hostRates, output: device)
        let shallow = plan.runs.compactMap { rate in
            device.formats(at: rate).first.flatMap { $0.isShallow ? ($0.bits, rate) : nil }
        }
        guard let bits = shallow.map(\.0).max() else { return nil }
        let rates = shallow.map { RateText.text($0.1) }.formatted(.list(type: .and))
        return "This output plays at most \(bits) bits at \(rates), so the record's noise floor "
            + "will be the output's \(bits) bits rather than the chain's."
    }

    /// The rates a run covers: the installed rate alone, or the host's rates the output offers.
    static func plan(everyRate: Bool, rate: Int, hostRates: [Int]?, output: OutputDevice)
        -> PassPlan
    {
        guard everyRate, let hostRates else { return PassPlan(runs: [rate]) }
        return PassPlan.make(hostRates: hostRates, output: output)
    }

}

/// A run's kind in words. A characterization runs the calibration too, so it is named as both
/// (maintainer, 2026-11-08); any kind the app does not know is the host's own word.
enum RunKindText {
    static func text(_ kind: String) -> String {
        switch kind {
        case StatedRun.Kind.calibration.rawValue: "Calibration"
        case StatedRun.Kind.characterization.rawValue: "Calibration + Characterization"
        default: kind
        }
    }
}

#Preview("Every rate, an output without 192 kHz") {
    @Previewable @State var kind = StatedRun.Kind.calibration
    @Previewable @State var everyRate = true
    Form {
        CalibrateFields(
            device: OutputDevice(uid: "d10s", name: "D10s ", availableRates: [44_100...96_000]),
            kind: $kind, everyRate: $everyRate, rate: 96_000,
            hostRates: [44_100, 48_000, 88_200, 96_000, 192_000])
    }
    .formStyle(.grouped)
    .frame(width: 460, height: 320)
}

#Preview("A 16-bit output") {
    @Previewable @State var kind = StatedRun.Kind.calibration
    @Previewable @State var everyRate = false
    let int16 = OutputFormat(bits: 16, isFloat: false)
    Form {
        CalibrateFields(
            device: OutputDevice(
                uid: "usb", name: "USB Audio", availableRates: [44_100...96_000],
                formats: [OutputFormatRange(format: int16, rates: 44_100...96_000)]),
            kind: $kind, everyRate: $everyRate, rate: 96_000,
            hostRates: [44_100, 48_000, 88_200, 96_000, 192_000])
    }
    .formStyle(.grouped)
    .frame(width: 460, height: 340)
}

#Preview("A characterization") {
    @Previewable @State var kind = StatedRun.Kind.characterization
    @Previewable @State var everyRate = false
    Form {
        CalibrateFields(
            device: OutputDevice(uid: "d10s", name: "D10s "), kind: $kind,
            everyRate: $everyRate, rate: 96_000,
            hostRates: [44_100, 48_000, 88_200, 96_000, 192_000])
    }
    .formStyle(.grouped)
    .frame(width: 460, height: 300)
}

#Preview("No output chosen") {
    @Previewable @State var kind = StatedRun.Kind.calibration
    @Previewable @State var everyRate = false
    Form {
        CalibrateFields(
            device: nil, kind: $kind, everyRate: $everyRate, rate: 96_000,
            hostRates: [44_100, 48_000, 88_200, 96_000, 192_000])
    }
    .formStyle(.grouped)
    .frame(width: 460, height: 300)
}

#Preview("No rate in common") {
    @Previewable @State var kind = StatedRun.Kind.calibration
    @Previewable @State var everyRate = true
    Form {
        CalibrateFields(
            device: OutputDevice(
                uid: "kiyo", name: "Razer Kiyo Pro",
                availableRates: [16_000...16_000, 32_000...32_000]),
            kind: $kind, everyRate: $everyRate, rate: 96_000,
            hostRates: [44_100, 48_000, 88_200, 96_000, 192_000])
    }
    .formStyle(.grouped)
    .frame(width: 460, height: 320)
}
