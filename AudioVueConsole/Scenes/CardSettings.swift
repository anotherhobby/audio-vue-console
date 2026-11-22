import ConsoleCore
import SwiftUI

/// The settings `declared` for `cards`, one row each in declared order, the colours together
/// under Colours, closed until opened: each row reads every card and a change sets it on them all
/// (`card-settings`).
struct CardSettingsList: View {
    let declared: SettingGroup
    let cards: [LayoutCard]
    /// Every card kind's settings, so each card is read by its own declaration.
    let groups: [String: SettingGroup]
    /// The scene's colours and the settings its colours block declares.
    let scene: SceneLook
    let editor: SceneEditor

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
        guard case .roleColour(let roles) = declaration.shape else {
            return FromScene(
                value: held == nil
                    ? scene.facts?.inheritedValue(
                        of: declaration, scene: blocks, installed: scene.installed) : nil,
                owner: declaration.inherits?.document == SettingDeclaration.Source.install
                    ? "panel" : "scene")
        }
        return FromScene(
            drawn: declaration.drawnColour(held, in: blocks, colours: scene.colours),
            roles: roles.compactMap { id in
                scene.colours.role(id).map { role in
                    RoleChoice(role: role, colour: scene.colours.colour(of: id, in: blocks))
                }
            })
    }

    /// The row's changes as editor steps on these cards, or nil where the scene is read-only.
    private func edit(_ declaration: SettingDeclaration) -> SettingEdit? {
        guard editor.readOnly == nil else { return nil }
        let (ids, key, label) = (Set(cards.map(\.id)), declaration.key, declaration.label)
        return SettingEdit(
            set: { [editor] in editor.set(key, to: $0, label: label, on: ids) },
            useDefault: { [editor] in editor.useDefault(key, label: label, on: ids) })
    }
}

/// Writes one key's span of a keyed block on the cards, each card's own block taking the span
/// where the span checks; nil where the scene is read-only (`meter-scales-editor`, design D3).
extension CardSettingsList {
    fileprivate func blockEdit(
        _ declaration: SettingDeclaration, _ block: KeyedBlock
    ) -> ((String, KeyedBlock.Span) -> Void)? {
        guard editor.readOnly == nil else { return nil }
        let (ids, key, label) = (Set(cards.map(\.id)), declaration.key, declaration.label)
        return { [editor] name, span in
            editor.editSetting(key, label: label, on: ids) { current in
                switch block.edit(
                    current, key: name, lo: span.lo, hi: span.hi, anchor: span.anchor)
                {
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
                    if value.isSet, let edit { UseDefaultButton(action: edit.useDefault) }
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
/// default applies. Never called Reset, the panel's measurement reset.
struct UseDefaultButton: View {
    let action: () -> Void

    var body: some View {
        Button("Use Default", systemImage: "arrow.uturn.backward", action: action)
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help("Use Default")
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
