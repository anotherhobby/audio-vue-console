import ConsoleCore
import SwiftUI

/// The card library beside the canvas: every card the host's schema marks placeable, dragged onto
/// the canvas to add it at its declared minimum (`scene-canvas`), each drawn by the helper where
/// it can be (`scene-rendering`, "A library tile is the card's plate as the helper draws it").
struct CardLibrary: View {
    let cards: [SchemaFacts.Card]
    /// The tiles drawn so far, by card name.
    let tiles: [String: LibraryTiles.Tile]
    /// A card's size on this scene's grid, by name.
    let sizeOf: (String) -> CellSize?
    @State private var search = ""

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SceneMetrics.stripSpacing) {
                ForEach(shown) {
                    CardTile(card: $0, size: sizeOf($0.name), tile: tiles[$0.name])
                }
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

/// One card in the library: its plate as the helper drew it, or a box at its minimum's shape.
struct CardTile: View {
    let card: SchemaFacts.Card
    let size: CellSize?
    let tile: LibraryTiles.Tile?
    @Environment(SceneStore.self) private var store

    var body: some View {
        VStack(alignment: .leading) {
            preview
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
            if tile?.unfit.isEmpty == false {
                Text("Too small to show its reading").font(.callout).foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        // The canvas previews the card's size while it hovers, before the drop delivers the text.
        .onDrag {
            store.draggedKind = card.name
            return NSItemProvider(object: card.name as NSString)
        }
    }

    @ViewBuilder private var preview: some View {
        if let tile {
            Image(decorative: tile.image, scale: 1)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
        } else {
            RoundedRectangle(cornerRadius: CanvasMetrics.plateCornerRadius)
                .fill(CanvasMetrics.color(for: card.name).opacity(CanvasMetrics.plateFillOpacity))
                .aspectRatio(aspect, contentMode: .fit)
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
    CardLibrary(cards: cards, tiles: [:]) { name in cards.first { $0.name == name }?.minimum }
        .frame(width: SceneMetrics.libraryIdealWidth, height: PanelMetrics.windowDefaultHeight)
        .environment(SceneStore())
}

#Preview("Card library, drawn") {
    let cards = [
        SchemaFacts.Card(name: "waveform", minimum: CellSize(cols: 12, rows: 7), placeable: true),
        SchemaFacts.Card(name: "rta_bars", minimum: CellSize(cols: 17, rows: 10), placeable: true),
        SchemaFacts.Card(name: "logo", minimum: CellSize(cols: 6, rows: 4), placeable: true),
    ]
    // A translucent plate over a solid backdrop, as the helper would draw them; logo is undrawn.
    let navy = CGColor(srgbRed: 0.1, green: 0.15, blue: 0.3, alpha: 1)
    let glass = CGColor(srgbRed: 0.6, green: 0.6, blue: 0.6, alpha: 0.4)
    let plate = CGSize(width: 200, height: 120)
    let backdrop = PreviewLayer.solid(.backdrop, navy, size: CGSize(width: 400, height: 240))
    let tiles = [
        "waveform": PreviewLayer.solid(.plate, glass, size: plate),
        "rta_bars": PreviewLayer.solid(.plate, glass, size: plate, unfit: ["rta_bars"]),
    ].compactMapValues { layer in layer.map { LibraryTiles.Tile(layer: $0, over: backdrop) } }
    CardLibrary(cards: cards, tiles: tiles) { name in cards.first { $0.name == name }?.minimum }
        .frame(width: SceneMetrics.libraryIdealWidth, height: PanelMetrics.windowDefaultHeight)
        .environment(SceneStore())
}

/// Layers of one colour, for previews.
private enum PreviewLayer {
    private static let bitsPerComponent = 8

    /// A `size` layer at the display's top left, filled with `color`.
    static func solid(
        _ kind: RenderedLayer.Kind, _ color: CGColor, size: CGSize, unfit: [String] = []
    ) -> RenderedLayer? {
        let rect = CGRect(origin: .zero, size: size)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil, width: Int(size.width), height: Int(size.height),
                bitsPerComponent: bitsPerComponent, bytesPerRow: 0, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.setFillColor(color)
        context.fill(rect)
        guard let image = context.makeImage() else { return nil }
        return RenderedLayer(kind: kind, cardIDs: [], rect: rect, unfit: unfit, image: image)
    }
}
