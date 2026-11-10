import ConsoleCore
import SwiftUI

/// The scene's own settings, shown whenever no card is selected: its name and where it is kept,
/// then tabs over the blocks the host's schema declares, so no tab is a long list
/// (`scene-settings`, design D2). The tab chosen is kept for the next scene.
struct SceneSettingsPanel: View {
    let document: SceneDocument
    let editor: SceneEditor?
    let scenes: PanelScenes
    let input: PanelInput?
    @AppStorage("sceneSettingsTab") private var chosenTab = SceneSettingsTab.look.rawValue

    var body: some View {
        Form {
            Section(document.name ?? document.id) {
                LabeledContent("Kept", value: kept)
            }
            if let editor, let facts = scenes.facts {
                Section {
                    Picker("Settings", selection: tab(in: facts)) {
                        ForEach(facts.settingsTabs) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                ForEach(facts.blocks(on: shownTab(in: facts))) { block in
                    BlockSection(
                        block: block, editor: editor, colours: facts.colours, scenes: scenes,
                        calibrationNote: calibrationNote(editor))
                }
            }
        }
        .formStyle(.grouped)
    }

    private var kept: String {
        if SceneDrafts.isCopy(document.id) { return "In this app until saved" }
        return document.builtIn ? "Built in" : "On the panel"
    }

    /// The tab chosen, or the first where the chosen one has nothing to show.
    private func shownTab(in facts: SchemaFacts) -> SceneSettingsTab {
        let tabs = facts.settingsTabs
        return SceneSettingsTab(rawValue: chosenTab).flatMap { tabs.contains($0) ? $0 : nil }
            ?? tabs.first ?? .look
    }

    private func tab(in facts: SchemaFacts) -> Binding<SceneSettingsTab> {
        Binding(get: { shownTab(in: facts) }, set: { chosenTab = $0.rawValue })
    }

    /// What the Analysis section says about calibration at the scene's rate (design D7).
    private func calibrationNote(_ editor: SceneEditor) -> String? {
        CalibrationCoverage.note(
            for: editor.content.blocks, installed: input?.rate, calibrations: input?.calibrations)
    }
}

/// One scene block's section: the backdrop, the grid, the palette and the elements with views of
/// their own, and any other block's settings in declared order.
struct BlockSection: View {
    let block: SchemaFacts.Block
    let editor: SceneEditor
    let colours: SceneColours
    let scenes: PanelScenes
    let calibrationNote: String?

    var body: some View {
        Section {
            content
        } header: {
            VStack(alignment: .leading, spacing: SceneMetrics.settingSpacing) {
                Text(Self.title(block.name))
                if let description = Self.descriptions[block.name] {
                    Text(description).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch block.name {
        case "backdrop":
            BackdropEditor(
                settings: block.settings, editor: editor, colours: colours, scenes: scenes)
        case "grid":
            GridEditor(settings: block.settings, editor: editor, colours: colours)
        case "palette":
            PaletteGrid(settings: block.settings, editor: editor, colours: colours)
        case "elements":
            ElementFamilies(settings: block.settings, editor: editor, colours: colours)
        default:
            if block.name == "analysis", let calibrationNote {
                Label(calibrationNote, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout).foregroundStyle(.orange)
            }
            ForEach(block.settings.settings) {
                BlockSettingRow(
                    block: block.name, declaration: $0, editor: editor, colours: colours)
            }
        }
    }

    /// What the two colour sections are, said under their titles, since their names overlap: the
    /// palette's Shadow is a colour, the elements' Shadow says which colour shadows are drawn in.
    private static let descriptions = [
        "palette": "The scene's colours. Hover over one for what it is used for.",
        "elements": "Which palette colour each part of a card is drawn in.",
    ]

    /// A block's section title from its name, since a block declares no label.
    static func title(_ name: String) -> String {
        name.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

/// One setting of a scene block, read from the scene as edited and changed as one step of the
/// editor's (design D2). An element's choices are shown as the swatches they name, each in its
/// colour in this scene (design D8).
struct BlockSettingRow: View {
    let block: String
    let declaration: SettingDeclaration
    let editor: SceneEditor
    let colours: SceneColours

    var body: some View {
        let value = declaration.value(in: editor.content.blocks[block])
        SettingRow(
            declaration: declaration, value: value, note: note(value), edit: edit,
            choiceLabel: choiceLabel)
    }

    private static let elements = "elements"

    /// An element's choices as their swatches; any other block's choices as they are.
    private var choiceLabel: ((JSONValue) -> ChoiceLabel)? {
        guard block == Self.elements else { return nil }
        return { swatch($0) }
    }

    private func note(_ value: SettingValue) -> SettingNote? {
        guard case .same(let shown, _) = value else { return nil }
        return declaration.note(for: shown)
    }

    private var edit: SettingEdit? {
        guard editor.readOnly == nil else { return nil }
        let (block, key, label) = (block, declaration.key, declaration.label)
        return SettingEdit(
            set: { [editor] in editor.setBlock(block, key, to: $0, label: label) },
            useDefault: { [editor] in editor.useDefault(block: block, key: key, label: label) })
    }

    private func swatch(_ choice: JSONValue) -> ChoiceLabel {
        let name = choice.stringValue ?? choice.text
        return ChoiceLabel(
            text: colours.swatch(name)?.label ?? name,
            colour: colours.colour(ofSwatch: name, in: editor.content.blocks))
    }
}

/// The grid's density, its columns and rows changed together at the scene's aspect, and its other
/// settings, such as the gap (design D5).
struct GridEditor: View {
    let settings: SettingGroup
    let editor: SceneEditor
    let colours: SceneColours

    var body: some View {
        let grid = editor.layout.grid
        let choices = GridDensity.choices(for: grid)
        let index = choices.firstIndex(of: grid) ?? 0
        LabeledContent("Density") {
            Stepper {
                Text(verbatim: "\(grid.cols) × \(grid.rows) cells")
            } onIncrement: {
                if index + 1 < choices.count { editor.setDensity(choices[index + 1]) }
            } onDecrement: {
                if index > 0 { editor.setDensity(choices[index - 1]) }
            }
        }
        .disabled(editor.readOnly != nil)
        if case .tooSmall? = editor.refusal, let refusal = editor.refusal {
            Text(refusal.description).font(.callout).foregroundStyle(.orange)
        }
        ForEach(settings.settings.filter { !Self.cellCounts.contains($0.key) }) {
            BlockSettingRow(block: "grid", declaration: $0, editor: editor, colours: colours)
        }
    }

    /// The grid's settings density sets, never shown on their own.
    private static let cellCounts: Set<String> = ["cols", "rows"]
}
