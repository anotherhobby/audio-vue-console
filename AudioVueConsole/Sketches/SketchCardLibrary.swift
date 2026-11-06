import SwiftUI

/// The card library beside the canvas: every card with a large preview, dragged onto the canvas
/// to add it. The previews stand in for the tiles the host will render from the real card code.
struct SketchCardLibrary: View {
    let kinds: [SketchCardKind]
    @State private var search = ""

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SketchMetrics.stripSpacing) {
                ForEach(shown) { SketchCardTile(kind: $0) }
            }
            .padding(SketchMetrics.stripPadding)
        }
        .safeAreaInset(edge: .top) {
            TextField("Search cards", text: $search)
                .textFieldStyle(.roundedBorder)
                .padding(SketchMetrics.stripPadding)
        }
        .background(.background.secondary)
    }

    private var shown: [SketchCardKind] {
        search.isEmpty ? kinds : kinds.filter { $0.title.localizedCaseInsensitiveContains(search) }
    }
}

struct SketchCardTile: View {
    let kind: SketchCardKind
    @Environment(SceneStore.self) private var store

    var body: some View {
        VStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: CanvasMetrics.plateCornerRadius)
                .fill(CanvasMetrics.color(for: kind.card).opacity(CanvasMetrics.plateFillOpacity))
                .aspectRatio(kind.aspect, contentMode: .fit)
                .padding(SketchMetrics.tilePadding)
                .frame(maxWidth: .infinity)
                .frame(height: SketchMetrics.cardPreviewHeight)
                .background(
                    CanvasMetrics.backdrop,
                    in: RoundedRectangle(cornerRadius: SketchMetrics.tileCornerRadius))
            HStack {
                Text(kind.title)
                Spacer()
                Text(verbatim: "\(kind.cols) × \(kind.rows)").foregroundStyle(.secondary)
            }
            .font(.callout)
        }
        .contentShape(Rectangle())
        // The canvas previews the card's size while it hovers, before the drop delivers the text.
        .onDrag {
            store.draggedKind = kind.card
            return NSItemProvider(object: kind.card as NSString)
        }
    }
}

#Preview("Card library") {
    SketchCardLibrary(kinds: SketchCardKind.roster(from: SketchData.shared.scenes))
        .frame(width: SketchMetrics.libraryIdealWidth, height: PanelMetrics.windowDefaultHeight)
        .environment(SceneStore())
}
