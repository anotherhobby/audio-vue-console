import ConsoleCore
import SwiftUI

/// Calibrate…: the output device feeding the panel, remembered for it, and the run: a calibration,
/// or a calibration with a characterization, at the installed rate or, for a calibration, at every
/// rate the host declares (`calibration-run`, `calibration-pass`).
struct CalibrateSheet: View {
    /// The panel's installed capture rate, the rate a one-rate run plays and captures at.
    let rate: Int
    /// The rates the host's schema declares for the input, or nil where it declares none.
    let hostRates: [Int]?
    let hostID: String?
    let start: (StatedRun.Kind, PassPlan, OutputDevice) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var devices: [OutputDevice] = []
    @State private var device: OutputDevice?
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
                    devices: devices, device: $device, kind: $kind, everyRate: $everyRate,
                    rate: rate, hostRates: hostRates)
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
        .task { load() }
    }

    private func load() {
        devices = CoreAudioOutputDevices().list()
        device = hostID.flatMap { PlaybackDeviceMemory().chosen(for: $0, among: devices) }
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
        if let hostID { PlaybackDeviceMemory().remember(device, for: hostID) }
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
    let devices: [OutputDevice]
    @Binding var device: OutputDevice?
    @Binding var kind: StatedRun.Kind
    @Binding var everyRate: Bool
    let rate: Int
    let hostRates: [Int]?

    var body: some View {
        Section {
            Picker("Output", selection: $device) {
                Text("Choose…").tag(OutputDevice?.none)
                ForEach(devices) { Text(Self.name($0)).tag(OutputDevice?.some($0)) }
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

    /// The rates a run covers: the installed rate alone, or the host's rates the output offers.
    static func plan(everyRate: Bool, rate: Int, hostRates: [Int]?, output: OutputDevice)
        -> PassPlan
    {
        guard everyRate, let hostRates else { return PassPlan(runs: [rate]) }
        return PassPlan.make(hostRates: hostRates, output: output)
    }

    /// A device's name as CoreAudio gives it, without the space it may end with.
    static func name(_ device: OutputDevice) -> String {
        device.name.trimmingCharacters(in: .whitespaces)
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
    @Previewable @State var device: OutputDevice? = OutputDevice(
        uid: "d10s", name: "D10s ", availableRates: [44_100...96_000])
    @Previewable @State var kind = StatedRun.Kind.calibration
    @Previewable @State var everyRate = true
    Form {
        CalibrateFields(
            devices: [device].compactMap(\.self), device: $device, kind: $kind,
            everyRate: $everyRate, rate: 96_000,
            hostRates: [44_100, 48_000, 88_200, 96_000, 192_000])
    }
    .formStyle(.grouped)
    .frame(width: 460, height: 320)
}

#Preview("A characterization") {
    @Previewable @State var device: OutputDevice? = OutputDevice(uid: "d10s", name: "D10s ")
    @Previewable @State var kind = StatedRun.Kind.characterization
    @Previewable @State var everyRate = false
    Form {
        CalibrateFields(
            devices: [device].compactMap(\.self), device: $device, kind: $kind,
            everyRate: $everyRate, rate: 96_000,
            hostRates: [44_100, 48_000, 88_200, 96_000, 192_000])
    }
    .formStyle(.grouped)
    .frame(width: 460, height: 300)
}

#Preview("No rate in common") {
    @Previewable @State var device: OutputDevice? = OutputDevice(
        uid: "kiyo", name: "Razer Kiyo Pro", availableRates: [16_000...16_000, 32_000...32_000])
    @Previewable @State var kind = StatedRun.Kind.calibration
    @Previewable @State var everyRate = true
    Form {
        CalibrateFields(
            devices: [device].compactMap(\.self), device: $device, kind: $kind,
            everyRate: $everyRate, rate: 96_000,
            hostRates: [44_100, 48_000, 88_200, 96_000, 192_000])
    }
    .formStyle(.grouped)
    .frame(width: 460, height: 320)
}
