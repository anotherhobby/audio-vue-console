import ConsoleCore
import SwiftUI

@main struct AudioVueConsoleApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    /// The one host connection, the app's rather than the window's, so closing the window keeps it.
    @State private var connection: HostConnection
    /// The panels announced on the network, browsed from launch while the app runs.
    @State private var discovery: PanelDiscovery
    /// The scenes as edited on the Scenes page's sample panel, kept here so they outlive the window.
    @State private var sceneStore = SceneStore()
    /// The render helper the app carries, the app's so it outlives the window (`render-helper`).
    @State private var renderer = Renderer.app()

    /// Makes the discovery and the connection given it, since one `@State` initialiser cannot read
    /// another, and starts browsing here rather than in a view's `.task`, which runs only while the
    /// view has something to show (discovery design D8).
    init() {
        let discovery = PanelDiscovery()
        _discovery = State(initialValue: discovery)
        _connection = State(
            initialValue: HostConnection(
                tokens: FileTokenStore.applicationSupport, discovery: discovery))
        Task { await discovery.browse() }
        Task { await Self.browseAgainWhenActive(discovery) }
    }

    /// Browses again each time the app becomes active while it may not reach the local network, so
    /// access given in System Settings is picked up without a relaunch (discovery design D6).
    private static func browseAgainWhenActive(_ discovery: PanelDiscovery) async {
        let activations = NotificationCenter.default.notifications(
            named: NSApplication.didBecomeActiveNotification)
        for await _ in activations where !discovery.mayBrowse {
            discovery.restart()
        }
    }

    var body: some Scene {
        // The panel window, around the scene canvas. Its Arrange menu acts on the canvas, the one
        // place it applies.
        Window("audio-vue Console", id: PanelWindow.windowID) {
            PanelWindow(connection: connection, discovery: discovery, renderer: renderer)
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
