import ConsoleCore
import SwiftUI

/// The Host menu: pairing with the connected host and its clients, from wherever the user is. Each
/// brings the connect window forward, where the sheet opens.
struct HostCommands: Commands {
    let connection: HostConnection
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandMenu("Host") {
            Button("Pair with Host…") {
                openWindow(id: ConnectView.windowID)
                connection.pair()
            }
            .disabled(connection.isPaired != false)
            Button("Show Clients…") {
                openWindow(id: ConnectView.windowID)
                connection.showClients()
            }
            .disabled(connection.isPaired != true)
        }
    }
}
