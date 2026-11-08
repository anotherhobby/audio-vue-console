import ConsoleCore
import SwiftUI

@main struct AudioVueConsoleApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    /// The one host connection, the app's rather than the window's, so closing the window keeps it.
    @State private var connection: HostConnection
    /// The panels announced on the network, browsed from launch while the app runs.
    @State private var discovery: PanelDiscovery
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

    /// Whether toolbar buttons show their names, on until the user turns them off. The label style
    /// is set fixed from it: bound to `windowToolbarLabelStyle(_:)`, the style was overwritten
    /// with the toolbar's icon-only default at launch (measured, 2026-11-08).
    @AppStorage("showsButtonNames") private var showsButtonNames = true

    var body: some Scene {
        // The panel window, around the scene canvas. Its Arrange menu acts on the canvas, the one
        // place it applies.
        Window("audio-vue Console", id: PanelWindow.windowID) {
            PanelWindow(connection: connection, discovery: discovery, renderer: renderer)
                .environment(delegate.sceneStore)
        }
        .defaultSize(
            width: PanelMetrics.windowDefaultWidth, height: PanelMetrics.windowDefaultHeight
        )
        .commands {
            SceneCommands()
            ArrangeCommands()
            CommandGroup(after: .toolbar) {
                Toggle("Show Button Names", isOn: $showsButtonNames)
            }
        }
        .windowToolbarLabelStyle(fixed: showsButtonNames ? .titleAndIcon : .iconOnly)
    }
}

/// Keeps the app running with its window closed, so the connection lasts and the window comes back
/// from the Window menu or the Dock. A lone `Window` scene would otherwise quit the app. It holds the
/// scenes' store, so a quit can settle unsaved scenes first (design D6).
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// The scenes as edited, kept here so they outlive the window and a quit can reach them.
    let sceneStore = SceneStore()

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Asks before quitting while scenes are unsaved: in the panel window where it is open, and in
    /// an alert of its own where it is not. The quit goes on after Save All succeeds or Discard.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let writes = sceneStore.currentWrites
        guard let writes, !writes.drafts.unsaved(writes.scenes.scenes).isEmpty else {
            return .terminateNow
        }
        let reply: (Bool) -> Void = { sender.reply(toApplicationShouldTerminate: $0) }
        let windowOpen = sender.windows.contains { $0.isVisible && $0.canBecomeMain }
        if windowOpen {
            sceneStore.unsaved.settle(writes, then: { reply(true) }, cancelled: { reply(false) })
        } else {
            // Asked once `.terminateLater` is returned: Discard and Cancel reply at once, and a reply
            // may not come before it.
            Task { @MainActor [sceneStore] in
                sceneStore.unsaved.askModally(
                    writes, then: { reply(true) }, cancelled: { reply(false) })
            }
        }
        return .terminateLater
    }
}
