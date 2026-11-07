import ConsoleCore
import SwiftUI

/// The selected card's place on the grid, the selection's Group and Ungroup with the reason Group
/// is refused, or the scene's own facts when nothing is selected.
struct SceneInspector: View {
    let editor: SceneEditor?
    let document: SceneDocument

    var body: some View {
        let cards = editor?.selectedCards ?? []
        if editor != nil, let card = cards.first, cards.count == 1 {
            single(card)
        } else if let editor, !cards.isEmpty {
            several(cards, editor)
        } else {
            SceneSettingsPanel(document: document, grid: editor?.layout.grid)
        }
    }

    private func single(_ card: LayoutCard) -> some View {
        Form {
            Section(card.kind.replacingOccurrences(of: "_", with: " ")) {
                LabeledContent("Position") {
                    Text(verbatim: "column \(card.cells.col), row \(card.cells.row)")
                }
                LabeledContent("Size") {
                    Text(verbatim: "\(card.cells.cols) × \(card.cells.rows) cells")
                }
                LabeledContent("Group", value: card.group ?? "None")
            }
        }
        .formStyle(.grouped)
    }

    private func several(_ cards: [LayoutCard], _ editor: SceneEditor) -> some View {
        Form {
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
        .formStyle(.grouped)
    }
}

/// The scene's own facts, shown whenever no card is selected: its name, grid, and whether it is a
/// built-in or a copy made in the app.
struct SceneSettingsPanel: View {
    let document: SceneDocument
    let grid: CellSize?

    var body: some View {
        Form {
            Section(document.name ?? document.id) {
                if let grid {
                    LabeledContent("Grid") { Text(verbatim: "\(grid.cols) × \(grid.rows) cells") }
                }
                LabeledContent("Kept", value: kept)
            }
        }
        .formStyle(.grouped)
    }

    private var kept: String {
        if SceneDrafts.isCopy(document.id) { return "In this app until it quits" }
        return document.builtIn ? "Built in" : "On the panel"
    }
}
