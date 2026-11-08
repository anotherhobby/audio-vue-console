import ConsoleCore
import SwiftUI

/// The gallery of a panel's scenes: the user's of the panel's shape, then the built-ins, then
/// every scene of another shape, each pictured by its thumbnail, or its boxes until the helper
/// draws it (`scene-gallery`). Its menu renames and deletes any scene but a built-in
/// (`scene-saving`).
struct SceneGallery: View {
    let scenes: [SceneDocument]
    let facts: SchemaFacts
    let panel: DisplayShape
    /// Why no card is drawn, where the card code says so.
    var notice: String?
    let open: (String) -> Void
    var rename: (String, String) async throws(HostFailure) -> Void = { _, _ in }
    var delete: (String) async throws(HostFailure) -> Void = { _ in }
    @Environment(SceneStore.self) private var store
    @State private var renaming: SceneDocument?
    @State private var deleting: SceneDocument?
    @State private var failure: HostFailure?

    var body: some View {
        sections
            .sheet(item: $renaming) { scene in
                RenameSceneSheet(current: scene.name ?? scene.id) { name in
                    write { () throws(HostFailure) in try await rename(scene.id, name) }
                }
            }
            .confirmationDialog(
                "Delete “\(deleting?.name ?? "")”?",
                isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                presenting: deleting
            ) { scene in
                Button("Delete", role: .destructive) {
                    write { () throws(HostFailure) in try await delete(scene.id) }
                }
            } message: { scene in
                Text(Self.deleteWarning(scene))
            }
            .writeFailureAlert($failure)
    }

    /// My scenes, the built-ins, then the other shapes, the last only when it has a scene.
    private var sections: some View {
        let sections = GallerySections(rows, panel: panel, defaultGrid: facts.defaultGrid)
        return ScrollView {
            VStack(alignment: .leading, spacing: SceneMetrics.gallerySpacing) {
                if let notice {
                    Label(notice, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                section(
                    "My Scenes", sections.mine, fits: true,
                    empty: "Duplicate a built-in scene to make one of your own.")
                section(
                    "Built-in Scenes", sections.builtIn, fits: true,
                    empty: "No built-in scene has this panel's shape.")
                if !sections.otherShapes.isEmpty {
                    section("Other Shapes", sections.otherShapes, fits: false)
                }
            }
            .padding(SceneMetrics.canvasPadding)
        }
    }

    /// What deleting `scene` loses, said before it is confirmed.
    private static func deleteWarning(_ scene: SceneDocument) -> String {
        SceneDrafts.isCopy(scene.id)
            ? "This copy was never saved, so it is discarded."
            : "The scene and its earlier versions are deleted from the panel. This can't be undone."
    }

    /// Runs one write, showing why it failed.
    private func write(_ run: @escaping () async throws(HostFailure) -> Void) {
        Task {
            do throws(HostFailure) {
                try await run()
            } catch {
                failure = error
            }
        }
    }

    /// One scene as the gallery shows it.
    struct Item: Identifiable, GalleryEntry {
        let document: SceneDocument
        let laidOut: LaidOutScene?
        var id: String { document.id }
        var builtIn: Bool { document.builtIn }
        var grid: CellSize? { laidOut?.layout.grid }
    }

    private var rows: [Item] {
        scenes.map { Item(document: $0, laidOut: ScenesPage.laidOut($0, facts: facts)) }
    }

    /// One section; `fits` says its scenes have the panel's shape, and `empty` what goes in it
    /// when it has none.
    private func section(_ title: String, _ items: [Item], fits: Bool, empty: String? = nil)
        -> some View
    {
        VStack(alignment: .leading) {
            Text(title).font(.headline)
            if items.isEmpty, let empty {
                Text(empty).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: columns, alignment: .leading, spacing: SceneMetrics.gallerySpacing) {
                ForEach(items) { item in
                    SceneRow(item: item, panel: panel)
                        .contentShape(Rectangle())
                        .onTapGesture { open(item.id) }
                        .contextMenu { menu(item, fits: fits) }
                }
            }
        }
    }

    @ViewBuilder private func menu(_ item: Item, fits: Bool) -> some View {
        Button("Edit") { open(item.id) }
        if fits, item.laidOut != nil {
            Button("Duplicate") { duplicate(item.document) }
        } else {
            Button("Duplicate for This Panel") {}.disabled(true)
        }
        if !item.document.builtIn {
            Divider()
            Button("Rename…") { renaming = item.document }
            Button("Delete…", role: .destructive) { deleting = item.document }
        }
    }

    /// Copies `document` as its draft shows it, and opens the copy.
    private func duplicate(_ document: SceneDocument) {
        guard let draft = ScenesPage.draft(document, in: store.drafts, facts: facts) else { return }
        open(store.drafts.duplicate(draft, among: scenes).id)
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: SceneMetrics.galleryTileWidth), alignment: .top)]
    }
}

/// A scene's thumbnail and name, with a dot for an unsaved scene and a lock for a built-in one.
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
                if store.drafts.draft(item.id)?.isUnsaved == true {
                    Circle()
                        .frame(
                            width: SceneMetrics.unsavedDotSize, height: SceneMetrics.unsavedDotSize
                        )
                        .foregroundStyle(.secondary)
                        .help("Unsaved")
                }
                Spacer()
                if item.document.builtIn {
                    Image(systemName: "lock.fill").foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder private var thumbnail: some View {
        if let image = store.thumbnails.images[item.id] {
            Image(decorative: image, scale: 1).resizable()
        } else if let laidOut = item.laidOut {
            LayoutPlates(
                layout: store.drafts.draft(item.id)?.layout ?? laidOut.layout, isThumbnail: true
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

#Preview("Gallery, only built-ins") {
    if let preview = GalleryPreview.scenes, let facts = GalleryPreview.facts {
        SceneGallery(
            scenes: preview.filter { $0.builtIn && $0.id == "rta" }, facts: facts,
            panel: DisplayShape(width: 1920, height: 720)
        ) { _ in }
        .environment(SceneStore())
        .frame(width: PanelMetrics.windowDefaultWidth, height: PanelMetrics.windowDefaultHeight)
    }
}

#Preview("Gallery, with an unsaved copy") {
    if let preview = GalleryPreview.scenes, let facts = GalleryPreview.facts,
        let store = GalleryPreview.storeWithCopy(of: preview, facts: facts)
    {
        SceneGallery(
            scenes: store.drafts.listing(preview), facts: facts,
            panel: DisplayShape(width: 1920, height: 720)
        ) { _ in }
        .environment(store)
        .frame(width: PanelMetrics.windowDefaultWidth, height: PanelMetrics.windowDefaultHeight)
    }
}

/// Two built-in scenes and two stored ones, one of each shape each, read as the host gives scene
/// documents.
private enum GalleryPreview {
    static let wide = #"{"grid": {"cols": 96, "rows": 36}, "cards": [{"card": "rta_bars"}]}"#
    static let docs = [
        ("rta", "RTA", true, wide),
        ("default", "Default", true, #"{"cards": [{"card": "meter", "colspan": 32}]}"#),
        ("s1", "My RTA", false, wide),
        ("s2", "Wide", false, #"{"cards": [{"card": "waveform", "colspan": 32}]}"#),
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

    /// A store holding a copy of the first scene, never saved.
    @MainActor static func storeWithCopy(of scenes: [SceneDocument], facts: SchemaFacts)
        -> SceneStore?
    {
        let store = SceneStore()
        guard let first = scenes.first,
            let draft = ScenesPage.draft(first, in: store.drafts, facts: facts)
        else { return nil }
        _ = store.drafts.duplicate(draft, among: scenes)
        return store
    }

    static var scenes: [SceneDocument]? {
        do {
            return try docs.map { id, name, builtIn, doc in
                SceneDocument(
                    id: id, name: name, builtIn: builtIn, fixed: false,
                    doc: try JSONDecoder().decode(JSONValue.self, from: Data(doc.utf8)))
            }
        } catch {
            return nil
        }
    }
}
