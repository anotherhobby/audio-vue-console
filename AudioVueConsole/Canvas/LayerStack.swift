import ConsoleCore
import SwiftUI

/// The helper's layers over the whole panel outline (`scene-rendering`, design D4): the backdrop,
/// then each plate at its rect, scaled by the outline's width over the display's. A plate drawn at
/// other cells than it is shown at is slid or stretched, edge by edge, until it is drawn again
/// there. A card whose code differs from the panel's is a plain box over its plate.
struct LayerStack: View {
    let rendering: SceneRendering
    let grid: CellSize
    /// Where each card is shown now: as a gesture would leave it, or as it is.
    let shown: SceneLayout

    var body: some View {
        GeometryReader { proxy in
            let region = Self.region(in: proxy.size, grid: grid)
            let cells = GridGeometry(grid: grid, size: region.size)
            let scale = proxy.size.width / CGFloat(rendering.context.display.width)
            ZStack(alignment: .topLeading) {
                if let backdrop = rendering.backdrop {
                    layerImage(backdrop.image).frame(
                        width: proxy.size.width, height: proxy.size.height)
                }
                ForEach(rendering.orderedPlates, id: \.layer.cardIDs) { placed in
                    layerImage(placed.layer.image)
                        .placed(at: rect(of: placed, scale: scale, cells: cells))
                }
                ForEach(shown.cards.filter { rendering.boxedCards.contains($0.id) }) { card in
                    PlainBox(kind: card.kind)
                        .placed(
                            at: cells.rect(of: card.cells).offsetBy(
                                dx: region.minX, dy: region.minY))
                }
            }
        }
        .allowsHitTesting(false)
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

    /// The largest centred rectangle of `size` at the grid's aspect, where the panel draws the
    /// scene's region (audio-vue `layout.Grid.region`).
    static func region(in size: CGSize, grid: CellSize) -> CGRect {
        let aspect = CGFloat(grid.cols) / CGFloat(grid.rows)
        let width = min(size.width, size.height * aspect)
        let height = width / aspect
        return CGRect(
            x: (size.width - width) / 2, y: (size.height - height) / 2, width: width,
            height: height)
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
