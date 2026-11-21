import ConsoleCore
import SwiftUI

/// The gallery of a panel's scenes: the user's, then the built-ins, each pictured by its
/// thumbnail, or its boxes until the helper draws it, and noted where it is too wide for the
/// panel (`scene-gallery`). Its menu renames and deletes any scene but a built-in
/// (`scene-saving`).
struct SceneGallery: View {
    let scenes: [SceneDocument]
    /// The panel's grid, which every scene is laid out on.
    let grid: CellSize
    /// The display's width over its height.
    let aspect: Double
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
            .toolbar {
                ToolbarItem {
                    Button("New Scene", systemImage: "plus", action: newScene)
                        .help("Make a scene with no cards")
                }
            }
    }

    /// Makes a scene with no cards on the panel's grid, and opens it.
    private func newScene() {
        do {
            open(try store.drafts.new(on: grid, among: scenes).id)
        } catch {
            // A scene with no cards holds nothing a layout refuses.
            return
        }
    }

    /// My scenes, then the built-ins.
    private var sections: some View {
        let sections = GallerySections(rows)
        return ScrollView {
            VStack(alignment: .leading, spacing: SceneMetrics.gallerySpacing) {
                if let notice {
                    Label(notice, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                section(
                    "My Scenes", sections.mine,
                    empty: "Make a new scene, or duplicate a built-in one.")
                section(
                    "Built-in Scenes", sections.builtIn, empty: "The panel lists no built-in scene."
                )
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
    }

    private var rows: [Item] {
        scenes.map { Item(document: $0, laidOut: ScenesPage.laidOut($0, on: grid)) }
    }

    /// One section, and `empty`, what goes in it when it has none.
    private func section(_ title: String, _ items: [Item], empty: String) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.headline)
            if items.isEmpty {
                Text(empty).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: columns, alignment: .leading, spacing: SceneMetrics.gallerySpacing) {
                ForEach(items) { item in
                    SceneRow(item: item, aspect: aspect)
                        .contentShape(Rectangle())
                        .onTapGesture { open(item.id) }
                        .contextMenu { menu(item) }
                }
            }
        }
    }

    @ViewBuilder private func menu(_ item: Item) -> some View {
        Button("Edit") { open(item.id) }
        Button("Duplicate") { duplicate(item.document) }.disabled(item.laidOut == nil)
        if !item.document.builtIn {
            Divider()
            Button("Rename…") { renaming = item.document }
            Button("Delete…", role: .destructive) { deleting = item.document }
        }
    }

    /// Copies `document` as its draft shows it, and opens the copy.
    private func duplicate(_ document: SceneDocument) {
        guard let draft = ScenesPage.draft(document, in: store.drafts, on: grid) else { return }
        open(store.drafts.duplicate(draft, among: scenes).id)
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: SceneMetrics.galleryTileWidth), alignment: .top)]
    }
}

/// A scene's thumbnail and name, with a dot for an unsaved scene and a lock for a built-in one.
struct SceneRow: View {
    let item: SceneGallery.Item
    /// The display's width over its height.
    let aspect: Double
    @Environment(SceneStore.self) private var store

    /// The scene as edited where it has a draft, else as read.
    private var shown: (scene: LaidOutScene, content: SceneContent)? {
        let draft = store.drafts.draft(item.id)
        return (draft?.laidOut ?? item.laidOut).map { ($0, draft?.content ?? $0.content) }
    }

    private var isTooWide: Bool { shown.map { $0.scene.isTooWide($0.content) } ?? false }

    var body: some View {
        VStack(alignment: .leading) {
            thumbnail
                .aspectRatio(aspect, contentMode: .fit)
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
            if isTooWide {
                Text("Too wide for this panel").font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var thumbnail: some View {
        if let image = store.thumbnails.images[item.id] {
            Image(decorative: image, scale: 1).resizable()
        } else if let shown {
            // A scene wider than the panel's grid is wider by the same cells.
            let layout = shown.content.layout
            LayoutPlates(layout: layout, isThumbnail: true)
                .aspectRatio(
                    aspect * Double(layout.grid.cols) / Double(shown.scene.panel.cols),
                    contentMode: .fit)
        } else {
            Color.clear
        }
    }
}

#Preview("Gallery, a 16:9 panel") {
    if let preview = GalleryPreview.scenes {
        SceneGallery(
            scenes: preview, grid: CellSize(cols: 64, rows: 36), aspect: 16.0 / 9.0
        ) { _ in }
        .environment(SceneStore())
        .frame(width: PanelMetrics.windowDefaultWidth, height: PanelMetrics.windowDefaultHeight)
    }
}

#Preview("Gallery, only built-ins") {
    if let preview = GalleryPreview.scenes {
        SceneGallery(
            scenes: preview.filter { $0.builtIn && $0.id == "rta" },
            grid: CellSize(cols: 64, rows: 36), aspect: 16.0 / 9.0
        ) { _ in }
        .environment(SceneStore())
        .frame(width: PanelMetrics.windowDefaultWidth, height: PanelMetrics.windowDefaultHeight)
    }
}

#Preview("Gallery, with an unsaved copy") {
    if let preview = GalleryPreview.scenes,
        let store = GalleryPreview.storeWithCopy(of: preview, on: CellSize(cols: 64, rows: 36))
    {
        SceneGallery(
            scenes: store.drafts.listing(preview), grid: CellSize(cols: 64, rows: 36),
            aspect: 16.0 / 9.0
        ) { _ in }
        .environment(store)
        .frame(width: PanelMetrics.windowDefaultWidth, height: PanelMetrics.windowDefaultHeight)
    }
}

/// Two built-in scenes and two stored ones on a 16:9 panel, read as the host gives scene
/// documents; "My RTA" reaches past the panel's last column.
private enum GalleryPreview {
    static let docs = [
        ("rta", "RTA", true, #"{"cards": [{"card": "rta_bars", "colspan": 48}]}"#),
        ("default", "Default", true, #"{"cards": [{"card": "rta_bars"}]}"#),
        ("s1", "My RTA", false, #"{"cards": [{"card": "rta_bars", "colspan": 96}]}"#),
        ("s2", "Wide", false, #"{"cards": [{"card": "waveform", "colspan": 32}]}"#),
    ]

    /// A store holding a copy of the first scene, never saved.
    @MainActor static func storeWithCopy(of scenes: [SceneDocument], on grid: CellSize)
        -> SceneStore?
    {
        let store = SceneStore()
        guard let first = scenes.first,
            let draft = ScenesPage.draft(first, in: store.drafts, on: grid)
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
