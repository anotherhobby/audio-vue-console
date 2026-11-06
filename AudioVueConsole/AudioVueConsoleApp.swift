import ConsoleCore
import SwiftUI

@main struct AudioVueConsoleApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    /// The one host connection, the app's rather than the window's, so closing the window keeps it.
    @State private var connection = HostConnection(tokens: FileTokenStore.applicationSupport)
    /// The scenes as edited on the Scenes page's sample panel, kept here so they outlive the window.
    @State private var sceneStore = SceneStore()

    var body: some Scene {
        // The panel window, around the scene canvas. Its Arrange menu acts on the canvas, the one
        // place it applies.
        Window("audio-vue Console", id: PanelWindow.windowID) {
            PanelWindow(connection: connection)
                .environment(sceneStore)
        }
        .defaultSize(
            width: PanelMetrics.windowDefaultWidth, height: PanelMetrics.windowDefaultHeight
        )
        .commands { ArrangeCommands() }
    }
}

/// Keeps the app running with its window closed, so the connection lasts and the window comes back
/// from the Window menu or the Dock. A lone `Window` scene would otherwise quit the app.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
