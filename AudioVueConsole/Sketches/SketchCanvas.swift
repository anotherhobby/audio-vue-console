import SwiftUI

/// The canvas: the scene's grid fitted inside the panel's display, as the host fits it, with
/// the backdrop outside. Click a card to select it, and anywhere else to deselect. No dragging
/// yet; that is the canvas spike.
struct SketchCanvas: View {
    let panel: SketchPanel
    let scene: SketchScene?
    @Binding var cardID: String?
    @State private var isTargeted = false

    var body: some View {
        VStack {
            if let scene {
                display(scene)
                footer(scene)
            } else {
                ContentUnavailableView("No Scene Selected", systemImage: "rectangle.3.group")
            }
        }
        .padding(SketchMetrics.canvasPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // A click anywhere off a card, inside the panel or around it, goes back to the scene's
        // settings; a card's own tap wins over this one.
        .contentShape(Rectangle())
        .onTapGesture { cardID = nil }
    }

    private func display(_ scene: SketchScene) -> some View {
        ZStack {
            SketchMetrics.backdrop
            SketchPlates(scene: scene, cardID: $cardID, isThumbnail: false)
                .aspectRatio(scene.aspect, contentMode: .fit)
        }
        .aspectRatio(panel.aspect, contentMode: .fit)
        .padding(SketchMetrics.bezelWidth)
        .background(.black, in: RoundedRectangle(cornerRadius: SketchMetrics.bezelCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: SketchMetrics.bezelCornerRadius)
                .strokeBorder(
                    isTargeted ? Color.accentColor : .clear, lineWidth: SketchMetrics.bezelWidth)
        }
        // A card from the library lights the panel up; placing it is the canvas spike's work, so
        // the sketch refuses the drop and the card returns to the library.
        .dropDestination(for: String.self) { _, _ in
            false
        } isTargeted: {
            isTargeted = $0
        }
    }

    private func footer(_ scene: SketchScene) -> some View {
        HStack {
            Text(
                verbatim: "\(panel.name): \(panel.widthPx) × \(panel.heightPx), \(panel.shapeName)")
            Text(verbatim: "Scene grid: \(scene.cols) × \(scene.rows)")
            if !panel.fits(scene) {
                Label(
                    "This scene is \(scene.shapeName). Duplicate it for this panel to edit.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .foregroundStyle(.orange)
            }
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }
}

/// A scene's cards as coloured plates. A group is drawn as one plate, as the panel draws it.
struct SketchPlates: View {
    let scene: SketchScene
    @Binding var cardID: String?
    let isThumbnail: Bool

    var body: some View {
        GeometryReader { proxy in
            let cell = CGSize(
                width: proxy.size.width / CGFloat(scene.cols),
                height: proxy.size.height / CGFloat(scene.rows))
            ZStack(alignment: .topLeading) {
                ForEach(groups, id: \.self) { group in
                    plate(color: groupColor(group), filled: true, selected: false)
                        .placed(scene.groupBounds[group] ?? SketchCells(enclosing: []), in: cell)
                }
                ForEach(scene.cards) { card in
                    cardPlate(card).placed(card.cells, in: cell)
                }
            }
        }
    }

    private var groups: [String] { scene.groupBounds.keys.sorted() }

    private func groupColor(_ group: String) -> Color {
        let member = scene.cards.first { $0.group == group }
        return SketchMetrics.color(for: member?.card ?? group)
    }

    private func cardPlate(_ card: SketchCard) -> some View {
        plate(
            color: SketchMetrics.color(for: card.card), filled: card.group == nil,
            selected: card.id == cardID
        )
        .overlay(alignment: .topLeading) { label(card) }
        .contentShape(Rectangle())
        .onTapGesture { cardID = card.id }
    }

    private func plate(color: Color, filled: Bool, selected: Bool) -> some View {
        let shape = RoundedRectangle(
            cornerRadius: isThumbnail
                ? SketchMetrics.thumbnailCornerRadius : SketchMetrics.plateCornerRadius)
        // A group member is outlined faintly within its group's plate; a lone card is not.
        let outline = filled ? Color.clear : .white.opacity(SketchMetrics.groupStrokeOpacity)
        return
            shape
            .fill(filled ? color.opacity(SketchMetrics.plateFillOpacity) : .clear)
            .overlay {
                shape.strokeBorder(
                    selected ? Color.accentColor : outline,
                    lineWidth: SketchMetrics.selectionLineWidth)
            }
            .padding(isThumbnail ? SketchMetrics.thumbnailInset : SketchMetrics.plateInset)
    }

    @ViewBuilder private func label(_ card: SketchCard) -> some View {
        if !isThumbnail {
            Text(card.title)
                .font(.caption)
                .foregroundStyle(.white)
                .padding(SketchMetrics.labelPadding)
        }
    }
}

extension View {
    /// Sizes and places a view over a block of cells, from the top-left of the grid.
    fileprivate func placed(_ cells: SketchCells, in cell: CGSize) -> some View {
        frame(width: cell.width * CGFloat(cells.cols), height: cell.height * CGFloat(cells.rows))
            .offset(x: cell.width * CGFloat(cells.col), y: cell.height * CGFloat(cells.row))
    }
}

#Preview("Canvas, 16:9 scene on an 8:3 panel") {
    if let panel = SketchData.shared.panels.first,
        let scene = SketchData.shared.scenes.first(where: { $0.spec == "stereo" })
    {
        SketchCanvas(panel: panel, scene: scene, cardID: .constant(nil))
    }
}
