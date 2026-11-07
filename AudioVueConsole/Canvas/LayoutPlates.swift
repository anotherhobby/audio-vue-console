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

#Preview("Plates and a group") {
    if let layout = PlatesPreview.layout {
        LayoutPlates(layout: layout)
            .aspectRatio(8.0 / 3.0, contentMode: .fit)
            .background(CanvasMetrics.backdrop)
            .padding()
    }
}

/// A wide layout with a group, for the preview, read as a scene's document is.
private enum PlatesPreview {
    static let doc = #"""
        {"grid": {"cols": 96, "rows": 36}, "cards": [
          {"card": "rta_bars", "col": 0, "row": 0, "colspan": 48, "rowspan": 36},
          {"card": "meter", "col": 48, "row": 0, "colspan": 24, "rowspan": 18, "group": "g"},
          {"card": "readout", "col": 72, "row": 0, "colspan": 24, "rowspan": 18, "group": "g"},
          {"card": "waveform", "col": 48, "row": 18, "colspan": 48, "rowspan": 18}]}
        """#

    static var layout: SceneLayout? {
        do {
            let document = SceneDocument(
                id: "preview", name: "Preview", builtIn: false, fixed: false,
                doc: try JSONDecoder().decode(JSONValue.self, from: Data(doc.utf8)))
            // The document declares its grid, so no default is used.
            return try LaidOutScene(document, defaultGrid: .oneCell).layout
        } catch {
            return nil
        }
    }
}
