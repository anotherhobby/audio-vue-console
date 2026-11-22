import ConsoleCore
import SwiftUI

/// Parked cards as plain boxes, where the scene is drawn as boxes (`card-parking`).
struct ParkedBoxes: View {
    let cards: [LayoutCard]
    let geometry: GridGeometry

    var body: some View {
        ForEach(cards) { card in
            PlainBox(kind: card.kind).placed(at: geometry.rect(of: card.cells))
        }
        .allowsHitTesting(false)
    }
}

/// The selection's outlines, red when a gesture is refused, and the marquee's rectangle.
struct CanvasOutlines: View {
    let rects: [CGRect]
    let isRefused: Bool
    let marquee: CGRect?

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(rects.enumerated()), id: \.offset) { _, rect in
                RoundedRectangle(cornerRadius: CanvasMetrics.plateCornerRadius)
                    .strokeBorder(
                        isRefused ? Color.red : .accentColor,
                        lineWidth: CanvasMetrics.selectionLineWidth
                    )
                    .placed(at: rect)
            }
            if let marquee {
                Rectangle()
                    .fill(Color.accentColor.opacity(CanvasMetrics.marqueeFillOpacity))
                    .overlay { Rectangle().strokeBorder(Color.accentColor) }
                    .placed(at: marquee)
            }
        }
        .allowsHitTesting(false)
    }
}
