import ConsoleCore
import SwiftUI

/// The card library beside the canvas: every card the host's schema marks placeable, dragged onto
/// the canvas to add it at its declared minimum (`scene-canvas`).
struct CardLibrary: View {
    let cards: [SchemaFacts.Card]
    /// A card's size on this scene's grid, by name.
    let sizeOf: (String) -> CellSize?
    @State private var search = ""

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SceneMetrics.stripSpacing) {
                ForEach(shown) { CardTile(card: $0, size: sizeOf($0.name)) }
            }
            .padding(SceneMetrics.stripPadding)
        }
        .safeAreaInset(edge: .top) {
            TextField("Search cards", text: $search)
                .textFieldStyle(.roundedBorder)
                .padding(SceneMetrics.stripPadding)
        }
        .background(.background.secondary)
    }

    private var shown: [SchemaFacts.Card] {
        guard !search.isEmpty else { return cards }
        return cards.filter { CardTile.title($0.name).localizedCaseInsensitiveContains(search) }
    }
}

/// One card in the library, its plate at its minimum's shape.
struct CardTile: View {
    let card: SchemaFacts.Card
    let size: CellSize?
    @Environment(SceneStore.self) private var store

    var body: some View {
        VStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: CanvasMetrics.plateCornerRadius)
                .fill(CanvasMetrics.color(for: card.name).opacity(CanvasMetrics.plateFillOpacity))
                .aspectRatio(aspect, contentMode: .fit)
                .padding(SceneMetrics.tilePadding)
                .frame(maxWidth: .infinity)
                .frame(height: SceneMetrics.cardPreviewHeight)
                .background(
                    CanvasMetrics.backdrop,
                    in: RoundedRectangle(cornerRadius: SceneMetrics.tileCornerRadius))
            HStack {
                Text(Self.title(card.name))
                Spacer()
                if let size {
                    Text(verbatim: "\(size.cols) × \(size.rows)").foregroundStyle(.secondary)
                }
            }
            .font(.callout)
        }
        .contentShape(Rectangle())
        // The canvas previews the card's size while it hovers, before the drop delivers the text.
        .onDrag {
            store.draggedKind = card.name
            return NSItemProvider(object: card.name as NSString)
        }
    }

    private var aspect: Double {
        let minimum = size ?? card.minimum
        return Double(minimum.cols) / Double(minimum.rows)
    }

    static func title(_ name: String) -> String {
        name.replacingOccurrences(of: "_", with: " ")
    }
}

#Preview("Card library") {
    let cards = [
        SchemaFacts.Card(name: "waveform", minimum: CellSize(cols: 12, rows: 7), placeable: true),
        SchemaFacts.Card(name: "rta_bars", minimum: CellSize(cols: 17, rows: 10), placeable: true),
    ]
    CardLibrary(cards: cards) { name in cards.first { $0.name == name }?.minimum }
        .frame(width: SceneMetrics.libraryIdealWidth, height: PanelMetrics.windowDefaultHeight)
        .environment(SceneStore())
}
