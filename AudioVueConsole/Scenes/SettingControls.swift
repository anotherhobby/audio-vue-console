import AppKit
import ConsoleCore
import SwiftUI

/// The scene's roles a card's colour may take in place of a colour of its own, each with a chip
/// of its colour in this scene, the one taken ticked.
struct RoleMenu: View {
    let roles: [RoleChoice]
    /// The role the colour takes now, if it takes one.
    let taken: String?
    let set: ((JSONValue) -> Void)?

    var body: some View {
        Menu {
            ForEach(roles) { choice in
                Toggle(isOn: isTaken(choice)) {
                    Label {
                        Text(choice.role.label)
                    } icon: {
                        choice.colour.map { Image(nsImage: SwatchChip.image($0)) }
                    }
                }
            }
        } label: {
            Label("Use a Scene Colour", systemImage: "paintpalette")
        }
        .labelStyle(.iconOnly)
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Use one of the scene's colours")
    }

    /// Whether the colour takes `choice`; turning it on takes it.
    private func isTaken(_ choice: RoleChoice) -> Binding<Bool> {
        Binding(get: { choice.id == taken }, set: { _ in set?(.string(choice.id)) })
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
    /// Whether the cards differ; an empty field otherwise holds a setting with no value, such as
    /// a time left unset.
    var isMixed = true

    var body: some View {
        HStack(spacing: SceneMetrics.settingSpacing) {
            TextField(
                declaration.label, value: number, format: .number,
                prompt: Text(isMixed ? "Mixed" : "None")
            )
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

/// An amount from none to all, set by a slider and shown as a percentage. A drag is written once,
/// as it ends, so it is one step and one redraw.
struct AmountSlider: View {
    let declaration: SettingDeclaration
    /// The value every card takes, or nil where they differ.
    let value: JSONValue?
    let set: ((JSONValue) -> Void)?
    @State private var dragged: Double?
    @State private var dragging = false

    var body: some View {
        HStack(spacing: SceneMetrics.settingSpacing) {
            Slider(value: amount, in: 0...1) { editing in
                dragging = editing
                if !editing { commit() }
            }
            .frame(width: SceneMetrics.amountSliderWidth)
            Text(dragged ?? value?.numberValue ?? 0, format: .percent.precision(.fractionLength(0)))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: SceneMetrics.amountTextWidth, alignment: .trailing)
        }
    }

    /// The amount shown; a change outside a drag, as from the keyboard, is written at once.
    private var amount: Binding<Double> {
        Binding(
            get: { dragged ?? value?.numberValue ?? 0 },
            set: { chosen in
                dragged = chosen
                if !dragging { commit() }
            })
    }

    private func commit() {
        guard let chosen = dragged else { return }
        dragged = nil
        guard let written = declaration.written(chosen), written != value else { return }
        set?(written)
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
