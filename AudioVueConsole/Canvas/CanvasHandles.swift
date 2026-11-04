import ConsoleCore
import SwiftUI

/// The resize handles of the one card that can be resized: at its corners and edges, or only its
/// lower-right corner when the card is too small to hold eight. Each sits above the card's own
/// drag so it wins the click (`design.md`).
struct CanvasHandles: View {
    let card: LayoutCard
    /// Where the card is drawn, following a resize under way.
    let rect: CGRect
    let geometry: GridGeometry
    let editor: SceneEditor
    @Binding var gesture: CanvasGesture?

    private static let all: [CardEdges] = [
        [.left, .top], .top, [.right, .top], .right, [.right, .bottom], .bottom, [.left, .bottom],
        .left,
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(edges, id: \.rawValue) { handle($0) }
        }
    }

    private var edges: [CardEdges] {
        let crowded = min(rect.width, rect.height) < CanvasMetrics.crowdedCardSize
        return crowded ? [[.right, .bottom]] : Self.all
    }

    private func handle(_ edges: CardEdges) -> some View {
        Rectangle()
            .fill(.white)
            .overlay { Rectangle().strokeBorder(Color.accentColor) }
            .frame(width: CanvasMetrics.handleSize, height: CanvasMetrics.handleSize)
            .frame(width: CanvasMetrics.handleHitSize, height: CanvasMetrics.handleHitSize)
            .contentShape(Rectangle())
            .position(point(for: edges))
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        gesture = .resizing(
                            card.id, edges, geometry.offset(for: value.translation))
                    }
                    .onEnded { value in
                        let offset = geometry.offset(for: value.translation)
                        editor.resize(card.id, edges: edges, by: offset)
                        gesture = nil
                    })
    }

    private func point(for edges: CardEdges) -> CGPoint {
        let x = edges.contains(.left) ? rect.minX : edges.contains(.right) ? rect.maxX : rect.midX
        let y = edges.contains(.top) ? rect.minY : edges.contains(.bottom) ? rect.maxY : rect.midY
        return CGPoint(x: x, y: y)
    }
}
