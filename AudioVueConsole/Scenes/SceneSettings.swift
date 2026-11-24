import ConsoleCore
import SwiftUI

/// The scene's own settings, shown whenever no card is selected: tabs over the blocks the host's
/// schema declares, so no tab is a long list (`scene-settings`, design D2). The tab chosen is
/// kept for the next scene.
struct SceneSettingsPanel: View {
    let document: SceneDocument
    let editor: SceneEditor?
    let scenes: PanelScenes
    let input: PanelInput?
    @AppStorage("sceneSettingsTab") private var chosenTab = SceneSettingsTab.scene.rawValue

    var body: some View {
        Form {
            if let editor, let facts = scenes.facts {
                let own = facts.sceneSettings(on: shownTab(in: facts))
                if !own.isEmpty {
                    Section {
                        ForEach(own) { SceneSettingRow(declaration: $0, editor: editor) }
                    }
                }
                ForEach(facts.blocks(on: shownTab(in: facts))) { block in
                    BlockSection(
                        block: block, editor: editor, colours: facts.colours, scenes: scenes,
                        calibrationNote: calibrationNote(editor))
                }
            }
        }
        .formStyle(.grouped)
        // A tab's settings start at their top, whatever the last tab was scrolled to.
        .id(chosenTab)
        // The tabs stay above the settings, which scroll under them (maintainer, 2026-11-20).
        .safeAreaInset(edge: .top, spacing: 0) {
            if editor != nil, let facts = scenes.facts {
                Picker("Settings", selection: tab(in: facts)) {
                    ForEach(facts.settingsTabs) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(SceneMetrics.stripPadding)
                .frame(maxWidth: .infinity)
                .background(.bar)
            }
        }
    }

    /// The tab chosen, or the first where the chosen one has nothing to show.
    private func shownTab(in facts: SchemaFacts) -> SceneSettingsTab {
        let tabs = facts.settingsTabs
        return SceneSettingsTab(rawValue: chosenTab).flatMap { tabs.contains($0) ? $0 : nil }
            ?? tabs.first ?? .scene
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

/// One scene block's section: the backdrop, the grid and the colours with views of their own,
/// and any other block's settings in declared order.
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
                Text(SceneSettingsTab.title(ofBlock: block.name))
                if let description = Self.descriptions[block.name] {
                    Text(description).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder private var content: some View {
        ForEach(scenes.facts?.sceneSettings(with: block.name) ?? []) {
            SceneSettingRow(declaration: $0, editor: editor)
        }
        switch block.name {
        case "backdrop":
            BackdropEditor(
                settings: block.settings, editor: editor, colours: colours, scenes: scenes)
        case SceneColours.block:
            ColourGroups(settings: block.settings, editor: editor, colours: colours)
        default:
            if block.name == "analysis", let calibrationNote {
                Label(calibrationNote, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout).foregroundStyle(.orange)
            }
            ForEach(block.settings.settings) {
                BlockSettingRow(
                    block: block.name, declaration: $0, editor: editor, colours: colours,
                    installed: installed($0))
            }
        }
    }

    /// What the scene takes for `declaration` while it leaves it unset, where the setting
    /// declares its source, as its display timeouts take the panel's.
    private func installed(_ declaration: SettingDeclaration) -> JSONValue? {
        scenes.facts?.inheritedValue(
            of: declaration, scene: editor.content.blocks, installed: scenes.installed)
    }

    /// What a section is, said under its title.
    private static let descriptions = [
        "colors": "What each part of a card is drawn in. Hover over one for what it is.",
        "type": "The typeface, and the size of each kind of text.",
        "case": "How each kind of text is written. Units, numbers and symbols keep their case.",
    ]
}

/// One setting of a scene block, read from the scene as edited and changed as one step of the
/// editor's (design D2).
struct BlockSettingRow: View {
    let block: String
    let declaration: SettingDeclaration
    let editor: SceneEditor
    /// The scene's colours, which a colour setting takes a role from.
    let colours: SceneColours
    /// What the panel holds for the setting, which the scene takes while it leaves it unset.
    var installed: JSONValue?

    var body: some View {
        let blocks = editor.content.blocks
        let own = declaration.value(in: blocks[block])
        let taken = own.isSet ? nil : installed
        let value = taken.map { SettingValue.same($0, isSet: false) } ?? own
        SettingRow(
            declaration: declaration, value: value, note: note(value), edit: edit,
            fromScene: fromScene(blocks, taken: taken))
    }

    /// What the scene gives the setting: a colour's drawn colour and roles, or the value an unset
    /// setting takes from the block it inherits from, and whose that is.
    private func fromScene(_ blocks: [String: JSONValue], taken: JSONValue?) -> FromScene {
        let held = blocks[block]?[declaration.key]
        if let colour = FromScene.colour(declaration, held: held, in: blocks, colours) {
            return colour
        }
        return FromScene(
            value: taken,
            owner: declaration.inherits?.document == SettingDeclaration.Source.scene
                ? "scene" : "panel")
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
}

/// One of the scene's own settings, held outside any block, such as its typeface: read from the
/// scene as edited and changed as one step of the editor's.
struct SceneSettingRow: View {
    let declaration: SettingDeclaration
    let editor: SceneEditor

    var body: some View {
        let own = editor.content.blocks[declaration.key]
        SettingRow(
            declaration: declaration,
            value: .same(own ?? declaration.defaultValue, isSet: own != nil), note: nil,
            edit: edit)
    }

    private var edit: SettingEdit? {
        guard editor.readOnly == nil else { return nil }
        let (key, label) = (declaration.key, declaration.label)
        return SettingEdit(
            set: { [editor] in editor.setScene(key, to: $0, label: label) },
            useDefault: { [editor] in editor.useDefault(scene: key, label: label) })
    }
}
