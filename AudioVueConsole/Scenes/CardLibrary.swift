import ConsoleCore
import SwiftUI

/// The card library beside the canvas: every card the host's schema marks placeable, under the
/// panel's categories in its order, dragged onto the canvas to add it at its declared minimum
/// (`scene-canvas`), each drawn by the helper where it can be (`scene-rendering`, "A library tile
/// is the card's plate as the helper draws it").
struct CardLibrary: View {
    let shelves: [SchemaFacts.Shelf]
    /// The tiles drawn so far, by card name.
    let tiles: [String: LibraryTiles.Tile]
    /// The scene's backdrop as the helper drew it, which each tile sits on.
    let backdrop: CGImage?
    /// A card's size on this scene's grid, by name.
    let sizeOf: (String) -> CellSize?
    /// The library card selected, and selecting one by name (`library-setup`).
    var selection = LibrarySelection()
    @State private var search: String

    init(
        shelves: [SchemaFacts.Shelf], tiles: [String: LibraryTiles.Tile],
        backdrop: CGImage? = nil, search: String = "", selection: LibrarySelection = .init(),
        sizeOf: @escaping (String) -> CellSize?
    ) {
        self.shelves = shelves
        self.tiles = tiles
        self.backdrop = backdrop
        self.selection = selection
        self.sizeOf = sizeOf
        _search = State(initialValue: search)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SceneMetrics.stripSpacing) {
                ForEach(shown) { shelf in
                    Section {
                        // Each tile carries its own id; a card is on one shelf, so ids stay unique.
                        ForEach(shelf.cards) { card in
                            CardTile(
                                card: card, size: sizeOf(card.name), tile: tiles[card.name],
                                backdrop: backdrop, selection: selection)
                        }
                    } header: {
                        VStack(alignment: .leading, spacing: SceneMetrics.stripSpacing) {
                            if shelf.id != shown.first?.id {
                                Divider()
                            }
                            Text(shelf.category.label).font(.headline)
                        }
                    }
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

    /// The shelves with the cards the search matches, leaving out a shelf with none.
    private var shown: [SchemaFacts.Shelf] {
        guard !search.isEmpty else { return shelves }
        return shelves.compactMap { shelf in
            let cards = shelf.cards.filter {
                CardTile.title($0.name).localizedCaseInsensitiveContains(search)
            }
            return cards.isEmpty ? nil : SchemaFacts.Shelf(category: shelf.category, cards: cards)
        }
    }
}

/// Which library card is selected, which are set up, and how one is chosen (`library-setup`).
struct LibrarySelection {
    var selected: String?
    var setUp: Set<String> = []
    var choose: (String) -> Void = { _ in }
}

/// One card in the library: its plate as the helper drew it, or a box at its minimum's shape. A
/// click selects it, and a drag adds it to the canvas.
struct CardTile: View {
    let card: SchemaFacts.Card
    let size: CellSize?
    let tile: LibraryTiles.Tile?
    /// The scene's backdrop, or nil until the helper has drawn it.
    var backdrop: CGImage?
    var selection = LibrarySelection()
    @Environment(SceneStore.self) private var store

    var body: some View {
        VStack(alignment: .leading) {
            preview
                .padding(SceneMetrics.tilePadding)
                .frame(maxWidth: .infinity)
                .frame(height: SceneMetrics.cardPreviewHeight)
                .background { SceneBackdrop(image: backdrop) }
                .clipShape(RoundedRectangle(cornerRadius: SceneMetrics.tileCornerRadius))
                .overlay {
                    if selection.selected == card.name {
                        RoundedRectangle(cornerRadius: SceneMetrics.tileCornerRadius)
                            .strokeBorder(.tint, lineWidth: CanvasMetrics.selectionLineWidth)
                    }
                }
            caption
        }
        .contentShape(Rectangle())
        .onTapGesture { selection.choose(card.name) }
        // The canvas previews the card's size while it hovers, before the drop delivers the text.
        .onDrag {
            store.draggedKind = card.name
            return NSItemProvider(object: card.name as NSString)
        }
        // A fresh tile after each drop on the canvas, so a refused drop leaves no drag behind.
        .id("\(card.name) \(store.drops)")
    }

    /// The card's name, marked where it is set up, the size it is drawn at, and where its reading
    /// does not fit.
    @ViewBuilder private var caption: some View {
        HStack {
            Text(Self.title(card.name))
            if selection.setUp.contains(card.name) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(.secondary)
                    .help("Set up for the cards dropped from the library")
            }
            Spacer()
            if let drawn = tile?.size {
                Text(verbatim: "\(drawn.cols) × \(drawn.rows)").foregroundStyle(.secondary)
            }
        }
        .font(.callout)
        if tile?.unfit.isEmpty == false {
            Text("Too small to show its reading").font(.callout).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var preview: some View {
        if let tile {
            // Over the scene's backdrop the plate is shown alone, its corners clear; stacked on
            // its own square patch of the backdrop it showed that patch's corners.
            Image(decorative: backdrop == nil ? tile.image : tile.layer.image, scale: 1)
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
        SceneSettingsTab.title(ofCard: name)
    }
}

#Preview("Card library") {
    let cards = [
        SchemaFacts.Card(name: "meter", minimum: CellSize(cols: 8, rows: 6), placeable: true),
        SchemaFacts.Card(name: "readout", minimum: CellSize(cols: 8, rows: 4), placeable: true),
        SchemaFacts.Card(name: "vu_meter", minimum: CellSize(cols: 12, rows: 10), placeable: true),
        SchemaFacts.Card(name: "peak_rms", minimum: CellSize(cols: 15, rows: 10), placeable: true),
    ]
    CardLibrary(shelves: LibraryPreview.shelves(cards), tiles: [:]) { name in
        cards.first { $0.name == name }?.minimum
    }
    .frame(width: SceneMetrics.libraryIdealWidth, height: PanelMetrics.windowDefaultHeight)
    .environment(SceneStore())
}

#Preview("Card library, searched") {
    let cards = [
        SchemaFacts.Card(name: "meter", minimum: CellSize(cols: 8, rows: 6), placeable: true),
        SchemaFacts.Card(name: "readout", minimum: CellSize(cols: 8, rows: 4), placeable: true),
        SchemaFacts.Card(name: "vu_meter", minimum: CellSize(cols: 12, rows: 10), placeable: true),
        SchemaFacts.Card(name: "peak_rms", minimum: CellSize(cols: 15, rows: 10), placeable: true),
    ]
    CardLibrary(shelves: LibraryPreview.shelves(cards), tiles: [:], search: "meter") { name in
        cards.first { $0.name == name }?.minimum
    }
    .frame(width: SceneMetrics.libraryIdealWidth, height: PanelMetrics.windowDefaultHeight)
    .environment(SceneStore())
}

/// Readouts and Level, as the panel's schema gives them.
private enum LibraryPreview {
    static func shelves(_ cards: [SchemaFacts.Card]) -> [SchemaFacts.Shelf] {
        [
            shelf("readouts", "Readouts", ["meter", "readout"], from: cards),
            shelf("level", "Level", ["vu_meter", "peak_rms"], from: cards),
        ]
    }

    private static func shelf(
        _ id: String, _ label: String, _ names: [String], from cards: [SchemaFacts.Card]
    ) -> SchemaFacts.Shelf {
        SchemaFacts.Shelf(
            category: SchemaFacts.Category(id: id, label: label, cards: names),
            cards: names.compactMap { name in cards.first { $0.name == name } })
    }
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
    ].compactMapValues { layer in
        layer.map {
            LibraryTiles.Tile(layer: $0, size: CellSize(cols: 12, rows: 7), over: backdrop)
        }
    }
    let shelf = SchemaFacts.Shelf(
        category: SchemaFacts.Category(
            id: "spectrum", label: "Spectrum", cards: cards.map(\.name)),
        cards: cards)
    CardLibrary(shelves: [shelf], tiles: tiles) { name in
        cards.first { $0.name == name }?.minimum
    }
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

/// What a scene's cards sit on wherever the app shows them: the scene's backdrop as the helper
/// drew it, filling the space, or the stand-in gradient until it has.
struct SceneBackdrop: View {
    let image: CGImage?

    var body: some View {
        if let image {
            Color.clear.overlay {
                Image(decorative: image, scale: 1).resizable().scaledToFill()
            }
            .clipped()
        } else {
            CanvasMetrics.backdrop
        }
    }
}
