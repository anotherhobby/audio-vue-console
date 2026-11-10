import ConsoleCore
import SwiftUI

/// A device, rate and format for the panel's input: nil for the host's default device, and for
/// a format the host declares none of.
struct InputChoice: Equatable {
    var device: String?
    var rate: Int
    var format: String?
}

/// The Input section's values, as `PanelInput` read them.
struct InputShown: Equatable {
    var choice: InputChoice
    var devices: [String]
    var devicesReason: String?
    var rateChoices: [Int]
    var formatChoices: [String] = []
    var isDeviceAttached = true
    var isRateOffered = true
    var isFormatOffered = true
    /// Each rate's calibration for the installed device, or nil to mark no rate.
    var calibrations: [Int: CalibratedRate.Status]?
    var note: PanelInput.Note?
    var isWriting = false

    @MainActor init?(_ input: PanelInput) {
        guard let rate = input.rate else { return nil }
        choice = InputChoice(device: input.device, rate: rate, format: input.format)
        devices = input.devices
        devicesReason = input.devicesReason
        rateChoices = input.rateChoices
        formatChoices = input.formatChoices
        isDeviceAttached = input.isDeviceAttached
        isRateOffered = input.isRateOffered
        isFormatOffered = input.isFormatOffered
        calibrations = input.calibrations
        note = input.note
        isWriting = input.isWriting
    }

    /// The values a preview shows, each of the rest at its default.
    init(choice: InputChoice, devices: [String], rateChoices: [Int]) {
        self.choice = choice
        self.devices = devices
        self.rateChoices = rateChoices
    }
}

/// What the Input section shows: the input, or why it shows none.
enum InputListing: Equatable {
    case notPaired
    case loading
    case failed(String)
    case shown(InputShown)
}

/// Why the input cannot be changed now, if it cannot: a calibration has the panel, either running or
/// holding its last result until audio returns (`capture-input`, design D11).
enum InputLock: Equatable {
    case free
    case calibrating
    /// The panel shows the last run's result, capturing at `rate`, until audio returns.
    case holding(rate: Int?)
}

/// The Capture page's Input and Output section: the panel's capture device, rate and format,
/// written to the host's `input` install block when chosen (`capture-input`), and this Mac's output
/// (`mac-output`). A capture change asks first, since the host restarts the panel for it, unless
/// the panel is down. While Synchronize Rates is on, a stored capture rate sets the output, and an
/// output rate is written as the capture rate first (design D6). Everything is disabled while a
/// calibration has the panel; while it holds a run's result, Return to Scene ends the hold.
struct InputSection: View {
    let input: PanelInput?
    let output: MacOutput?
    let isPanelDown: Bool
    let lock: InputLock
    /// A choice waiting on the user's answer to the restart question.
    @State private var asked: InputChoice?
    /// A choice being written, shown until the write returns, so the pickers do not show the old
    /// value while the panel restarts.
    @State private var writing: InputChoice?

    var body: some View {
        InputFields(
            listing: listing, selection: selection, lock: lock,
            output: output.map { OutputShown($0, input: input) }, outputActions: outputActions
        ) {
            Task { await input?.endHold() }
        }
        .alert(
            "Changing the input restarts the panel.", isPresented: isAsking, presenting: asked
        ) { choice in
            Button("Restart Panel") { write(choice) }
            Button("Cancel", role: .cancel) { asked = nil }
        } message: { _ in
            Text("The panel stops measuring while it restarts with the new input.")
        }
    }

    /// The choice the pickers show and set, read from the section's state and the model each time
    /// it is called.
    private var selection: Binding<InputChoice> {
        Binding(get: { shownChoice }, set: { choose($0) })
    }

    /// The choice waiting on the restart question, else the one being written, else the installed.
    private var shownChoice: InputChoice {
        asked ?? writing
            ?? InputChoice(device: input?.device, rate: input?.rate ?? 0, format: input?.format)
    }

    private var isAsking: Binding<Bool> {
        Binding(get: { asked != nil }, set: { if !$0 { asked = nil } })
    }

    private var listing: InputListing {
        switch input?.state {
        case nil, .unpaired?: .notPaired
        case .failed(let failure)?: .failed(ReadFailureText.text(failure))
        case .idle?, .loading?, .loaded?:
            input.flatMap(InputShown.init).map { .shown($0) } ?? .loading
        }
    }

    private func choose(_ choice: InputChoice) {
        guard choice != shownChoice else { return }
        guard isPanelDown else {
            asked = choice
            return
        }
        write(choice)
    }

    /// Writes `choice`, showing it until the host answers; a refused write then shows the installed
    /// values again. A new capture rate the host stores is followed by a synchronized output.
    private func write(_ choice: InputChoice) {
        writing = choice
        asked = nil
        let isNewRate = choice.rate != input?.rate
        Task {
            let stored =
                await input?.write(device: choice.device, rate: choice.rate, format: choice.format)
                ?? false
            writing = nil
            guard stored, isNewRate, let output else { return }
            let follow = RateSync.afterCapture(
                stored: choice.rate, synchronized: output.isSynchronized, output: output.current,
                device: output.device)
            follow.map(output.setRate)
        }
    }

    private var outputActions: OutputActions {
        OutputActions(
            choose: { output?.choose($0) }, chooseRate: chooseOutputRate,
            chooseFormat: { output?.setFormat($0) }, synchronize: synchronize)
    }

    /// Sets the output's rate, or, while synchronized, writes it as the capture rate first.
    private func chooseOutputRate(_ rate: Int) {
        guard let output else { return }
        let action = RateSync.onOutputChosen(
            rate, synchronized: output.isSynchronized, capture: input?.rate)
        switch action {
        case .setOutput(let rate): output.setRate(rate)
        case .writeCapture(let rate):
            choose(InputChoice(device: shownChoice.device, rate: rate, format: shownChoice.format))
        }
    }

    /// Turns Synchronize Rates on or off, setting the output to the capture rate as it turns on.
    private func synchronize(_ isOn: Bool) {
        guard let output else { return }
        output.setSynchronized(isOn)
        guard isOn else { return }
        let rate = RateSync.onSynchronize(
            capture: input?.rate, output: output.current, device: output.device)
        rate.map(output.setRate)
    }
}

/// The Input section for given values, so previews can show each.
struct InputFields: View {
    let listing: InputListing
    /// The device and rate shown, and set when the user picks one.
    @Binding var selection: InputChoice
    let lock: InputLock
    /// This Mac's output, nil where the section shows none.
    var output: OutputShown?
    var outputActions = OutputActions()
    /// Ends the hold after a calibration run.
    var returnToScene: () -> Void = {}

    var body: some View {
        Section {
            switch listing {
            case .notPaired:
                Text("Pair with the panel to set its input.").foregroundStyle(.secondary)
            case .loading: ProgressView().controlSize(.small)
            case .failed(let reason):
                Label(
                    "Couldn't read the input: \(reason)",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .foregroundStyle(.orange)
            case .shown(let shown): pickers(shown)
            }
        } header: {
            Text("Input and Output")
        } footer: {
            if lock == .calibrating, case .shown = listing { Text("A calibration is running.") }
        }
    }

    @ViewBuilder private func pickers(_ shown: InputShown) -> some View {
        Group {
            Picker("Capture Device (audio-vue)", selection: $selection.device) {
                Text("Default device").tag(String?.none)
                ForEach(Self.devices(shown), id: \.self) { name in
                    Text(Self.deviceText(name, shown)).tag(String?.some(name))
                }
            }
            if shown.devices.isEmpty, let reason = shown.devicesReason {
                Text(reason).foregroundStyle(.secondary)
            }
            Picker("Capture Rate (audio-vue)", selection: $selection.rate) {
                ForEach(shown.rateChoices, id: \.self) { rate in
                    Text(Self.rateText(rate, shown)).tag(rate)
                }
            }
            CaptureFormatRow(shown: shown, selection: $selection.format)
        }
        .disabled(lock != .free || shown.isWriting)
        if let output {
            OutputFields(
                shown: output, isDisabled: lock != .free || shown.isWriting,
                actions: outputActions)
        }
        if case .holding(let rate) = lock {
            HoldRow(rate: rate, returnToScene: returnToScene)
        }
        if shown.isWriting {
            HStack {
                ProgressView().controlSize(.small)
                Text("Changing the input…")
            }
        } else if let note = shown.note {
            InputNoteRow(note: note)
        }
    }

    /// The host's devices, with the installed one kept where the host no longer lists it.
    private static func devices(_ shown: InputShown) -> [String] {
        guard let device = shown.choice.device, !shown.devices.contains(device) else {
            return shown.devices
        }
        return [device] + shown.devices
    }

    private static func deviceText(_ name: String, _ shown: InputShown) -> String {
        shown.devices.contains(name) ? name : "\(name) (not attached)"
    }

    /// A rate, marked where the host does not offer it, and with its calibration where the host
    /// reported which rates hold one (`capture-input`).
    static func rateText(_ rate: Int, _ shown: InputShown) -> String {
        var text = RateText.text(rate)
        if rate == shown.choice.rate && !shown.isRateOffered {
            text += " (not offered by the host)"
        }
        guard let calibrations = shown.calibrations else { return text }
        switch calibrations[rate] {
        case .calibrated?: return "\(text) — calibrated"
        case .stale?: return "\(text) — calibrated, stale"
        case nil: return "\(text) — not calibrated"
        }
    }
}

#Preview("Paired") {
    var shown = InputShown(
        choice: InputChoice(device: "hw:CARD=D10s,DEV=0", rate: 96_000, format: "S32_LE"),
        devices: ["hw:CARD=D10s,DEV=0", "hw:CARD=CODEC,DEV=0"],
        rateChoices: [44_100, 48_000, 88_200, 96_000, 192_000])
    shown.formatChoices = ["S16_LE", "S32_LE"]
    return Form {
        InputFields(listing: .shown(shown), selection: .constant(shown.choice), lock: .free)
    }
    .formStyle(.grouped).frame(width: 560, height: 260)
}

#Preview("Not paired") {
    Form {
        InputFields(
            listing: .notPaired, selection: .constant(InputChoice(rate: 0)), lock: .free)
    }
    .formStyle(.grouped).frame(width: 560, height: 140)
}

#Preview("No devices, 16-bit") {
    var shown = InputShown(
        choice: InputChoice(device: nil, rate: 48_000, format: "S16_LE"), devices: [],
        rateChoices: [44_100, 48_000, 88_200, 96_000, 192_000])
    shown.devicesReason = "No capture device is attached."
    shown.formatChoices = ["S16_LE", "S32_LE"]
    return Form {
        InputFields(listing: .shown(shown), selection: .constant(shown.choice), lock: .free)
    }
    .formStyle(.grouped).frame(width: 560, height: 260)
}

#Preview("Disabled during a run") {
    var shown = InputShown(
        choice: InputChoice(device: "hw:CARD=D10s,DEV=0", rate: 96_000, format: "S32_LE"),
        devices: ["hw:CARD=D10s,DEV=0", "hw:CARD=CODEC,DEV=0"],
        rateChoices: [44_100, 48_000, 88_200, 96_000, 192_000])
    shown.formatChoices = ["S16_LE", "S32_LE"]
    shown.note = .written(calibration: "The panel's 96 kHz holds no calibration.")
    return Form {
        InputFields(listing: .shown(shown), selection: .constant(shown.choice), lock: .calibrating)
    }
    .formStyle(.grouped).frame(width: 560, height: 280)
}

#Preview("Calibrated at 48 and 96 kHz") {
    var shown = InputShown(
        choice: InputChoice(device: "hw:CARD=D10s,DEV=0", rate: 96_000, format: "S32_LE"),
        devices: ["hw:CARD=D10s,DEV=0"], rateChoices: [44_100, 48_000, 88_200, 96_000, 192_000])
    shown.formatChoices = ["S16_LE", "S32_LE"]
    shown.calibrations = [48_000: .calibrated, 96_000: .calibrated]
    return Form {
        InputFields(listing: .shown(shown), selection: .constant(shown.choice), lock: .free)
        Section("Rates") {
            ForEach(shown.rateChoices, id: \.self) { Text(InputFields.rateText($0, shown)) }
        }
    }
    .formStyle(.grouped).frame(width: 560, height: 460)
}

#Preview("Holding after a pass") {
    var shown = InputShown(
        choice: InputChoice(device: "hw:CARD=m2x4HD,DEV=0", rate: 96_000, format: "S32_LE"),
        devices: ["hw:CARD=m2x4HD,DEV=0", "hw:CARD=CODEC,DEV=0"],
        rateChoices: [44_100, 48_000, 88_200, 96_000, 192_000])
    shown.formatChoices = ["S16_LE", "S32_LE"]
    return Form {
        InputFields(
            listing: .shown(shown), selection: .constant(shown.choice),
            lock: .holding(rate: 192_000))
    }
    .formStyle(.grouped).frame(width: 640, height: 300)
}
