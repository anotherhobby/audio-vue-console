import ConsoleCore
import SwiftUI

/// Calibrate…: the output device feeding the panel, remembered for it, and the run: a calibration,
/// or a calibration with a characterization (`calibration-run`).
struct CalibrateSheet: View {
    /// The panel's installed capture rate, the rate the run plays and captures at.
    let rate: Int
    let hostID: String?
    let start: (StatedRun, OutputDevice) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var devices: [OutputDevice] = []
    @State private var device: OutputDevice?
    @State private var kind = StatedRun.Kind.calibration

    static let whereItPlays =
        "Calibration plays from this Mac, so it works only from the machine whose output feeds "
        + "the panel."
    private static let width: CGFloat = 460

    var body: some View {
        VStack(spacing: 0) {
            Form {
                CalibrateFields(devices: devices, device: $device, kind: $kind, rate: rate)
            }
            .formStyle(.grouped)
            PlaybackWarning().padding(.horizontal)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Start") { begin() }.keyboardShortcut(.defaultAction)
                    .disabled(device == nil)
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

    private func begin() {
        guard let device else { return }
        if let hostID { PlaybackDeviceMemory().remember(device, for: hostID) }
        start(StatedRun(kind: kind, rate: rate), device)
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
    let rate: Int

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
            LabeledContent("Rate", value: "\(rate.formatted()) Hz")
        } footer: {
            Text(CalibrateSheet.whereItPlays)
        }
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

#Preview("Calibrate…") {
    @Previewable @State var device: OutputDevice? = OutputDevice(uid: "d10s", name: "D10s ")
    @Previewable @State var kind = StatedRun.Kind.characterization
    Form {
        CalibrateFields(
            devices: [
                OutputDevice(uid: "d10s", name: "D10s "), OutputDevice(uid: "s", name: "Speakers"),
            ],
            device: $device, kind: $kind, rate: 96_000)
    }
    .formStyle(.grouped)
    .frame(width: 460, height: 300)
}
