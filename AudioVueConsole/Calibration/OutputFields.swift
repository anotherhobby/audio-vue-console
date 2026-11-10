import ConsoleCore
import SwiftUI

/// This Mac's output as the section shows it, from `MacOutput` and the panel's input, so previews
/// can give each case.
struct OutputShown: Equatable {
    var devices: [OutputDevice]
    var device: OutputDevice?
    var current: OutputCurrent?
    var isSynchronized = true
    var refusal: OutputFailure?
    /// The panel's capture rate, nil until read.
    var captureRate: Int?
    /// The rates the host declares for capture, nil where it declares none.
    var hostRates: [Int]?

    init(devices: [OutputDevice], device: OutputDevice?, current: OutputCurrent?) {
        self.devices = devices
        self.device = device
        self.current = current
    }

    @MainActor init(_ output: MacOutput, input: PanelInput?) {
        self.init(devices: output.devices, device: output.device, current: output.current)
        isSynchronized = output.isSynchronized
        refusal = output.refusal
        captureRate = input?.rate
        hostRates = input?.rates
    }

    /// The host's rates the device offers, with the device's own rate where it is not one of them
    /// (design D7).
    var rateChoices: [Int] {
        guard let device else { return [] }
        let offered = hostRates.map { PassPlan.make(hostRates: $0, output: device).runs } ?? []
        guard let rate = current?.rate, !offered.contains(rate) else { return offered }
        return (offered + [rate]).sorted()
    }

    var formatChoices: [OutputFormat] {
        guard let device, let rate = current?.rate else { return [] }
        return device.formats(at: rate)
    }

    var match: RateMatch {
        RateMatch.of(output: current, device: device, capture: captureRate)
    }
}

/// What choosing in the output rows asks for; the section decides what each does (design D6).
struct OutputActions {
    var choose: @MainActor (OutputDevice) -> Void = { _ in }
    var chooseRate: @MainActor (Int) -> Void = { _ in }
    var chooseFormat: @MainActor (OutputFormat) -> Void = { _ in }
    var synchronize: @MainActor (Bool) -> Void = { _ in }
}

/// Output Device, Output Rate and Output Format (this Mac), Synchronize Rates, and what they come
/// to: a mismatch with the capture rate, a format under 24 bits, or a refused set (`mac-output`).
struct OutputFields: View {
    let shown: OutputShown
    let isDisabled: Bool
    var actions = OutputActions()

    var body: some View {
        Group {
            Picker("Output Device (this Mac)", selection: deviceBinding) {
                if shown.device == nil { Text("Choose…").tag(OutputDevice?.none) }
                ForEach(shown.devices) { Text(Self.name($0)).tag(OutputDevice?.some($0)) }
            }
            if let current = shown.current {
                OutputCurrentRows(
                    shown: shown, current: current, chooseRate: actions.chooseRate,
                    chooseFormat: actions.chooseFormat)
            }
            Toggle(
                "Synchronize Rates",
                isOn: Binding(get: { shown.isSynchronized }, set: { actions.synchronize($0) }))
        }
        .disabled(isDisabled)
        OutputNotes(shown: shown)
    }

    private var deviceBinding: Binding<OutputDevice?> {
        Binding(get: { shown.device }, set: { $0.map(actions.choose) })
    }

    /// A device's name as Core Audio gives it, without the space it may end with.
    static func name(_ device: OutputDevice) -> String {
        device.name.trimmingCharacters(in: .whitespaces)
    }
}

/// Output Rate and Output Format for a device whose values are read.
private struct OutputCurrentRows: View {
    let shown: OutputShown
    let current: OutputCurrent
    let chooseRate: @MainActor (Int) -> Void
    let chooseFormat: @MainActor (OutputFormat) -> Void

    var body: some View {
        Picker(
            "Output Rate (this Mac)",
            selection: Binding(get: { current.rate }, set: chooseRate)
        ) {
            ForEach(shown.rateChoices, id: \.self) { Text(rateText($0)).tag($0) }
        }
        if let format = current.format {
            Picker(
                "Output Format (this Mac)",
                selection: Binding(get: { format }, set: chooseFormat)
            ) {
                ForEach(shown.formatChoices, id: \.self) {
                    Text(FormatText.output($0)).tag($0)
                }
            }
        }
    }

    /// A rate, marked where it is not one the panel captures at.
    private func rateText(_ rate: Int) -> String {
        let text = RateText.text(rate)
        guard let hostRates = shown.hostRates, !hostRates.contains(rate) else { return text }
        return "\(text) (not a rate the panel captures at)"
    }
}

/// The output's mismatch, depth and refusal, each in words.
struct OutputNotes: View {
    let shown: OutputShown

    var body: some View {
        if let text = Self.matchText(shown.match) { ShallowRow(text: text) }
        if let format = shown.current?.format, format.isShallow {
            ShallowRow(
                text: "Playing \(format.bits) bits limits the noise floor the panel can read.")
        }
        if let refusal = shown.refusal {
            ShallowRow(text: "This Mac's output wasn't changed: \(Self.text(refusal))")
        }
    }

    static func matchText(_ match: RateMatch) -> String? {
        switch match {
        case .noOutput, .same: nil
        case .different(let output, let capture):
            "This Mac plays at \(RateText.text(output)) while the panel captures at "
                + "\(RateText.text(capture))."
        case .cannotPlay(let capture):
            "This output can't play the panel's capture rate, \(RateText.text(capture))."
        }
    }

    static func text(_ failure: OutputFailure) -> String {
        switch failure {
        case .notFound: "this Mac no longer lists it."
        case .formatNotOffered: "it doesn't offer that format at this rate."
        case .refused(let status): "Core Audio refused it (error \(status))."
        }
    }
}

#Preview("Every case") {
    let int16 = OutputFormat(bits: 16, isFloat: false)
    let int24 = OutputFormat(bits: 24, isFloat: false)
    let d10s = OutputDevice(
        uid: "d10s", name: "D10s ", availableRates: [44_100...96_000],
        formats: [
            OutputFormatRange(format: int16, rates: 44_100...96_000),
            OutputFormatRange(format: int24, rates: 44_100...96_000),
        ])
    let hostRates = [44_100, 48_000, 88_200, 96_000, 192_000]
    @MainActor func shown(_ rate: Int, _ format: OutputFormat, capture: Int) -> OutputShown {
        var shown = OutputShown(
            devices: [d10s], device: d10s, current: OutputCurrent(rate: rate, format: format))
        shown.captureRate = capture
        shown.hostRates = hostRates
        return shown
    }
    var refused = shown(96_000, int24, capture: 96_000)
    refused.refusal = .refused(-50)
    return Form {
        Section("Matched") {
            OutputFields(shown: shown(96_000, int24, capture: 96_000), isDisabled: false)
        }
        Section("Different") {
            OutputFields(shown: shown(48_000, int24, capture: 96_000), isDisabled: false)
        }
        Section("Cannot play") {
            OutputFields(shown: shown(96_000, int24, capture: 192_000), isDisabled: false)
        }
        Section("16-bit") {
            OutputFields(shown: shown(96_000, int16, capture: 96_000), isDisabled: false)
        }
        Section("No device") {
            OutputFields(
                shown: OutputShown(devices: [d10s], device: nil, current: nil), isDisabled: false)
        }
        Section("During a run, refused") { OutputFields(shown: refused, isDisabled: true) }
    }
    .formStyle(.grouped).frame(width: 600, height: 1_300)
}
