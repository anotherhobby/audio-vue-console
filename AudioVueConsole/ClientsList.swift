import ConsoleCore
import SwiftUI

/// The host's paired clients, in place in the Overview's Pairing section: this Mac marked, and
/// each revoked after the user confirms (`panel-window`, "The Pairing section lists the host's
/// clients"). The model does the work, loaded by whoever makes it, since rows with nothing to show
/// never appear and so never start a task of their own; this only shows it.
struct ClientsList: View {
    let clients: PairedClients

    var body: some View {
        ClientRows(
            state: clients.state, clients: clients.clients, isThisMac: clients.isThisApp,
            revoke: { listed in Task { await clients.revoke(listed) } })
    }
}

/// The client rows for a given state, so previews can show them.
struct ClientRows: View {
    let state: PairedClients.State
    let clients: [PairedClient]
    var isThisMac: (PairedClient) -> Bool = { _ in false }
    var revoke: (PairedClient) -> Void = { _ in }

    var body: some View {
        switch state {
        case .failed:
            Label("Couldn't read the host's clients.", systemImage: "xmark.octagon.fill")
                .foregroundStyle(.red)
        case .unpaired:
            EmptyView()
        case .idle, .loading, .loaded:
            if state == .loading, clients.isEmpty { ProgressView() }
            ForEach(clients) { client in
                ClientRow(client: client, isThisMac: isThisMac(client)) { revoke(client) }
            }
        }
    }
}

/// One paired client: its name, when it paired, and Revoke, which asks first.
private struct ClientRow: View {
    let client: PairedClient
    let isThisMac: Bool
    let revoke: () -> Void
    @State private var isConfirming = false

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(verbatim: client.name).font(.headline)
                pairedAt.foregroundStyle(.secondary)
            }
            if isThisMac {
                Text("This Mac")
                    .font(.caption)
                    .padding(.horizontal)
                    .background(.quaternary, in: .capsule)
            }
            Spacer()
            Button("Revoke…") { isConfirming = true }
        }
        .confirmationDialog("Revoke \(client.name)?", isPresented: $isConfirming) {
            Button("Revoke", role: .destructive, action: revoke)
        } message: {
            Text(
                isThisMac
                    ? "This Mac will have to pair again at the panel to reach the host."
                    : "It will have to pair again at the panel to reach the host.")
        }
    }

    private var pairedAt: Text {
        guard let date = client.pairedAt else { return Text(verbatim: client.pairedAtText) }
        return Text("Paired \(date, format: .dateTime.day().month().year().hour().minute())")
    }
}

#Preview("Three clients") {
    Form {
        Section("Clients") {
            ClientRows(
                state: .loaded,
                clients: [
                    PairedClient(
                        id: "a", name: "hobbymac", pairedAtText: "2026-11-04T10:00:00+00:00"),
                    PairedClient(
                        id: "b", name: "Lost laptop", pairedAtText: "2026-10-01T08:30:00+00:00"),
                ],
                isThisMac: { $0.id == "a" })
        }
    }
    .formStyle(.grouped)
}
