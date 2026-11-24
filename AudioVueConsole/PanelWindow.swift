import ConsoleCore
import SwiftUI

/// The app's one window for a panel, settings-style, with the panel picked at the top of the Panel
/// page (`panel-window`). It connects at launch, watches the paired host's live state while it is
/// open, and starts the renderer once paired. Opening a scene to edit collapses the sidebar so the
/// editor gets the width. History is still a placeholder, until its own change builds it.
struct PanelWindow: View {
    /// The window's id, which the Window menu and the Dock bring it back by.
    static let windowID = "panel"

    @Bindable var connection: HostConnection
    let discovery: PanelDiscovery
    let renderer: Renderer
    /// The app's calibration, fed the live state and whether it is current while the window
    /// watches it.
    let calibration: CalibrationPass?
    @State private var section: PanelSection? = .panel
    @State private var isEditingScene = false
    @State private var columns: NavigationSplitViewVisibility = .all
    @State private var live: LiveState?
    @State private var isAddingPanel = false
    @Environment(SceneStore.self) private var store

    var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
            PanelSidebar(section: $section)
        } detail: {
            detail
        }
        .onChange(of: section) { isEditingScene = false }
        .onChange(of: isEditingScene) { _, editing in
            columns = editing ? .detailOnly : .all
        }
        .sheet(isPresented: $isAddingPanel) {
            AddPanelSheet(connection: connection, calibration: calibration)
        }
        .unsavedScenesAlerts(store.unsaved, shown: !isAddingPanel)
        .onChange(of: live?.state?.sceneSpec) { _, spec in store.follow(onScreen: spec) }
        .onChange(of: live?.state?.grid, initial: true) { _, grid in store.follow(grid: grid) }
        .onChange(of: live?.state) { forwardLiveState() }
        .onChange(of: live?.isLive) { forwardLiveState() }
        .task { await connection.connectAtLaunch() }
        .task(id: WatchKey(connection)) {
            live = connection.liveState()
            await live?.watch()
        }
        .task(id: WatchKey(connection)) { await startRendering() }
        .frame(minWidth: PanelMetrics.windowMinWidth, minHeight: PanelMetrics.windowMinHeight)
    }

    /// Starts the helper once the app is paired and compares its code with the panel's
    /// (`render-helper`, `card-code`). The scenes are read meanwhile, and drawn ahead with the
    /// library's tiles, so the Scenes page and a scene show at once when opened
    /// (`scene-rendering`).
    private func startRendering() async {
        renderer.forgetCode()
        let paired = connection.isPaired == true
        store.follow(host: paired ? connection.host?.id : nil)
        let scenes = paired ? connection.makeScenes() : nil
        store.scenes = scenes
        guard let scenes else { return }
        async let started: Void = renderer.start()
        await scenes.load()
        // Last launch's thumbnails show while the helper starts. A new pairing's drafts were
        // forgotten with the old panel's grid, so the grid is followed again.
        store.follow(grid: live?.state?.grid)
        store.restoreThumbnails()
        await started
        await renderer.checkCode(with: scenes)
        await store.drawAhead(with: renderer)
    }

    @ViewBuilder private var detail: some View {
        switch section ?? .panel {
        case .panel:
            PanelPage(
                connection: connection, live: live, renderer: renderer, panelName: label?.name
            ) {
                isAddingPanel = true
            }
            .toolbar { picker }
            .toolbar(removing: .title)
        case .scenes:
            ScenesPage(
                connection: connection, renderer: renderer, live: live,
                isEditing: $isEditingScene)
        case .capture:
            CapturePage(
                connection: connection, live: live, renderer: renderer, pass: calibration)
        case .display:
            DisplayPage(connection: connection)
        case .history:
            SketchLaterPage(section: .history)
        }
    }

    /// Passes the live state, and whether it is current, to the calibration, which stops a pass
    /// between rates once the panel is down or no longer heard from.
    private func forwardLiveState() {
        calibration?.observe(live?.state, isLive: live?.isLive ?? false)
    }

    /// The id of the panel held, when the app knows it.
    private var heldID: String? { connection.host?.id ?? connection.foundPanel?.id }

    /// The panel held, named with the host's identity only while paired, else by its address, and
    /// discovered while found and not paired: the one name the picker, the prompt and the status
    /// use (discovery design D10, D11).
    private var label: PanelLabel? {
        let found =
            discovery.held(id: heldID, address: connection.address) ?? connection.foundPanel
        return PanelLabel(
            address: connection.address,
            host: connection.isPaired == true ? connection.host : nil,
            foundName: found?.name)
    }

    /// The picker: the panel held, and the other panels found, each connected to when chosen,
    /// once any calibration under way and any unsaved scenes are settled (`panel-window`,
    /// `calibration-run`).
    private var picker: PanelPicker {
        PanelPicker(
            panel: label,
            others: discovery.others(heldID: heldID, heldAddress: connection.address),
            mayBrowse: discovery.mayBrowse,
            choose: { panel in
                RunUnderWay.settle(calibration, before: "Switch Panels") {
                    store.unsaved.settle(store.currentWrites) {
                        Task { await connection.connect(to: panel) }
                    }
                }
            },
            addPanel: { isAddingPanel = true })
    }

    /// What the live state is for: the host, and whether it is paired. A new key, as after pairing
    /// again, which closes its sheet, starts the watch again with the token now kept.
    private struct WatchKey: Hashable {
        let address: HostAddress?
        let paired: Bool?
        let isPairing: Bool

        @MainActor init(_ connection: HostConnection) {
            address = connection.address
            paired = connection.isPaired
            isPairing = connection.pairing != nil
        }
    }
}

/// The sidebar's pages. Access went: pairing and the clients are on the Panel page.
enum PanelSection: String, CaseIterable, Identifiable {
    case panel, scenes, capture, display, history

    var id: Self { self }
    var title: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .panel: "gauge.with.dots.needle.33percent"
        case .scenes: "rectangle.3.group"
        case .capture: "tuningfork"
        case .display: "display"
        case .history: "clock.arrow.circlepath"
        }
    }
}

struct PanelSidebar: View {
    @Binding var section: PanelSection?

    var body: some View {
        List(selection: $section) {
            ForEach(PanelSection.allCases) { item in
                Label(item.title, systemImage: item.symbol).tag(item)
            }
        }
        .navigationSplitViewColumnWidth(
            min: PanelMetrics.sidebarMinWidth, ideal: PanelMetrics.sidebarIdealWidth)
    }

}
