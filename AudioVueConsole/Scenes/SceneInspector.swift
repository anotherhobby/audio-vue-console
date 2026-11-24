import ConsoleCore
import SwiftUI

/// The selected card's place on the grid and its settings; for several, Group and Ungroup with the
/// reason Group is refused, the settings they share, then each card's own; or the scene's own facts
/// when nothing is selected (`card-settings`).
struct SceneInspector: View {
    let editor: SceneEditor?
    let document: SceneDocument
    let scenes: PanelScenes
    let input: PanelInput?

    /// Each card kind's settings, as the panel's schema declares them.
    private var settings: [String: SettingGroup] { scenes.facts?.settings ?? [:] }
    private var look: SceneLook { SceneLook(scenes) }

    var body: some View {
        let cards = editor?.selectedCards ?? []
        if let editor, let card = cards.first, cards.count == 1 {
            single(card, editor)
        } else if let editor, !cards.isEmpty {
            several(cards, editor)
        } else {
            SceneSettingsPanel(document: document, editor: editor, scenes: scenes, input: input)
        }
    }

    private func single(_ card: LayoutCard, _ editor: SceneEditor) -> some View {
        Form {
            Section(Self.title(card)) {
                LabeledContent("Position") {
                    Text(verbatim: "column \(card.cells.col), row \(card.cells.row)")
                }
                LabeledContent("Size") {
                    Text(verbatim: "\(card.cells.cols) × \(card.cells.rows) cells")
                }
                LabeledContent("Group", value: card.group ?? "None")
            }
            Section("Settings") { ownSettings(card, editor) }
        }
        .formStyle(.grouped)
        .id(editor.selection)
    }

    private func several(_ cards: [LayoutCard], _ editor: SceneEditor) -> some View {
        let shared = SettingGroup.shared(cards.map { settings[$0.kind] ?? SettingGroup([]) })
        return Form {
            grouping(cards, editor)
            if !shared.settings.isEmpty {
                Section("Shared Settings") {
                    CardSettingsList(
                        declared: shared, cards: cards, groups: settings, scene: look,
                        editor: editor)
                }
            }
            ForEach(cards) { card in
                Section {
                    DisclosureGroup(Self.title(card)) { ownSettings(card, editor) }
                }
            }
        }
        .formStyle(.grouped)
        .id(editor.selection)
    }

    private func grouping(_ cards: [LayoutCard], _ editor: SceneEditor) -> some View {
        Section {
            LabeledContent("Selected") { Text(verbatim: "\(cards.count) cards") }
            HStack {
                Button("Group") { editor.group() }
                    .disabled(editor.groupRefusal != nil)
                Button("Ungroup") { editor.ungroup() }
                    .disabled(!editor.canUngroup)
            }
            if let refusal = editor.groupRefusal {
                Text(refusal.description).font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    /// Every setting `card` declares, changing that card alone.
    @ViewBuilder private func ownSettings(_ card: LayoutCard, _ editor: SceneEditor) -> some View {
        if let declared = settings[card.kind], !declared.settings.isEmpty {
            CardSettingsList(
                declared: declared, cards: [card], groups: settings, scene: look, editor: editor)
        } else {
            Text("This card has no settings.").foregroundStyle(.secondary)
        }
    }

    private static func title(_ card: LayoutCard) -> String {
        SceneSettingsTab.title(ofCard: card.kind)
    }
}
