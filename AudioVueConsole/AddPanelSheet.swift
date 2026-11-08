import ConsoleCore
import SwiftUI

/// Add Panel…: a host's address, and what connecting to it came to (`panel-window`, "A panel is
/// added by its address"). The app holds one panel, so a connect here replaces the one it held.
struct AddPanelSheet: View {
    @Bindable var connection: HostConnection
    /// The calibration under way, if any, settled before another panel replaces this one.
    var calibration: CalibrationSession?
    @Environment(\.dismiss) private var dismiss
    @Environment(SceneStore.self) private var store

    var body: some View {
        AddPanelForm(
            address: $connection.addressText, state: connection.state, connect: connect,
            done: { dismiss() }
        )
        .unsavedScenesAlerts(store.unsaved)
    }

    /// Connects to the address typed, once any calibration under way and any unsaved scenes are
    /// settled, unless it is the panel held, whose scenes a reconnect keeps (`scene-saving`,
    /// `calibration-run`).
    private func connect() {
        guard HostAddress(parsing: connection.addressText) != connection.address else {
            Task { await connection.connect() }
            return
        }
        RunUnderWay.settle(calibration, before: "Switch Panels") {
            store.unsaved.settle(store.currentWrites) { Task { await connection.connect() } }
        }
    }
}

/// The Add Panel form for a given state, so previews can show each.
struct AddPanelForm: View {
    @Binding var address: String
    let state: HostConnection.State
    var connect: () -> Void = {}
    var done: () -> Void = {}

    private static let width: CGFloat = 440

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField(
                        "Address", text: $address, prompt: Text(verbatim: "audio-vue.local")
                    )
                    .onSubmit(connect)
                    .disabled(isConnecting)
                } footer: {
                    Text("A hostname or IPv4 address, with a port if it isn't 19200.")
                }
                Section {
                    if case .connected(let reached, _, paired: false) = state {
                        Label(
                            """
                            Reached \(reached.description). Pair with it on the Panel page to see \
                            and control its panel.
                            """, systemImage: "link.badge.plus")
                    }
                    ConnectionStatus(state: state)
                }
            }
            .formStyle(.grouped)
            buttons
        }
        .frame(width: Self.width)
    }

    private var buttons: some View {
        HStack {
            Spacer()
            Button(isConnected ? "Done" : "Cancel", action: done)
                .keyboardShortcut(isConnected ? .defaultAction : .cancelAction)
            Button("Connect", action: connect)
                .keyboardShortcut(isConnected ? nil : .defaultAction)
                .disabled(isConnecting || address.isEmpty)
        }
        .padding()
    }

    private var isConnecting: Bool {
        if case .connecting = state { return true }
        return false
    }

    /// Whether the address typed is the one the app is connected to, when Done is the next step.
    private var isConnected: Bool {
        guard case .connected(let connected, _, _) = state else { return false }
        return HostAddress(parsing: address) == connected
    }
}

#Preview("Idle") {
    AddPanelForm(address: .constant(""), state: .idle)
}

#Preview("Reached, not paired") {
    if let address = HostAddress(parsing: "audio-vue"), let api = APIVersion(parsing: "2.1.0") {
        AddPanelForm(
            address: .constant("audio-vue"),
            state: .connected(
                address, HostVersion(api: api, schema: 1, cards: .preview), paired: false))
    }
}

#Preview("Failed") {
    if let address = HostAddress(parsing: "audio-vue") {
        AddPanelForm(address: .constant("audio-vue"), state: .failed(address, .unreachable))
    }
}
