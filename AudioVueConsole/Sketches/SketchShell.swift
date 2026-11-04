import SwiftUI

/// Sketch A: one panel's window, settings-style, with the panel picked at the top of the sidebar.
/// Opening a scene to edit collapses the sidebar so the editor gets the width.
struct SketchShell: View {
    private let data = SketchData.shared
    @State private var panelID: String?
    @State private var section: SketchSection? = .overview
    @State private var isEditingScene = false
    @State private var columns: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
            SketchSidebar(panels: data.panels, panel: panel, panelID: $panelID, section: $section)
        } detail: {
            detail
        }
        .onChange(of: section) { isEditingScene = false }
        .onChange(of: isEditingScene) { _, editing in
            columns = editing ? .detailOnly : .all
        }
        .frame(minWidth: SketchMetrics.windowMinWidth, minHeight: SketchMetrics.windowMinHeight)
    }

    private var panel: SketchPanel? {
        data.panels.first { $0.id == panelID } ?? data.panels.first
    }

    @ViewBuilder private var detail: some View {
        if let panel {
            switch section ?? .overview {
            case .overview: SketchOverviewPage(panel: panel)
            case .scenes:
                SketchScenesPage(panel: panel, scenes: data.scenes, isEditing: $isEditingScene)
                    .id(panel.id)
            case .input: SketchInputPage()
            case .calibration: SketchCalibrationPage(panel: panel)
            case .display: SketchDisplayPage(panel: panel)
            case .history, .access: SketchLaterPage(section: section ?? .history)
            }
        } else {
            ContentUnavailableView(
                "No Panels", systemImage: "display.trianglebadge.exclamationmark")
        }
    }
}

enum SketchSection: String, CaseIterable, Identifiable {
    case overview, scenes, input, calibration, display, history, access

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
        case .access: "key"
        }
    }
}

struct SketchSidebar: View {
    let panels: [SketchPanel]
    let panel: SketchPanel?
    @Binding var panelID: String?
    @Binding var section: SketchSection?

    var body: some View {
        List(selection: $section) {
            ForEach(SketchSection.allCases) { item in
                Label(item.title, systemImage: item.symbol).tag(item)
            }
        }
        .safeAreaInset(edge: .top) { picker }
        .navigationSplitViewColumnWidth(
            min: SketchMetrics.sidebarMinWidth, ideal: SketchMetrics.sidebarIdealWidth)
    }

    private var picker: some View {
        Menu {
            ForEach(panels) { item in
                Button {
                    panelID = item.id
                } label: {
                    SketchPanelLabel(panel: item)
                }
            }
            Divider()
            Button("Add Panel…") {}
        } label: {
            if let panel { SketchPanelLabel(panel: panel) } else { Text("No Panel") }
        }
        .menuStyle(.borderlessButton)
        .padding(SketchMetrics.pickerPadding)
    }
}

struct SketchPanelLabel: View {
    let panel: SketchPanel

    var body: some View {
        HStack {
            Circle()
                .fill(panel.isUp ? Color.green : Color.secondary)
                .frame(width: SketchMetrics.statusDotSize, height: SketchMetrics.statusDotSize)
            Text(panel.name).font(.headline)
            Text(panel.shapeName).foregroundStyle(.secondary)
        }
    }
}

#Preview("Window") {
    SketchShell()
        .environment(SceneStore())
        .frame(
            width: SketchMetrics.windowDefaultWidth, height: SketchMetrics.windowDefaultHeight)
}
