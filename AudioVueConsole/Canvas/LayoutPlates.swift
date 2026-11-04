import ConsoleCore
import SwiftUI

/// A layout's cards as coloured plates on its grid, filling the space it is given. A group is
/// drawn as one plate, as the panel draws it, with its members outlined faintly inside it.
struct LayoutPlates: View {
    let layout: SceneLayout
    var isThumbnail = false

    var body: some View {
        GeometryReader { proxy in
            let geometry = GridGeometry(grid: layout.grid, size: proxy.size)
            ZStack(alignment: .topLeading) {
                ForEach(layout.groups.keys.sorted(), id: \.self) { name in
                    groupPlate(name).placed(at: geometry.rect(of: groupCells(name)))
                }
                ForEach(layout.cards) { card in
                    plate(card).placed(at: geometry.rect(of: card.cells))
                }
            }
        }
    }

    private var cornerRadius: CGFloat {
        isThumbnail ? CanvasMetrics.thumbnailCornerRadius : CanvasMetrics.plateCornerRadius
    }

    private var inset: CGFloat {
        isThumbnail ? CanvasMetrics.thumbnailInset : CanvasMetrics.plateInset
    }

    private func groupCells(_ name: String) -> CellRect {
        CellRect(enclosing: layout.groups[name, default: []].map(\.cells))
            ?? CellRect(col: 0, row: 0, cols: 0, rows: 0)
    }

    private func groupPlate(_ name: String) -> some View {
        let kind = layout.groups[name]?.first?.kind ?? name
        return RoundedRectangle(cornerRadius: cornerRadius)
            .fill(CanvasMetrics.color(for: kind).opacity(CanvasMetrics.plateFillOpacity))
            .padding(inset)
    }

    private func plate(_ card: LayoutCard) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        let fill = CanvasMetrics.color(for: card.kind).opacity(CanvasMetrics.plateFillOpacity)
        return
            shape
            .fill(card.group == nil ? fill : .clear)
            .overlay {
                if card.group != nil {
                    shape.strokeBorder(.white.opacity(CanvasMetrics.memberStrokeOpacity))
                }
            }
            .overlay(alignment: .topLeading) {
                if !isThumbnail {
                    Text(card.kind.replacingOccurrences(of: "_", with: " "))
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(CanvasMetrics.labelPadding)
                }
            }
            .padding(inset)
    }
}

extension View {
    /// Sizes and places a view over `rect`, from the top-left of its container.
    func placed(at rect: CGRect) -> some View {
        frame(width: rect.width, height: rect.height).offset(x: rect.minX, y: rect.minY)
    }
}

#Preview("Workbench") {
    let store = SceneStore()
    if let scene = SketchData.shared.scenes.first(where: { $0.spec == "workbench" }),
        let layout = store.layout(for: scene)
    {
        LayoutPlates(layout: layout)
            .aspectRatio(scene.aspect, contentMode: .fit)
            .background(CanvasMetrics.backdrop)
            .padding()
    }
}
