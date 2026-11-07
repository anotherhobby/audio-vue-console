import ConsoleCore
import SwiftUI

/// The gallery of a panel's scenes: those of the panel's shape first, then the others, each
/// pictured by its thumbnail, or its boxes until the helper draws it (`scene-gallery`).
struct SceneGallery: View {
    let scenes: [SceneDocument]
    let facts: SchemaFacts
    let panel: DisplayShape
    /// Why no card is drawn, where the card code says so.
    var notice: String?
    let open: (String) -> Void
    @Environment(SceneStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SceneMetrics.gallerySpacing) {
                if let notice {
                    Label(notice, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                section("For this panel, \(panel)", rows.filter(\.fits), fits: true)
                section("Other shapes", rows.filter { !$0.fits }, fits: false)
            }
            .padding(SceneMetrics.canvasPadding)
        }
    }

    /// One scene as the gallery shows it.
    struct Item: Identifiable {
        let document: SceneDocument
        let laidOut: LaidOutScene?
        let fits: Bool
        var id: String { document.id }
    }

    private var rows: [Item] {
        scenes.map { document in
            let laidOut = ScenesPage.laidOut(document, facts: facts)
            let grid = laidOut?.layout.grid ?? facts.defaultGrid
            return Item(
                document: document, laidOut: laidOut,
                fits: panel.matches(DisplayShape(width: grid.cols, height: grid.rows)))
        }
    }

    private func section(_ title: String, _ items: [Item], fits: Bool) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.headline)
            LazyVGrid(columns: columns, alignment: .leading, spacing: SceneMetrics.gallerySpacing) {
                ForEach(items) { item in
                    SceneRow(item: item, panel: panel)
                        .contentShape(Rectangle())
                        .onTapGesture { open(item.id) }
                        .contextMenu { menu(item) }
                }
            }
        }
    }

    @ViewBuilder private func menu(_ item: Item) -> some View {
        Button("Edit") { open(item.id) }
        if item.fits, let laidOut = item.laidOut {
            Button("Duplicate") { open(store.drafts.duplicate(laidOut).id) }
        } else {
            Button("Duplicate for This Panel") {}.disabled(true)
        }
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: SceneMetrics.galleryTileWidth), alignment: .top)]
    }
}

/// A scene's thumbnail and name, with a lock for a built-in scene.
struct SceneRow: View {
    let item: SceneGallery.Item
    let panel: DisplayShape
    @Environment(SceneStore.self) private var store

    var body: some View {
        VStack(alignment: .leading) {
            thumbnail
                .aspectRatio(panel.aspect, contentMode: .fit)
                .background(CanvasMetrics.backdrop)
                .frame(maxHeight: SceneMetrics.galleryThumbnailHeight, alignment: .leading)
            HStack {
                Text(item.document.name ?? item.document.id)
                Spacer()
                if item.document.builtIn {
                    Image(systemName: "lock.fill").foregroundStyle(.secondary)
                }
            }
        }
        .opacity(item.fits ? 1.0 : SceneMetrics.mismatchOpacity)
    }

    @ViewBuilder private var thumbnail: some View {
        if let image = store.thumbnails.images[item.id] {
            Image(decorative: image, scale: 1).resizable()
        } else if let laidOut = item.laidOut {
            LayoutPlates(
                layout: store.drafts.layout(for: item.id) ?? laidOut.layout, isThumbnail: true
            )
            .aspectRatio(
                CGFloat(laidOut.layout.grid.cols) / CGFloat(laidOut.layout.grid.rows),
                contentMode: .fit)
        } else {
            Color.clear
        }
    }
}

#Preview("Gallery, an 8:3 panel") {
    if let preview = GalleryPreview.scenes, let facts = GalleryPreview.facts {
        SceneGallery(
            scenes: preview, facts: facts,
            panel: DisplayShape(width: 1920, height: 720)
        ) { _ in }
        .environment(SceneStore())
        .frame(width: PanelMetrics.windowDefaultWidth, height: PanelMetrics.windowDefaultHeight)
    }
}

/// Two scenes, one of each shape, read as the host gives scene documents.
private enum GalleryPreview {
    static let docs = [
        ("rta", "RTA", #"{"grid": {"cols": 96, "rows": 36}, "cards": [{"card": "rta_bars"}]}"#),
        ("default", "Default", #"{"cards": [{"card": "meter", "colspan": 32}]}"#),
    ]

    static let schema =
        #"{"$defs": {"block.grid": {"properties": "#
        + #"{"cols": {"default": 64}, "rows": {"default": 36}}}}}"#

    static var facts: SchemaFacts? {
        do {
            return SchemaFacts(
                schema: try JSONDecoder().decode(JSONValue.self, from: Data(schema.utf8)))
        } catch {
            return nil
        }
    }

    static var scenes: [SceneDocument]? {
        do {
            return try docs.map { id, name, doc in
                SceneDocument(
                    id: id, name: name, builtIn: true, fixed: false,
                    doc: try JSONDecoder().decode(JSONValue.self, from: Data(doc.utf8)))
            }
        } catch {
            return nil
        }
    }
}
