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
    let editor: SceneEditor

    var body: some View {
        ForEach(declared.settings) { declaration in
            SettingRow(
                declaration: declaration,
                value: SettingGroup.value(of: declaration.key, across: cards, declaredBy: groups),
                note: SettingGroup.note(of: declaration.key, across: cards, declaredBy: groups),
                edit: edit(declaration))
        }
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

/// One setting: its label and control, its help, the standard it is off, and whether it is the
/// default, mixed, or set with Use Default beside it (design D5). Nothing here says Reset, which
/// is the panel's measurement reset.
struct SettingRow: View {
    let declaration: SettingDeclaration
    let value: SettingValue
    let note: SettingNote?
    let edit: SettingEdit?

    var body: some View {
        VStack(alignment: .leading, spacing: SceneMetrics.settingSpacing) {
            LabeledContent(declaration.label) {
                SettingControl(declaration: declaration, value: value, edit: edit)
            }
            if !declaration.help.isEmpty {
                Text(declaration.help).font(.caption).foregroundStyle(.secondary)
            }
            if case .offStandard(let document)? = note {
                Label("Outside \(document)", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.orange)
            }
            footer
        }
    }

    @ViewBuilder private var footer: some View {
        HStack {
            if let state { Text(state).font(.caption).foregroundStyle(.secondary) }
            if value.isSet, let edit {
                Button("Use Default", action: edit.useDefault).controlSize(.small)
            }
        }
    }

    /// What the value is when the scene does not set it alone: mixed, the default, or the palette.
    private var state: String? {
        switch value {
        case .mixed: "Mixed"
        case .same(nil, isSet: false): declaration.shape == .colour ? "Uses the palette" : "Unset"
        case .same(_, isSet: false): "Default"
        case .same(_, isSet: true): nil
        }
    }
}

/// The control a setting's shape takes: a switch, a picker of its choices, a colour well, a number
/// field, or its value as text where the app cannot edit it.
struct SettingControl: View {
    let declaration: SettingDeclaration
    let value: SettingValue
    let edit: SettingEdit?

    var body: some View {
        Group {
            switch declaration.shape {
            case .boolean:
                Toggle(declaration.label, isOn: flag).labelsHidden()
            case .choice(let choices):
                Picker(declaration.label, selection: choice) {
                    ForEach(choices, id: \.self) { Text($0.text).tag(Optional($0)) }
                }
                .labelsHidden()
            case .colour:
                ColourWell(hex: shown?.stringValue, set: edit?.set)
            case .number, .integer:
                NumberField(declaration: declaration, value: shown, set: edit?.set)
            case .other:
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
    /// The stored colour, or nil for a colour left to the palette or one that differs.
    let hex: String?
    let set: ((JSONValue) -> Void)?
    @State private var pending: String?
    @State private var settling: Task<Void, Never>?

    var body: some View {
        ColorPicker("Colour", selection: colour, supportsOpacity: false)
            .labelsHidden()
            .onDisappear(perform: commit)
    }

    /// The stored colour, as `HexColour` writes it.
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
