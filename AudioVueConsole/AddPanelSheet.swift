import ConsoleCore
import SwiftUI

/// Add Panel…: a host's address, and what connecting to it came to (`panel-window`, "A panel is
/// added by its address"). The app holds one panel, so a connect here replaces the one it held.
struct AddPanelSheet: View {
    @Bindable var connection: HostConnection
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        AddPanelForm(
            address: $connection.addressText, state: connection.state,
            connect: { Task { await connection.connect() } }, done: { dismiss() })
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
            state: .connected(address, HostVersion(api: api, schema: 1), paired: false))
    }
}

#Preview("Failed") {
    if let address = HostAddress(parsing: "audio-vue") {
        AddPanelForm(address: .constant("audio-vue"), state: .failed(address, .unreachable))
    }
}
