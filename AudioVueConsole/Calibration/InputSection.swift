import ConsoleCore
import SwiftUI

/// A device and rate for the panel's input: nil for the host's default device.
struct InputChoice: Equatable {
    var device: String?
    var rate: Int
}

/// The Input section's values, as `PanelInput` read them.
struct InputShown: Equatable {
    var choice: InputChoice
    var devices: [String]
    var devicesReason: String?
    var rateChoices: [Int]
    var isDeviceAttached: Bool
    var isRateOffered: Bool
    /// Each rate's calibration for the installed device, or nil to mark no rate.
    var calibrations: [Int: CalibratedRate.Status]?
    var note: PanelInput.Note?
    var isWriting: Bool

    @MainActor init?(_ input: PanelInput) {
        guard let rate = input.rate else { return nil }
        self.init(
            choice: InputChoice(device: input.device, rate: rate), devices: input.devices,
            devicesReason: input.devicesReason, rateChoices: input.rateChoices,
            isDeviceAttached: input.isDeviceAttached, isRateOffered: input.isRateOffered,
            calibrations: input.calibrations, note: input.note, isWriting: input.isWriting)
    }

    init(
        choice: InputChoice, devices: [String], devicesReason: String? = nil,
        rateChoices: [Int], isDeviceAttached: Bool = true, isRateOffered: Bool = true,
        calibrations: [Int: CalibratedRate.Status]? = nil, note: PanelInput.Note? = nil,
        isWriting: Bool = false
    ) {
        self.choice = choice
        self.devices = devices
        self.devicesReason = devicesReason
        self.rateChoices = rateChoices
        self.isDeviceAttached = isDeviceAttached
        self.isRateOffered = isRateOffered
        self.calibrations = calibrations
        self.note = note
        self.isWriting = isWriting
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

/// The Capture page's Input section: the panel's capture device and rate, written to the host's
/// `input` install block when chosen (`capture-input`). A change asks first, since the host
/// restarts the panel for it, unless the panel is down. Both are disabled while a calibration has
/// the panel; while it holds a run's result, Return to Scene ends the hold.
struct InputSection: View {
    let input: PanelInput?
    let isPanelDown: Bool
    let lock: InputLock
    /// A choice waiting on the user's answer to the restart question.
    @State private var asked: InputChoice?
    /// A choice being written, shown until the write returns, so the pickers do not show the old
    /// value while the panel restarts.
    @State private var writing: InputChoice?

    var body: some View {
        InputFields(listing: listing, selection: selection, lock: lock) {
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
        asked ?? writing ?? InputChoice(device: input?.device, rate: input?.rate ?? 0)
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
    /// values again.
    private func write(_ choice: InputChoice) {
        writing = choice
        asked = nil
        Task {
            await input?.write(device: choice.device, rate: choice.rate)
            writing = nil
        }
    }
}

/// The Input section for given values, so previews can show each.
struct InputFields: View {
    let listing: InputListing
    /// The device and rate shown, and set when the user picks one.
    @Binding var selection: InputChoice
    let lock: InputLock
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
            Text("Input")
        } footer: {
            if lock == .calibrating, case .shown = listing { Text("A calibration is running.") }
        }
    }

    @ViewBuilder private func pickers(_ shown: InputShown) -> some View {
        Group {
            Picker("Device", selection: $selection.device) {
                Text("Default device").tag(String?.none)
                ForEach(Self.devices(shown), id: \.self) { name in
                    Text(Self.deviceText(name, shown)).tag(String?.some(name))
                }
            }
            if shown.devices.isEmpty, let reason = shown.devicesReason {
                Text(reason).foregroundStyle(.secondary)
            }
            Picker("Rate", selection: $selection.rate) {
                ForEach(shown.rateChoices, id: \.self) { rate in
                    Text(Self.rateText(rate, shown)).tag(rate)
                }
            }
        }
        .disabled(lock != .free || shown.isWriting)
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

#Preview("Paired") {
    let shown = InputShown(
        choice: InputChoice(device: "hw:CARD=D10s,DEV=0", rate: 96_000),
        devices: ["hw:CARD=D10s,DEV=0", "hw:CARD=CODEC,DEV=0"],
        rateChoices: [44_100, 48_000, 88_200, 96_000, 192_000])
    Form {
        InputFields(listing: .shown(shown), selection: .constant(shown.choice), lock: .free)
    }
    .formStyle(.grouped).frame(width: 560, height: 220)
}

#Preview("Not paired") {
    Form {
        InputFields(
            listing: .notPaired, selection: .constant(InputChoice(rate: 0)), lock: .free)
    }
    .formStyle(.grouped).frame(width: 560, height: 140)
}

#Preview("No devices") {
    let shown = InputShown(
        choice: InputChoice(device: nil, rate: 48_000), devices: [],
        devicesReason: "No capture device is attached.",
        rateChoices: [44_100, 48_000, 88_200, 96_000, 192_000])
    Form {
        InputFields(listing: .shown(shown), selection: .constant(shown.choice), lock: .free)
    }
    .formStyle(.grouped).frame(width: 560, height: 220)
}

#Preview("Disabled during a run") {
    var shown = InputShown(
        choice: InputChoice(device: "hw:CARD=D10s,DEV=0", rate: 96_000),
        devices: ["hw:CARD=D10s,DEV=0", "hw:CARD=CODEC,DEV=0"],
        rateChoices: [44_100, 48_000, 88_200, 96_000, 192_000])
    shown.note = .written(calibration: "The panel's 96 kHz holds no calibration.")
    return Form {
        InputFields(listing: .shown(shown), selection: .constant(shown.choice), lock: .calibrating)
    }
    .formStyle(.grouped).frame(width: 560, height: 240)
}

#Preview("Calibrated at 48 and 96 kHz") {
    let shown = InputShown(
        choice: InputChoice(device: "hw:CARD=D10s,DEV=0", rate: 96_000),
        devices: ["hw:CARD=D10s,DEV=0"],
        rateChoices: [44_100, 48_000, 88_200, 96_000, 192_000],
        calibrations: [48_000: .calibrated, 96_000: .calibrated])
    Form {
        InputFields(listing: .shown(shown), selection: .constant(shown.choice), lock: .free)
        Section("Rates") {
            ForEach(shown.rateChoices, id: \.self) { Text(InputFields.rateText($0, shown)) }
        }
    }
    .formStyle(.grouped).frame(width: 560, height: 420)
}

#Preview("Holding after a pass") {
    let shown = InputShown(
        choice: InputChoice(device: "hw:CARD=m2x4HD,DEV=0", rate: 96_000),
        devices: ["hw:CARD=m2x4HD,DEV=0", "hw:CARD=CODEC,DEV=0"],
        rateChoices: [44_100, 48_000, 88_200, 96_000, 192_000])
    Form {
        InputFields(
            listing: .shown(shown), selection: .constant(shown.choice),
            lock: .holding(rate: 192_000))
    }
    .formStyle(.grouped).frame(width: 640, height: 260)
}
