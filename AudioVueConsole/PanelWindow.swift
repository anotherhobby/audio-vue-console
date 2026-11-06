import ConsoleCore
import SwiftUI

/// The app's one window for a panel, settings-style, with the panel picked at the top of the Panel
/// page (`panel-window`). It connects at launch, and watches the paired host's live state while
/// it is open. Opening a scene to edit collapses the sidebar so the editor gets the width. The pages
/// other than Panel still show sample values, until their own changes build them.
struct PanelWindow: View {
    /// The window's id, which the Window menu and the Dock bring it back by.
    static let windowID = "panel"

    @Bindable var connection: HostConnection
    let discovery: PanelDiscovery
    @State private var section: PanelSection? = .panel
    @State private var isEditingScene = false
    @State private var columns: NavigationSplitViewVisibility = .all
    @State private var live: LiveState?
    @State private var isAddingPanel = false

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
        .sheet(isPresented: $isAddingPanel) { AddPanelSheet(connection: connection) }
        .task { await connection.connectAtLaunch() }
        .task(id: WatchKey(connection)) {
            live = connection.liveState()
            await live?.watch()
        }
        .frame(minWidth: PanelMetrics.windowMinWidth, minHeight: PanelMetrics.windowMinHeight)
    }

    @ViewBuilder private var detail: some View {
        switch section ?? .panel {
        case .panel:
            PanelPage(connection: connection, live: live, panelName: label?.name) {
                isAddingPanel = true
            }
            .toolbar { picker }
            .toolbar(removing: .title)
        case .scenes, .input, .calibration, .display, .history:
            SamplePage(section: section ?? .panel, isEditingScene: $isEditingScene)
        }
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

    /// The picker: the panel held, and the other panels found, each connected to when chosen
    /// (`panel-window`).
    private var picker: PanelPicker {
        PanelPicker(
            panel: label,
            others: discovery.others(heldID: heldID, heldAddress: connection.address),
            mayBrowse: discovery.mayBrowse,
            choose: { panel in Task { await connection.connect(to: panel) } },
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
    case panel, scenes, input, calibration, display, history

    var id: Self { self }
    var title: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .panel: "gauge.with.dots.needle.33percent"
        case .scenes: "rectangle.3.group"
        case .input: "waveform"
        case .calibration: "tuningfork"
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

/// A page still built on sample values, for the first sample panel.
private struct SamplePage: View {
    let section: PanelSection
    @Binding var isEditingScene: Bool
    private let data = SketchData.shared

    var body: some View {
        if let panel = data.panels.first {
            switch section {
            case .scenes:
                SketchScenesPage(panel: panel, scenes: data.scenes, isEditing: $isEditingScene)
            case .input: SketchInputPage()
            case .calibration: SketchCalibrationPage(panel: panel)
            case .display: SketchDisplayPage(panel: panel)
            case .panel, .history: SketchLaterPage(section: section)
            }
        } else {
            ContentUnavailableView("No Sample Data", systemImage: "tray")
        }
    }
}
