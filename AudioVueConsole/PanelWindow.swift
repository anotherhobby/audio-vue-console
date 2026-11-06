import ConsoleCore
import SwiftUI

/// The app's one window for a panel, settings-style, with the panel picked at the top of the
/// sidebar (`panel-window`). It connects at launch, and watches the paired host's live state while
/// it is open. Opening a scene to edit collapses the sidebar so the editor gets the width. The pages
/// other than Overview still show sample values, until their own changes build them.
struct PanelWindow: View {
    /// The window's id, which the Window menu and the Dock bring it back by.
    static let windowID = "panel"

    @Bindable var connection: HostConnection
    @State private var section: PanelSection? = .overview
    @State private var isEditingScene = false
    @State private var columns: NavigationSplitViewVisibility = .all
    @State private var live: LiveState?
    @State private var isAddingPanel = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
            PanelSidebar(panel: panelLabel, section: $section) { isAddingPanel = true }
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
        switch section ?? .overview {
        case .overview:
            OverviewPage(connection: connection, live: live) { isAddingPanel = true }
        case .scenes, .input, .calibration, .display, .history:
            SamplePage(section: section ?? .overview, isEditingScene: $isEditingScene)
        }
    }

    /// The panel as the picker names it, with the host's identity only while paired.
    private var panelLabel: PanelLabel? {
        PanelLabel(
            address: connection.address,
            host: connection.isPaired == true ? connection.host : nil,
            state: live?.state, isLive: live?.isLive == true)
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

/// The sidebar's pages. Access went: pairing and the clients are in the Overview.
enum PanelSection: String, CaseIterable, Identifiable {
    case overview, scenes, input, calibration, display, history

    var id: Self { self }
    var title: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .overview: "gauge.with.dots.needle.33percent"
        case .scenes: "rectangle.3.group"
        case .input: "waveform"
        case .calibration: "tuningfork"
        case .display: "display"
        case .history: "clock.arrow.circlepath"
        }
    }
}

struct PanelSidebar: View {
    let panel: PanelLabel?
    @Binding var section: PanelSection?
    let addPanel: () -> Void

    var body: some View {
        List(selection: $section) {
            ForEach(PanelSection.allCases) { item in
                Label(item.title, systemImage: item.symbol).tag(item)
            }
        }
        .safeAreaInset(edge: .top) { picker }
        .navigationSplitViewColumnWidth(
            min: PanelMetrics.sidebarMinWidth, ideal: PanelMetrics.sidebarIdealWidth)
    }

    /// The panel's up mark and shape sit beside the menu, since a borderless menu shows its label
    /// as plain text only.
    private var picker: some View {
        HStack {
            if let panel { UpMark(isUp: panel.isUp) }
            Menu {
                if let panel { Text(verbatim: panel.name) }
                Divider()
                Button("Add Panel…", action: addPanel)
            } label: {
                Text(verbatim: panel?.name ?? "No Panel").font(.headline)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            if let shape = panel?.shape { Text(verbatim: shape).foregroundStyle(.secondary) }
        }
        .padding(PanelMetrics.pickerPadding)
    }
}

/// Whether the panel is up: green, or grey for anything else.
struct UpMark: View {
    let isUp: Bool

    var body: some View {
        Circle()
            .fill(isUp ? Color.green : Color.secondary)
            .frame(width: PanelMetrics.statusDotSize, height: PanelMetrics.statusDotSize)
            .accessibilityLabel(isUp ? "Up" : "Not up")
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
            case .overview, .history: SketchLaterPage(section: section)
            }
        } else {
            ContentUnavailableView("No Sample Data", systemImage: "tray")
        }
    }
}
