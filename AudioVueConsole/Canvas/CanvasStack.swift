import ConsoleCore
import SwiftUI

/// The canvas pane's column: the scene's name, the panel, and the line below it, stacked and
/// centred as a `VStack` would, but offering the panel only `scale` of the room left to it, so the
/// panel can be drawn smaller, still centred, to keep every parked card in view (`card-parking`,
/// design D6). The panel is the subview marked `CanvasStack.Display`.
struct CanvasStack: Layout {
    let scale: CGFloat

    /// Marks the panel among the stack's subviews.
    struct Display: LayoutValueKey {
        static let defaultValue = false
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        let sizes = Self.sizes(of: subviews, in: bounds.size, scale: scale)
        let spacing = CanvasMetrics.stackSpacing
        let total = sizes.map(\.height).reduce(0, +) + spacing * CGFloat(max(sizes.count - 1, 0))
        var top = bounds.midY - total / 2
        for (subview, size) in zip(subviews, sizes) {
            subview.place(
                at: CGPoint(x: bounds.midX, y: top), anchor: .top,
                proposal: ProposedViewSize(size))
            top += size.height + spacing
        }
    }

    /// Each subview's size: the lines at their own height across the width, the panel fitted to
    /// `scale` of the room they leave.
    private static func sizes(of subviews: Subviews, in room: CGSize, scale: CGFloat) -> [CGSize] {
        let across = ProposedViewSize(width: room.width, height: nil)
        let lines = subviews.filter { !$0[Display.self] }.map { $0.sizeThatFits(across).height }
        let gaps = CanvasMetrics.stackSpacing * CGFloat(max(subviews.count - 1, 0))
        let left = max(room.height - lines.reduce(0, +) - gaps, 0)
        let panel = ProposedViewSize(width: room.width * scale, height: left * scale)
        return subviews.map { subview in
            subview[Display.self]
                ? subview.sizeThatFits(panel)
                : CGSize(width: room.width, height: subview.sizeThatFits(across).height)
        }
    }
}

/// The canvas pane's size and the display region's frame in it, as last laid out: where parked
/// cards may go and how far the panel shrinks to keep them in view (`card-parking`).
struct PaneFrame: Equatable {
    var size: CGSize = .zero
    var region: CGRect = .zero

    /// The region's grid of `grid` cells, placed in the pane.
    func geometry(_ grid: CellSize) -> GridGeometry {
        GridGeometry(grid: grid, size: region.size, origin: region.origin)
    }

    /// The whole cells within the pane, from the grid's top-left: where a parked card may go.
    func reach(_ grid: CellSize) -> CellRect {
        guard region.width > 0, region.height > 0 else {
            return CellRect(col: 0, row: 0, cols: grid.cols, rows: grid.rows)
        }
        return geometry(grid).reach(in: size)
    }

    /// The scale to draw the panel at, from `scale`, the one it is drawn at now, so the cells
    /// `parked` lie within the pane: 1 where they fit at the panel's usual size.
    func fitted(_ grid: CellSize, parked: [CellRect], from scale: CGFloat) -> CGFloat {
        guard region.width > 0, region.height > 0 else { return scale }
        let factor = geometry(grid).fittingScale(of: CellRect(enclosing: parked), in: size)
        return min(1, scale * factor)
    }
}
