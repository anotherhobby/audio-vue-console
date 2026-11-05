import ConsoleCore
import SwiftUI

/// Pairing with the connected host: asking for a code, which its panel shows, and typing it here.
/// The model does the work; this only shows it.
struct PairingSheet: View {
    let pairing: HostPairing
    @State private var code = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        PairingForm(
            host: pairing.address.description,
            progress: PairingProgress(
                state: pairing.state, codeLapsesAt: pairing.codeLapsesAt,
                askAllowedAt: pairing.askAllowedAt, codeIsMalformed: pairing.codeIsMalformed),
            code: $code,
            actions: PairingActions(
                ask: {
                    code = ""
                    Task { await pairing.ask() }
                },
                confirm: { Task { await pairing.confirm(code) } },
                done: { dismiss() })
        )
        .onChange(of: pairing.state) { _, state in
            // A typo is fixed by typing the code again, so the field is cleared for it.
            if case .refused(let refusal) = state, refusal.kind == .wrongCode { code = "" }
        }
    }
}

/// What the pairing model says, as the form shows it.
struct PairingProgress {
    var state: HostPairing.State
    var codeLapsesAt: Date?
    var askAllowedAt: Date?
    var codeIsMalformed = false
}

/// What the pairing form's buttons do.
struct PairingActions {
    var ask: () -> Void = {}
    var confirm: () -> Void = {}
    var done: () -> Void = {}
}

/// The pairing form for a given progress, so previews can show each step.
struct PairingForm: View {
    let host: String
    let progress: PairingProgress
    @Binding var code: String
    var actions = PairingActions()

    private static let width: CGFloat = 420
    private static let spacing: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: Self.spacing) {
            Text("Pair with \(host)").font(.title2.bold())
            step
            HStack {
                Spacer()
                Button(progress.state == .paired ? "Done" : "Cancel", action: actions.done)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding()
        .frame(width: Self.width)
    }

    @ViewBuilder private var step: some View {
        switch progress.state {
        case .idle:
            Text("Ask \(host) to show a pairing code on its panel, then type it here.")
            Button("Ask for a Code", action: actions.ask).keyboardShortcut(.defaultAction)
        case .asking:
            ProgressView("Asking for a code…").controlSize(.small)
        case .showingCode, .confirming:
            codeEntry
        case .paired:
            Label("This Mac is paired with \(host).", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .refused(let refusal):
            RefusalNotice(refusal: refusal, progress: progress, ask: actions.ask)
            if refusal.kind == .wrongCode { codeEntry }
        case .failed(let failure):
            // A send that did not reach the host leaves the code standing, to send again.
            let codeStands = progress.codeLapsesAt != nil
            PairingFailureNotice(
                host: host, failure: failure, offersAsk: !codeStands, ask: actions.ask)
            if codeStands { codeEntry }
        case .notKept(let reason):
            Label(
                "Paired, but this Mac couldn't keep the token: \(reason)",
                systemImage: "xmark.octagon.fill"
            )
            .foregroundStyle(.red)
            Button("Ask for a New Code", action: actions.ask)
        }
    }

    private var codeEntry: some View {
        CodeEntry(
            code: $code, lapsesAt: progress.codeLapsesAt, isMalformed: progress.codeIsMalformed,
            isSending: progress.state == .confirming, confirm: actions.confirm, ask: actions.ask)
    }
}

/// The field the user types the panel's code into, with the code's time left, and asking for a new
/// code once it has lapsed.
struct CodeEntry: View {
    @Binding var code: String
    let lapsesAt: Date?
    let isMalformed: Bool
    let isSending: Bool
    let confirm: () -> Void
    let ask: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        Text("Type the six digits the panel shows.")
        TextField("Code", text: $code, prompt: Text(verbatim: "123456"))
            .font(.title.monospacedDigit())
            .textFieldStyle(.roundedBorder)
            .focused($focused)
            .onSubmit(confirm)
            .disabled(isSending)
            .onAppear { focused = true }
        if let lapsesAt {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(Self.timeLeft(until: lapsesAt, from: context.date))
                    .foregroundStyle(.secondary)
                if context.date >= lapsesAt {
                    Button("Ask for a New Code", action: ask)
                }
            }
        }
        if isMalformed {
            Text("The code is six digits.").foregroundStyle(.red)
        }
        Button("Pair", action: confirm)
            .keyboardShortcut(.defaultAction)
            .disabled(isSending || code.isEmpty)
    }

    private static func timeLeft(until lapse: Date, from now: Date) -> LocalizedStringKey {
        let seconds = Int(lapse.timeIntervalSince(now).rounded(.up))
        guard seconds > 0 else { return "The code has lapsed. Ask for a new one." }
        let left = Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
        return "The code stands for \(left)."
    }
}

/// Why the host refused, in this app's words with the host's reason under them, and asking again
/// once that makes sense. A wrong code offers none: the code still stands, so the user types it
/// again, and the code entry offers a new one once it lapses.
struct RefusalNotice: View {
    let refusal: PairingRefusal
    let progress: PairingProgress
    let ask: () -> Void

    var body: some View {
        Label(headline, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        if !refusal.detail.isEmpty {
            Text(verbatim: refusal.detail).foregroundStyle(.secondary)
        }
        if refusal.kind != .wrongCode {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Button(refusal.kind == .noCode ? "Ask for a New Code" : "Ask Again", action: ask)
                    .keyboardShortcut(.defaultAction)
                    .disabled(
                        !HostPairing.mayAsk(
                            at: context.date, codeLapsesAt: progress.codeLapsesAt,
                            askAllowedAt: progress.askAllowedAt))
            }
        }
    }

    private var headline: LocalizedStringKey {
        switch refusal.kind {
        case .busy:
            "A pairing is already under way at the panel. Ask again once it has finished."
        case .tooSoon(let seconds?):
            "Too soon after the last pairing. Ask again in \(seconds) seconds."
        case .tooSoon(nil):
            "Too soon after the last pairing. Ask again in a moment."
        case .noPanel:
            "The panel can't show a code. It must be running to pair."
        case .wrongCode:
            "That code was wrong. Check the panel and type it again."
        case .noCode:
            "The code is no longer showing."
        }
    }
}

/// A pairing request that went wrong in a way that is not a refusal.
struct PairingFailureNotice: View {
    let host: String
    let failure: HostFailure
    let offersAsk: Bool
    let ask: () -> Void

    var body: some View {
        Label(text, systemImage: "xmark.octagon.fill").foregroundStyle(.red)
        if offersAsk {
            Button("Ask Again", action: ask)
        }
    }

    private var text: LocalizedStringKey {
        failure == .unreachable
            ? "Couldn't reach \(host). Check that it is on, and connect again."
            : "\(host) answered in a way this app didn't expect."
    }
}

#Preview("Showing a code") {
    PairingForm(
        host: "audio-vue",
        progress: PairingProgress(
            state: .showingCode(PairingCode(ttl: 120, tries: 5)), codeLapsesAt: .now + 97),
        code: .constant("4821"))
}

#Preview("A wrong code") {
    PairingForm(
        host: "audio-vue",
        progress: PairingProgress(
            state: .refused(PairingRefusal(.wrongCode, detail: "wrong code: 4 tries left")),
            codeLapsesAt: .now + 64),
        code: .constant("482113"))
}

#Preview("Too soon") {
    PairingForm(
        host: "audio-vue",
        progress: PairingProgress(
            state: .refused(
                PairingRefusal(
                    .tooSoon(seconds: 30), detail: "too soon: wait 30 s before pairing again")),
            askAllowedAt: .now + 30),
        code: .constant(""))
}
