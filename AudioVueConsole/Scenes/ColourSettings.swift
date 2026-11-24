import ConsoleCore
import SwiftUI

/// The scene's colours as colour wells under their headings, the groups of roles then each
/// meaning scale, each named beneath and explained on hover, then the settings no heading holds,
/// such as the shadow's amount, as rows (`scene-settings`, "The scene's colours are shown by
/// group").
struct ColourGroups: View {
    let settings: SettingGroup
    let editor: SceneEditor
    let colours: SceneColours

    var body: some View {
        ForEach(colours.groups(of: settings)) { group in
            VStack(alignment: .leading, spacing: SceneMetrics.settingSpacing) {
                Text(group.label).font(.caption).foregroundStyle(.secondary)
                LazyVGrid(columns: Self.columns, alignment: .leading) {
                    ForEach(group.settings) { ColourCell(declaration: $0, editor: editor) }
                }
            }
        }
        ForEach(colours.ungrouped(of: settings)) {
            BlockSettingRow(
                block: SceneColours.block, declaration: $0, editor: editor, colours: colours)
        }
    }

    private static let columns = [GridItem(.adaptive(minimum: SceneMetrics.swatchCellWidth))]
}

/// One of the scene's colours: its well, its name, and Use Default where the scene sets it.
struct ColourCell: View {
    let declaration: SettingDeclaration
    let editor: SceneEditor

    var body: some View {
        let value = declaration.value(in: editor.content.blocks[SceneColours.block])
        VStack(spacing: SceneMetrics.settingSpacing) {
            ColourWell(hex: value.shown?.stringValue, set: edit?.set)
            HStack(spacing: 2) {
                Text(declaration.label).font(.caption2).lineLimit(1)
                    .foregroundStyle(value.isSet ? .primary : .secondary)
                UseDefaultButton(action: value.isSet ? edit?.useDefault : nil)
                    .controlSize(.mini)
            }
        }
        .help("\(declaration.label): \(declaration.help)")
        .disabled(edit == nil)
    }

    private var edit: SettingEdit? {
        guard editor.readOnly == nil else { return nil }
        let (block, key, label) = (SceneColours.block, declaration.key, declaration.label)
        return SettingEdit(
            set: { [editor] in editor.setBlock(block, key, to: $0, label: label) },
            useDefault: { [editor] in editor.useDefault(block: block, key: key, label: label) })
    }
}
