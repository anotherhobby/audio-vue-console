import ConsoleCore
import SwiftUI

@main struct AudioVueConsoleApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    /// The one host connection, the app's rather than the window's, so closing the window keeps it.
    @State private var connection = HostConnection(tokens: FileTokenStore.applicationSupport)

    #if DEBUG
        /// The sketch's scenes as edited, kept here so they outlive the sketch's window.
        @State private var sceneStore = SceneStore()
    #endif

    var body: some Scene {
        Window("Host Connection", id: ConnectView.windowID) {
            ConnectView(connection: connection)
        }
        .commands { HostCommands(connection: connection) }
        #if DEBUG
            // The UI sketch, in the Window menu, around the scene canvas. Its Arrange menu acts on
            // the canvas, the one place it applies.
            Window("UI Sketch", id: "sketch") {
                SketchShell()
                    .environment(sceneStore)
            }
            .defaultSize(
                width: SketchMetrics.windowDefaultWidth, height: SketchMetrics.windowDefaultHeight
            )
            .commands { ArrangeCommands() }
        #endif
    }
}

/// Keeps the app running with its window closed, so the connection lasts and the window comes back
/// from the Window menu or the Dock. A lone `Window` scene would otherwise quit the app.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
