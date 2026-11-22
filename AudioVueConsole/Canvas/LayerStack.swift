import ConsoleCore
import SwiftUI

/// The helper's layers over the display's outline (`scene-rendering`, design D4): the backdrop,
/// then each plate at its rect, scaled by the outline's width over the display's. On a scene
/// laid out wider than the panel's grid the display is the first `panelCols` columns. A plate drawn at
/// other cells than it is shown at is slid or stretched, edge by edge, until it is drawn again
/// there. A card whose code differs from the panel's is a plain box over its plate. A parked plate
/// is drawn the same way at its cells off the grid, outside the outline, or as a plain box while
/// it has no layer (`card-parking`).
struct LayerStack: View {
    let rendering: SceneRendering
    let grid: CellSize
    /// How many columns the panel's grid has.
    let panelCols: Int
    /// Where each card is shown now, on the grid or parked: as a gesture would leave it, or as it
    /// is.
    let shown: SceneContent

    var body: some View {
        GeometryReader { proxy in
            let cells = GridGeometry(grid: grid, size: proxy.size)
            let displayWidth = cells.cellWidth * CGFloat(panelCols)
            let scale = displayWidth / CGFloat(rendering.context.display.width)
            ZStack(alignment: .topLeading) {
                if let backdrop = rendering.backdrop {
                    layerImage(backdrop.image).frame(
                        width: displayWidth, height: proxy.size.height)
                }
                ForEach(plates, id: \.layer.cardIDs) { placed in
                    layerImage(placed.layer.image)
                        .placed(at: rect(of: placed, scale: scale, cells: cells))
                }
                ForEach(shown.parked.filter { !drawn.contains($0.id) }) { card in
                    PlainBox(kind: card.kind).placed(at: cells.rect(of: card.cells))
                }
                ForEach(shown.cards.filter { rendering.boxedCards.contains($0.id) }) { card in
                    PlainBox(kind: card.kind).placed(at: cells.rect(of: card.cells))
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// The plates on the grid, in the helper's order, then the parked ones.
    private var plates: [SceneRendering.PlacedLayer] {
        rendering.orderedPlates + Array(rendering.parked.layers.values)
    }

    /// Every card a layer is held for.
    private var drawn: Set<UUID> {
        Set(plates.flatMap(\.layer.cardIDs))
    }

    private func layerImage(_ image: CGImage) -> some View {
        Image(decorative: image, scale: 1).resizable().interpolation(.high)
    }

    /// Where `placed` goes in points: its rect, moved edge by edge by how far its plate's cells are
    /// from the cells it was drawn for.
    private func rect(of placed: SceneRendering.PlacedLayer, scale: CGFloat, cells: GridGeometry)
        -> CGRect
    {
        let drawn = placed.cells
        let now =
            CellRect(enclosing: placed.layer.cardIDs.compactMap { shown.card($0)?.cells })
            ?? drawn
        let base = CGRect(
            x: placed.layer.rect.minX * scale, y: placed.layer.rect.minY * scale,
            width: placed.layer.rect.width * scale, height: placed.layer.rect.height * scale)
        let left = CGFloat(now.col - drawn.col) * cells.cellWidth
        let right = CGFloat(now.maxCol - drawn.maxCol) * cells.cellWidth
        let top = CGFloat(now.row - drawn.row) * cells.cellHeight
        let bottom = CGFloat(now.maxRow - drawn.maxRow) * cells.cellHeight
        return CGRect(
            x: base.minX + left, y: base.minY + top, width: base.width + right - left,
            height: base.height + bottom - top)
    }
}

/// A card drawn as a plain box with its name, where the helper does not draw it.
struct PlainBox: View {
    let kind: String

    var body: some View {
        RoundedRectangle(cornerRadius: CanvasMetrics.plateCornerRadius)
            .fill(.gray.opacity(CanvasMetrics.plateFillOpacity))
            .overlay {
                Text(kind.replacingOccurrences(of: "_", with: " "))
                    .font(.caption)
                    .foregroundStyle(.white)
            }
            .padding(CanvasMetrics.plateInset)
    }
}
