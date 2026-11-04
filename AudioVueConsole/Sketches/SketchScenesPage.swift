import SwiftUI

/// The Scenes section: a gallery of scenes, this panel's shape first. Clicking one opens it for
/// editing, and `isEditing` tells the window to give the editor the width.
struct SketchScenesPage: View {
    let panel: SketchPanel
    let scenes: [SketchScene]
    @Binding var isEditing: Bool
    @State private var path: [String] = []

    var body: some View {
        NavigationStack(path: $path) {
            SketchSceneGallery(panel: panel, scenes: scenes) { path.append($0.id) }
                .navigationTitle("Scenes")
                .navigationDestination(for: String.self) { id in
                    if let scene = scenes.first(where: { $0.id == id }) {
                        SketchSceneEditor(
                            panel: panel, scene: scene,
                            roster: SketchCardKind.roster(from: scenes))
                    }
                }
        }
        .onChange(of: path) { isEditing = !path.isEmpty }
    }
}

struct SketchSceneGallery: View {
    let panel: SketchPanel
    let scenes: [SketchScene]
    let open: (SketchScene) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SketchMetrics.gallerySpacing) {
                section("For this panel, \(panel.shapeName)", scenes.filter(panel.fits), fits: true)
                section("Other shapes", scenes.filter { !panel.fits($0) }, fits: false)
            }
            .padding(SketchMetrics.canvasPadding)
        }
    }

    private func section(_ title: String, _ items: [SketchScene], fits: Bool) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.headline)
            LazyVGrid(columns: columns, alignment: .leading, spacing: SketchMetrics.gallerySpacing)
            {
                ForEach(items) { scene in
                    SketchSceneRow(
                        scene: scene, fits: fits, isShowing: scene.spec == panel.scene,
                        height: SketchMetrics.galleryThumbnailHeight
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { open(scene) }
                    .contextMenu {
                        Button("Edit") { open(scene) }
                        Button(fits ? "Duplicate" : "Duplicate for This Panel") {}
                        Button("Show on Panel") {}.disabled(!fits)
                    }
                }
            }
        }
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: SketchMetrics.galleryTileWidth), alignment: .top)]
    }
}

/// A scene's thumbnail and name, with a lock for a built-in scene and a play mark for the one the
/// panel is showing.
struct SketchSceneRow: View {
    let scene: SketchScene
    let fits: Bool
    let isShowing: Bool
    let height: CGFloat

    var body: some View {
        VStack(alignment: .leading) {
            SketchPlates(scene: scene, cardID: .constant(nil), isThumbnail: true)
                .aspectRatio(scene.aspect, contentMode: .fit)
                .background(SketchMetrics.backdrop)
                .frame(maxHeight: height, alignment: .leading)
            HStack {
                Text(scene.name)
                Spacer()
                if scene.builtIn { Image(systemName: "lock.fill").foregroundStyle(.secondary) }
                if isShowing { Image(systemName: "play.fill").foregroundStyle(.green) }
            }
        }
        .opacity(fits ? 1.0 : SketchMetrics.mismatchOpacity)
    }
}

#Preview("Scenes gallery") {
    if let panel = SketchData.shared.panels.first {
        SketchScenesPage(
            panel: panel, scenes: SketchData.shared.scenes, isEditing: .constant(false)
        )
        .frame(
            width: SketchMetrics.windowDefaultWidth,
            height: SketchMetrics.windowDefaultHeight)
    }
}
