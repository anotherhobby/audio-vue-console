import ConsoleCore
import SwiftUI

/// The clients paired with the connected host, this Mac marked, and revoking one after the user
/// confirms. The model does the work; this only shows it.
struct ClientsSheet: View {
    let clients: PairedClients
    @State private var revoking: PairedClient?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ClientsForm(
            host: clients.address.description, state: clients.state, clients: clients.clients,
            isThisMac: clients.isThisApp, revoke: { revoking = $0 }, done: { dismiss() }
        )
        .task { await clients.load() }
        .confirmationDialog(
            "Revoke \(revoking?.name ?? "")?", isPresented: isConfirming, presenting: revoking
        ) { listed in
            Button("Revoke", role: .destructive) {
                Task { await clients.revoke(listed) }
            }
        } message: { listed in
            Text(
                clients.isThisApp(listed)
                    ? "This Mac will have to pair again at the panel to reach the host."
                    : "It will have to pair again at the panel to reach the host.")
        }
    }

    private var isConfirming: Binding<Bool> {
        Binding {
            revoking != nil
        } set: {
            if !$0 { revoking = nil }
        }
    }
}

/// The clients list for a given state, so previews can show it.
struct ClientsForm: View {
    let host: String
    let state: PairedClients.State
    let clients: [PairedClient]
    var isThisMac: (PairedClient) -> Bool = { _ in false }
    var revoke: (PairedClient) -> Void = { _ in }
    var done: () -> Void = {}

    private static let width: CGFloat = 460
    private static let minHeight: CGFloat = 260

    var body: some View {
        VStack(alignment: .leading) {
            Text("Clients of \(host)").font(.title2.bold())
            switch state {
            case .unpaired:
                Label(
                    "This Mac is no longer paired with \(host). Pair again at the panel.",
                    systemImage: "link.badge.plus")
            case .failed:
                Label("Couldn't read the host's clients.", systemImage: "xmark.octagon.fill")
                    .foregroundStyle(.red)
            case .idle, .loading, .loaded:
                list
            }
            HStack {
                Spacer()
                Button("Done", action: done).keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: Self.width, minHeight: Self.minHeight)
    }

    private var list: some View {
        List(clients) { client in
            HStack {
                VStack(alignment: .leading) {
                    Text(verbatim: client.name).font(.headline)
                    Self.pairedAt(client).foregroundStyle(.secondary)
                }
                if isThisMac(client) {
                    Text("This Mac")
                        .font(.caption)
                        .padding(.horizontal)
                        .background(.quaternary, in: .capsule)
                }
                Spacer()
                Button("Revoke…") { revoke(client) }
            }
        }
        .overlay {
            if state == .loading { ProgressView() }
        }
    }

    private static func pairedAt(_ client: PairedClient) -> Text {
        guard let date = client.pairedAt else { return Text(verbatim: client.pairedAtText) }
        return Text("Paired \(date, format: .dateTime.day().month().year().hour().minute())")
    }
}

#Preview("Three clients") {
    ClientsForm(
        host: "audio-vue", state: .loaded,
        clients: [
            PairedClient(id: "a", name: "hobbymac", pairedAtText: "2026-11-04T10:00:00+00:00"),
            PairedClient(id: "b", name: "Lost laptop", pairedAtText: "2026-10-01T08:30:00+00:00"),
            PairedClient(id: "c", name: "Studio iMac", pairedAtText: "2026-09-12T19:05:00+00:00"),
        ],
        isThisMac: { $0.id == "a" })
}
