import AppKit
import ConsoleCore
import SwiftUI
import UniformTypeIdentifiers

/// The backdrop's one source, chosen by a segmented control, with its colour, its gradient's stops
/// and angle, or its image, and the blur any source takes. Each change is one step that writes the
/// whole block (`scene-settings`, "The backdrop is one source"; design D3).
struct BackdropEditor: View {
    let settings: SettingGroup
    let editor: SceneEditor
    let colours: SceneColours
    let scenes: PanelScenes
    @State private var picking = false

    var body: some View {
        Picker("Source", selection: kind) {
            ForEach(BackdropSource.Kind.allCases) { Text(Self.name($0)).tag($0) }
        }
        .pickerStyle(.segmented)
        .disabled(!editable)
        source
        ForEach(settings.settings.filter(shownBelow)) {
            BlockSettingRow(block: Self.block, declaration: $0, editor: editor)
        }
        .sheet(isPresented: $picking) {
            ImagePicker(scenes: scenes, chosen: chosenImage) { write(.image($0)) }
        }
    }

    private static let block = "backdrop"

    @ViewBuilder private var source: some View {
        switch current {
        case .unset:
            Text("The default backdrop shows.").foregroundStyle(.secondary)
        case .colour(let hex):
            LabeledContent("Colour") {
                ColourWell(hex: hex, set: colourSetter(else: hex))
            }
        case .gradient(let stops):
            GradientStops(
                stops: stops, source: current, write: writer, useDefault: defaultGradient)
        case .image(let id):
            LabeledContent("Image") {
                HStack {
                    Text(id).lineLimit(1).truncationMode(.middle).foregroundStyle(.secondary)
                    Button("Choose…") { picking = true }.disabled(!editable)
                }
            }
        }
    }

    /// The block's settings shown as rows beneath the source: the angle for a gradient, and the
    /// blur and any setting the app does not know for every source but Default, which has no
    /// block to hold them.
    private func shownBelow(_ declaration: SettingDeclaration) -> Bool {
        if current == .unset { return false }
        if declaration.key == Self.angle { return current.kind == .gradient }
        return !BackdropSource.sourceKeys.contains(declaration.key)
    }

    private static let angle = "angle"

    private var block: JSONValue? { editor.content.blocks[Self.block] }
    private var current: BackdropSource { BackdropSource(block: block) }
    private var editable: Bool { editor.readOnly == nil }

    private var chosenImage: String? {
        if case .image(let id) = current { return id }
        return nil
    }

    /// The source's kind, bringing back what it last held; choosing Image with none chosen yet
    /// opens the picker and changes nothing until one is chosen.
    private var kind: Binding<BackdropSource.Kind> {
        Binding(
            get: { current.kind },
            set: { kind in
                if !editor.switchBackdrop(to: kind, background: background) { picking = true }
            })
    }

    /// The card colour in this scene, which a gradient made from a colour ends in.
    private var background: String {
        colours.colour(of: Self.cardRole, in: editor.content.blocks)?.hex ?? Self.black
    }

    private static let cardRole = "card"
    private static let black = "#000000"

    /// Writes a chosen colour as the source, or nil where the scene is read-only.
    private func colourSetter(else held: String) -> ((JSONValue) -> Void)? {
        guard editable else { return nil }
        return { write(.colour($0.stringValue ?? held)) }
    }

    /// Sets the stops and angle to the default backdrop's, or nil where the scene is read-only,
    /// the default backdrop is no gradient, or the scene already holds it.
    private var defaultGradient: (() -> Void)? {
        let standard = scenes.defaultBackdrop
        guard editable, BackdropSource.gradient(of: standard, over: block) != nil else {
            return nil
        }
        return { editor.useDefaultGradient(standard) }
    }

    /// Writes a changed source, or nil where the scene is read-only.
    private var writer: ((BackdropSource) -> Void)? {
        guard editable else { return nil }
        return { write($0) }
    }

    private func write(_ source: BackdropSource) {
        editor.setBackdrop(source)
    }

    private static func name(_ kind: BackdropSource.Kind) -> String {
        switch kind {
        case .unset: "Default"
        case .colour: "Colour"
        case .gradient: "Gradient"
        case .image: "Image"
        }
    }
}

/// A gradient's stops in order, each a colour through the system colour panel, moved up or down,
/// removed while more than two remain, and one added after the last. A stack, not a `List`, which
/// crashed inside the editor (`pitfalls.md`).
struct GradientStops: View {
    let stops: [String]
    let source: BackdropSource
    /// Writes the changed gradient; nil where the scene is read-only.
    let write: ((BackdropSource) -> Void)?
    /// Sets the default backdrop's stops and angle; nil where there is nothing to change.
    let useDefault: (() -> Void)?

    var body: some View {
        ForEach(Array(stops.enumerated()), id: \.offset) { index, stop in
            LabeledContent("Stop \(index + 1)") {
                HStack {
                    ColourWell(hex: stop, set: setter(index))
                    Button("Move Up", systemImage: "chevron.up") {
                        apply(source.movingStop(at: index, by: -1))
                    }
                    .disabled(index == 0)
                    Button("Move Down", systemImage: "chevron.down") {
                        apply(source.movingStop(at: index, by: 1))
                    }
                    .disabled(index == stops.count - 1)
                    Button("Remove", systemImage: "minus.circle") {
                        apply(source.removingStop(at: index))
                    }
                    .disabled(stops.count <= BackdropSource.fewestStops)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
            }
        }
        .disabled(write == nil)
        HStack {
            Button("Add Stop") { apply(source.addingStop()) }
                .disabled(write == nil)
            Button("Use Default Gradient") { useDefault?() }
                .disabled(useDefault == nil)
                .help("Set the stops and angle to the default backdrop's")
        }
    }

    /// Sets the stop at `index` to a chosen colour, or nil where the scene is read-only.
    private func setter(_ index: Int) -> ((JSONValue) -> Void)? {
        guard write != nil else { return nil }
        return { colour in colour.stringValue.map { apply(source.settingStop(at: index, to: $0)) } }
    }

    private func apply(_ next: BackdropSource?) {
        if let next { write?(next) }
    }
}
