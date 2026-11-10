import AppKit
import ConsoleCore
import SwiftUI

/// The settings `declared` for `cards`, one row each in declared order: each row reads every card
/// and a change sets it on them all (`card-settings`).
struct CardSettingsList: View {
    let declared: SettingGroup
    let cards: [LayoutCard]
    /// Every card kind's settings, so each card is read by its own declaration.
    let groups: [String: SettingGroup]
    let colours: SceneColours
    let editor: SceneEditor

    var body: some View {
        ForEach(declared.settings) { declaration in
            let value = SettingGroup.value(of: declaration.key, across: cards, declaredBy: groups)
            SettingRow(
                declaration: declaration, value: value,
                note: SettingGroup.note(of: declaration.key, across: cards, declaredBy: groups),
                edit: edit(declaration), inherited: inherited(declaration, value),
                unused: SettingGroup.unusedReason(
                    of: declaration.key, across: cards, declaredBy: groups))
        }
    }

    /// The colour an unset colour is drawn in, from the scene's blocks as edited (`scene-settings`,
    /// design D8); nil for any other value.
    private func inherited(_ declaration: SettingDeclaration, _ value: SettingValue)
        -> InheritedColour?
    {
        guard case .same(nil, isSet: false) = value else { return nil }
        return declaration.inheritedColour(in: editor.content.blocks, colours: colours)
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

/// How a row changes its setting. A read-only scene's rows have none.
struct SettingEdit {
    let set: (JSONValue) -> Void
    let useDefault: () -> Void
}

/// How a choice is shown: its words, and the colour of the swatch it names where it names one.
struct ChoiceLabel {
    let text: String
    let colour: HexColour?
}

/// One setting, compact: its label, its control with Use Default beside it where the scene sets it,
/// its help on hover, and under it only what needs saying: the standard it is off, that the cards
/// differ, or the element and swatch an unset colour is drawn in (design D5; `scene-settings`).
/// Nothing here says Reset, which is the panel's measurement reset.
struct SettingRow: View {
    let declaration: SettingDeclaration
    let value: SettingValue
    let note: SettingNote?
    let edit: SettingEdit?
    /// Where an unset colour comes from, shown in its well and said under it.
    var inherited: InheritedColour?
    /// How each choice is shown, where not by its value.
    var choiceLabel: ((JSONValue) -> ChoiceLabel)?
    /// Why the setting has no effect as the card's other settings stand, which greys it out
    /// (`scene-settings`, design D9).
    var unused: String?

    var body: some View {
        VStack(alignment: .leading, spacing: SceneMetrics.settingSpacing) {
            LabeledContent(declaration.label) {
                HStack(spacing: SceneMetrics.settingSpacing) {
                    SettingControl(
                        declaration: declaration, value: value,
                        edit: unused == nil ? edit : nil, inheritedHex: inherited?.colour.hex,
                        choiceLabel: choiceLabel)
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

    /// What needs saying of a value the scene does not set alone: that the cards differ, or the
    /// element and swatch an unset colour is drawn in.
    private var state: String? {
        switch value {
        case .mixed: "Mixed"
        case .same(nil, isSet: false): inherited?.caption
        case .same: nil
        }
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

/// The control a setting's shape takes: a switch, a picker of its choices, a colour well, a number
/// field, or its value as text where the app cannot edit it.
struct SettingControl: View {
    let declaration: SettingDeclaration
    let value: SettingValue
    let edit: SettingEdit?
    /// The colour an unset colour is drawn in, shown in its well.
    var inheritedHex: String?
    var choiceLabel: ((JSONValue) -> ChoiceLabel)?

    var body: some View {
        Group {
            switch declaration.shape {
            case .boolean:
                Toggle(declaration.label, isOn: flag).labelsHidden()
            case .choice(let choices):
                Picker(declaration.label, selection: choice) {
                    ForEach(choices, id: \.self) { item($0).tag(Optional($0)) }
                }
                .labelsHidden()
            case .colour:
                ColourWell(hex: shown?.stringValue ?? inheritedHex, set: edit?.set)
            case .number, .integer:
                NumberField(declaration: declaration, value: shown, set: edit?.set)
            case .other, .colours:
                Text(shown?.text ?? "None").foregroundStyle(.secondary)
            }
        }
        .disabled(edit == nil)
    }

    /// The value every card takes, or nil where they differ.
    private var shown: JSONValue? {
        if case .same(let value, _) = value { return value }
        return nil
    }

    private var flag: Binding<Bool> {
        Binding(get: { shown?.boolValue ?? false }, set: { edit?.set(.bool($0)) })
    }

    private var choice: Binding<JSONValue?> {
        Binding(get: { shown }, set: { picked in picked.map { edit?.set($0) } })
    }

    /// A choice as its menu item: its words, with a chip of its swatch where it names one.
    @ViewBuilder private func item(_ choice: JSONValue) -> some View {
        if let label = choiceLabel?(choice) {
            if let colour = label.colour {
                Label {
                    Text(label.text)
                } icon: {
                    Image(nsImage: SwatchChip.image(colour))
                }
            } else {
                Text(label.text)
            }
        } else {
            Text(choice.text)
        }
    }
}

/// A small square of a colour for a menu item, drawn as an image since a menu does not draw
/// views or tint symbols.
enum SwatchChip {
    static func image(_ colour: HexColour) -> NSImage {
        let side = SceneMetrics.swatchChipSide
        return NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            let radius = SceneMetrics.swatchChipRadius
            let chip = NSBezierPath(
                roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: radius, yRadius: radius)
            NSColor(srgbRed: colour.red, green: colour.green, blue: colour.blue, alpha: 1)
                .setFill()
            chip.fill()
            NSColor.separatorColor.setStroke()
            chip.stroke()
            return true
        }
    }
}

/// A number typed or stepped: kept to its range and step as the core writes it, committed on
/// Return or leaving the field, each stepper click one step (design D4).
struct NumberField: View {
    let declaration: SettingDeclaration
    /// The value every card takes, or nil where they differ.
    let value: JSONValue?
    let set: ((JSONValue) -> Void)?

    var body: some View {
        HStack(spacing: SceneMetrics.settingSpacing) {
            TextField(declaration.label, value: number, format: .number, prompt: Text("Mixed"))
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .frame(width: SceneMetrics.numberFieldWidth)
            if !declaration.unit.isEmpty {
                Text(declaration.unit).foregroundStyle(.secondary)
            }
            if declaration.stepped(value, by: 1) != nil {
                Stepper(declaration.label, onIncrement: { step(1) }, onDecrement: { step(-1) })
                    .labelsHidden()
            }
        }
    }

    private var number: Binding<Double?> {
        Binding(
            get: { value?.numberValue },
            set: { typed in typed.flatMap(declaration.written).map { set?($0) } })
    }

    private func step(_ steps: Int) {
        declaration.stepped(value, by: steps).map { set?($0) }
    }
}

/// A colour through the system colour panel, with no opacity, written as `#RRGGBB` in sRGB. The
/// panel sends a change for every movement, so a run of changes is held and written once the
/// colour has rested, or the well goes, as one step and one redraw (design D8).
struct ColourWell: View {
    /// The colour shown: the stored one, or the one an unset colour is drawn in; nil for colours
    /// that differ. A colour chosen equal to it is not written (`scene-settings`, design D8).
    let hex: String?
    let set: ((JSONValue) -> Void)?
    @State private var pending: String?
    @State private var settling: Task<Void, Never>?

    var body: some View {
        ColorPicker("Colour", selection: colour, supportsOpacity: false)
            .labelsHidden()
            .onDisappear(perform: commit)
    }

    /// The colour shown, as `HexColour` writes it.
    private var stored: String? {
        hex.flatMap { HexColour($0) }?.hex
    }

    private var colour: Binding<Color> {
        Binding(get: { Self.swatch(pending ?? stored) }, set: choose)
    }

    private func choose(_ picked: Color) {
        guard let srgb = NSColor(picked).usingColorSpace(.sRGB) else { return }
        let chosen = HexColour(
            red: Double(srgb.redComponent), green: Double(srgb.greenComponent),
            blue: Double(srgb.blueComponent)
        ).hex
        guard chosen != (pending ?? stored) else { return }
        pending = chosen
        settling?.cancel()
        settling = Task {
            do {
                try await Task.sleep(for: .seconds(SceneMetrics.colourSettleSeconds))
            } catch {
                return
            }
            commit()
        }
    }

    /// Writes the held colour, if it differs from the stored one.
    private func commit() {
        settling?.cancel()
        settling = nil
        guard let chosen = pending else { return }
        pending = nil
        if chosen != stored { set?(.string(chosen)) }
    }

    /// `hex` as an sRGB colour, or clear for none.
    private static func swatch(_ hex: String?) -> Color {
        guard let colour = hex.flatMap({ HexColour($0) }) else { return .clear }
        return Color(.sRGB, red: colour.red, green: colour.green, blue: colour.blue)
    }
}
