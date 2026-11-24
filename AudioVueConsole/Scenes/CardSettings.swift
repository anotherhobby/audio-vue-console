import ConsoleCore
import SwiftUI

/// What a settings list changes: the scene's cards, or the setup of a library card, by name
/// (`library-setup`, design D6).
enum CardSettingsTarget: Equatable {
    case cards
    case library(String)
}

/// The settings `declared` for `cards`, one row each in declared order, the colours together
/// under Colours, closed until opened: each row reads every card and a change sets it on them all
/// (`card-settings`), or on the library card's setup the list is for.
struct CardSettingsList: View {
    let declared: SettingGroup
    let cards: [LayoutCard]
    /// Every card kind's settings, so each card is read by its own declaration.
    let groups: [String: SettingGroup]
    /// The scene's colours and the settings its colours block declares.
    let scene: SceneLook
    let editor: SceneEditor
    var target = CardSettingsTarget.cards

    var body: some View {
        ForEach(declared.settings.filter { !Self.isColour($0) }) { rowView($0) }
        let colours = declared.settings.filter(Self.isColour)
        if !colours.isEmpty {
            DisclosureGroup("Colours") {
                ForEach(colours) { row($0) }
            }
        }
    }

    /// A keyed block is a group of its keys' rows; any other setting is one row.
    @ViewBuilder
    private func rowView(_ declaration: SettingDeclaration) -> some View {
        if case .keyed(let block) = declaration.shape {
            KeyedBlockRows(
                declaration: declaration,
                block: block,
                keys: block.keys(
                    picked: KeyedBlock.picked(
                        by: block.keyedBy, across: cards, declaredBy: groups)),
                value: SettingGroup.value(of: declaration.key, across: cards, declaredBy: groups),
                set: blockEdit(declaration, block))
        } else {
            row(declaration)
        }
    }

    private static func isColour(_ declaration: SettingDeclaration) -> Bool {
        if case .roleColour = declaration.shape { return true }
        return false
    }

    private func row(_ declaration: SettingDeclaration) -> SettingRow {
        let value = SettingGroup.value(of: declaration.key, across: cards, declaredBy: groups)
        return SettingRow(
            declaration: declaration, value: value,
            note: SettingGroup.note(of: declaration.key, across: cards, declaredBy: groups),
            edit: edit(declaration), fromScene: fromScene(declaration, value),
            unused: SettingGroup.unusedReason(
                of: declaration.key, across: cards, declaredBy: groups))
    }

    /// What the scene, as edited, gives the setting: the colour it is drawn in and the roles it
    /// may take, or the scene's value an unset one takes (`scene-settings`, design D8). Nothing
    /// for cards that differ.
    private func fromScene(_ declaration: SettingDeclaration, _ value: SettingValue) -> FromScene {
        guard case .same(let held, _) = value else { return FromScene() }
        let blocks = editor.content.blocks
        if let colour = FromScene.colour(declaration, held: held, in: blocks, scene.colours) {
            return colour
        }
        return FromScene(
            value: held == nil
                ? scene.facts?.inheritedValue(
                    of: declaration, scene: blocks, installed: scene.installed) : nil,
            owner: declaration.inherits?.document == SettingDeclaration.Source.install
                ? "panel" : "scene")
    }

    /// The row's changes, or nil where the scene is read-only and the list is for its cards.
    private func edit(_ declaration: SettingDeclaration) -> SettingEdit? {
        writes(declaration).map { SettingEdit(set: $0.set, useDefault: $0.useDefault) }
    }

    /// One setting's writes on the list's target: editor steps on these cards, or changes to the
    /// library card's setup, which a read-only scene's library takes too.
    private func writes(_ declaration: SettingDeclaration) -> SettingWrites? {
        let (key, label) = (declaration.key, declaration.label)
        if case .library(let name) = target {
            return SettingWrites(
                set: { [editor] in editor.setSetup(key, to: $0, on: name) },
                useDefault: { [editor] in editor.unsetSetup(key, on: name) },
                change: { [editor] in editor.editSetup(key, on: name, $0) })
        }
        guard editor.readOnly == nil else { return nil }
        let ids = Set(cards.map(\.id))
        return SettingWrites(
            set: { [editor] in editor.set(key, to: $0, label: label, on: ids) },
            useDefault: { [editor] in editor.useDefault(key, label: label, on: ids) },
            change: { [editor] in editor.editSetting(key, label: label, on: ids, $0) })
    }
}

/// One setting's writes: set a value, use the default, or change each holder's own value.
private struct SettingWrites {
    let set: (JSONValue) -> Void
    let useDefault: () -> Void
    let change: ((JSONValue?) -> JSONValue?) -> Void
}

/// Writes one key's span of a keyed block on the cards, its segment size included, each card's own
/// block taking the span where the span checks; nil where the scene is read-only
/// (`meter-scales-editor`, design D3; `meter-segment-size`, design D2).
extension CardSettingsList {
    fileprivate func blockEdit(
        _ declaration: SettingDeclaration, _ block: KeyedBlock
    ) -> ((String, KeyedBlock.Span) -> Void)? {
        guard let writes = writes(declaration) else { return nil }
        return { name, span in
            writes.change { current in
                switch block.edit(current, key: name, span: span) {
                case .success(let next): next
                case .failure: current
                }
            }
        }
    }
}

/// How a row changes its setting. A read-only scene's rows have none.
struct SettingEdit {
    let set: (JSONValue) -> Void
    let useDefault: () -> Void
}

/// What a card's unset settings are read against: the scene's colours, and the host's facts and
/// install blocks a setting's declared source is found in.
struct SceneLook {
    let colours: SceneColours
    let facts: SchemaFacts?
    let installed: [String: JSONValue]

    init(_ scenes: PanelScenes) {
        facts = scenes.facts
        colours = scenes.facts?.colours ?? .none
        installed = scenes.installed
    }
}

/// One of the scene's roles as a card's colour may take it, in its colour in this scene.
struct RoleChoice: Identifiable {
    let role: SceneColours.Role
    let colour: HexColour?

    var id: String { role.id }
}

/// What the scene gives a card's setting: the colour a colour setting is drawn in, the roles it
/// may take, and the scene's value a setting with no default of its own takes while unset.
struct FromScene {
    var drawn: DrawnColour?
    var roles: [RoleChoice] = []
    var value: JSONValue?
    /// Whose value an unset setting takes: the scene's, or the panel's for a scene's own setting.
    var owner = "scene"

    /// What a colour setting holding `held` takes from a scene with `blocks` and `colours`, as
    /// edited: the colour it is drawn in and the roles it may take, each in the scene's colour for
    /// it. Nil for a setting that is no role colour. A card's colour and a scene block's alike
    /// (`card-settings`, `scene-settings`; `track-native-logo` design D1).
    static func colour(
        _ declaration: SettingDeclaration, held: JSONValue?, in blocks: [String: JSONValue],
        _ colours: SceneColours
    ) -> FromScene? {
        guard case .roleColour(let roles) = declaration.shape else { return nil }
        return FromScene(
            drawn: declaration.drawnColour(held, in: blocks, colours: colours),
            roles: roles.compactMap { id in
                colours.role(id).map { role in
                    RoleChoice(role: role, colour: colours.colour(of: id, in: blocks))
                }
            })
    }
}

/// One setting, compact: its label, its control with Use Default beside it where the scene sets it,
/// its help on hover, and under it only what needs saying: the standard it is off, that the cards
/// differ, or the scene's colour or value it takes (design D5; `scene-settings`).
/// Nothing here says Reset, which is the panel's measurement reset.
struct SettingRow: View {
    let declaration: SettingDeclaration
    let value: SettingValue
    let note: SettingNote?
    let edit: SettingEdit?
    /// What the scene gives the setting, shown in its control and said under it.
    var fromScene = FromScene()
    /// Why the setting has no effect as the card's other settings stand, which greys it out
    /// (`scene-settings`, design D9).
    var unused: String?

    var body: some View {
        VStack(alignment: .leading, spacing: SceneMetrics.settingSpacing) {
            LabeledContent(declaration.label) {
                HStack(spacing: SceneMetrics.settingSpacing) {
                    SettingControl(
                        declaration: declaration, value: value,
                        edit: unused == nil ? edit : nil, fromScene: fromScene)
                    UseDefaultButton(action: value.isSet ? edit?.useDefault : nil)
                }
            }
            .foregroundStyle(unused == nil ? .primary : .secondary)
            if case .offStandard(let document)? = note {
                Label("Outside \(document)", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.orange)
            }
            if let unused {
                Text(unused).font(.caption).foregroundStyle(.secondary)
            } else if let state {
                Text(state).font(.caption).foregroundStyle(.secondary)
            }
        }
        .help(declaration.help)
    }

    /// What needs saying of a value the card does not hold alone: that the cards differ, the
    /// scene's role a colour takes, or that an unset setting takes the scene's.
    private var state: String? {
        if case .mixed = value { return "Mixed" }
        if let caption = fromScene.drawn?.caption { return caption }
        return fromScene.value == nil ? nil : "Uses the \(fromScene.owner)'s \(declaration.label)"
    }
}

/// Use Default, as a small button beside a setting the scene sets: it removes the setting, so the
/// default applies. Never called Reset, the panel's measurement reset. With no action it is hidden
/// but keeps its space, so the control beside it never moves when it appears under the pointer.
struct UseDefaultButton: View {
    let action: (() -> Void)?

    var body: some View {
        Button("Use Default", systemImage: "arrow.uturn.backward") { action?() }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help("Use Default")
            .opacity(action == nil ? 0 : 1)
            .disabled(action == nil)
            .accessibilityHidden(action == nil)
    }
}

/// The control a setting's shape takes: a switch, a picker of its choices, a colour well, a colour
/// well with the scene's roles beside it, a number field, or its value as text where the app
/// cannot edit it.
struct SettingControl: View {
    let declaration: SettingDeclaration
    let value: SettingValue
    let edit: SettingEdit?
    /// What the scene gives the setting: a card colour's drawn colour and roles, or the value an
    /// unset number takes.
    var fromScene = FromScene()

    var body: some View {
        Group {
            switch declaration.shape {
            case .boolean:
                Toggle(declaration.label, isOn: flag).labelsHidden()
            case .choice(let choices):
                Picker(declaration.label, selection: choice) {
                    ForEach(choices, id: \.self) {
                        Text(declaration.label(of: $0)).tag(Optional($0))
                    }
                }
                .labelsHidden()
            case .colour:
                ColourWell(hex: shown?.stringValue, set: edit?.set)
            case .roleColour:
                ColourWell(hex: fromScene.drawn?.colour.hex, set: edit?.set)
                RoleMenu(roles: fromScene.roles, taken: fromScene.drawn?.role?.id, set: edit?.set)
            case .number where declaration.isAmount:
                AmountSlider(
                    declaration: declaration, value: shown ?? fromScene.value, set: edit?.set)
            case .number, .integer:
                NumberField(
                    declaration: declaration, value: shown ?? fromScene.value, set: edit?.set,
                    isMixed: isMixed)
            case .keyed:
                // A keyed block's rows are `KeyedBlockRows`, never a single control.
                EmptyView()
            case .other, .colours:
                Text(shown?.text ?? "None").foregroundStyle(.secondary)
            }
        }
        .disabled(edit == nil)
    }

    /// The value every card takes, or nil where they differ.
    private var shown: JSONValue? { value.shown }

    private var isMixed: Bool {
        if case .mixed = value { return true }
        return false
    }

    private var flag: Binding<Bool> {
        Binding(get: { shown?.boolValue ?? false }, set: { edit?.set(.bool($0)) })
    }

    private var choice: Binding<JSONValue?> {
        Binding(get: { shown }, set: { picked in picked.map { edit?.set($0) } })
    }
}
