import ConsoleCore
import SwiftUI

/// The palette as colour wells under their families, each named beneath and explained on hover,
/// with Use Default beside a name the scene sets (`scene-settings`, "The palette and the elements
/// are shown by family").
struct PaletteGrid: View {
    let settings: SettingGroup
    let editor: SceneEditor
    let colours: SceneColours

    var body: some View {
        ForEach(colours.families(of: settings, in: Self.block) ?? []) { family in
            VStack(alignment: .leading, spacing: SceneMetrics.settingSpacing) {
                Text(family.name.capitalized).font(.caption).foregroundStyle(.secondary)
                LazyVGrid(columns: Self.columns, alignment: .leading) {
                    ForEach(family.settings) { SwatchCell(declaration: $0, editor: editor) }
                }
            }
        }
    }

    private static let block = "palette"
    private static let columns = [GridItem(.adaptive(minimum: SceneMetrics.swatchCellWidth))]
}

/// One palette colour: its well, its name, and Use Default where the scene sets it.
struct SwatchCell: View {
    let declaration: SettingDeclaration
    let editor: SceneEditor

    var body: some View {
        let value = declaration.value(in: editor.content.blocks[Self.block])
        VStack(spacing: SceneMetrics.settingSpacing) {
            ColourWell(hex: value.shown?.stringValue, set: edit?.set)
            HStack(spacing: 2) {
                Text(declaration.label).font(.caption2).lineLimit(1)
                    .foregroundStyle(value.isSet ? .primary : .secondary)
                if value.isSet, let edit {
                    UseDefaultButton(action: edit.useDefault).controlSize(.mini)
                }
            }
        }
        .help("\(declaration.label): \(declaration.help)")
        .disabled(edit == nil)
    }

    private static let block = "palette"

    private var edit: SettingEdit? {
        guard editor.readOnly == nil else { return nil }
        let (key, label) = (declaration.key, declaration.label)
        return SettingEdit(
            set: { [editor] in editor.setBlock(Self.block, key, to: $0, label: label) },
            useDefault: { [editor] in editor.useDefault(block: Self.block, key: key, label: label) }
        )
    }
}

/// The elements under their families, each family collapsed until opened and saying how many of
/// its parts the scene points elsewhere, each part one row: its name and the swatch it is drawn
/// in, chosen from the palette with each swatch's chip.
struct ElementFamilies: View {
    let settings: SettingGroup
    let editor: SceneEditor
    let colours: SceneColours

    var body: some View {
        ForEach(colours.families(of: settings, in: Self.block) ?? []) { family in
            DisclosureGroup {
                ForEach(family.settings) {
                    BlockSettingRow(
                        block: Self.block, declaration: $0, editor: editor, colours: colours)
                }
            } label: {
                LabeledContent(family.name.capitalized, value: summary(family))
            }
        }
    }

    private static let block = "elements"

    /// How many of the family's parts the scene points at another swatch, or how many it has.
    private func summary(_ family: SceneColours.Family) -> String {
        let block = editor.content.blocks[Self.block]
        let changed = family.settings.filter { block?[$0.key] != nil }.count
        return changed > 0 ? "\(changed) changed" : "\(family.settings.count) parts"
    }
}
