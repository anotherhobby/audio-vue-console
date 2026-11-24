import ConsoleCore
import SwiftUI

/// A scene's thumbnail and name, with a dot for an unsaved scene, its Apply button, and a lock for
/// a built-in one.
struct SceneRow: View {
    let item: SceneGallery.Item
    /// The display's width over its height.
    let aspect: Double
    let shape: SceneShape
    /// Applies the scene (`scene-gallery`, "Each scene has an Apply button beside its name").
    var apply: () -> Void = {}
    /// Whether another Apply from the gallery is under way.
    var isApplying = false
    @Environment(SceneStore.self) private var store

    /// The scene as edited where it has a draft, else as read.
    private var shown: (scene: LaidOutScene, content: SceneContent)? {
        let draft = store.drafts.draft(item.id)
        return (draft?.laidOut ?? item.laidOut).map { ($0, draft?.content ?? $0.content) }
    }

    private var isTooWide: Bool { shown.map { $0.scene.isTooWide($0.content) } ?? false }

    /// Why the scene cannot be applied from here, as the editor would say, or nil where it can.
    private var applyReason: String? {
        guard let shown else { return "This scene can't be read" }
        return ApplyHelp.reason(
            hasParked: store.drafts.draft(item.id)?.hasParked == true, isTooWide: isTooWide,
            hasCards: !shown.content.layout.cards.isEmpty)
    }

    /// Whether the panel would refuse the scene for holding what its schema does not take
    /// (`scene-gallery`, "A scene that needs a repair is marked in the gallery").
    private var needsRepair: Bool { store.drafts.repair(of: item.document, shape: shape) != nil }

    var body: some View {
        VStack(alignment: .leading) {
            thumbnail
                .aspectRatio(aspect, contentMode: .fit)
                .background(CanvasMetrics.backdrop)
                .frame(maxHeight: SceneMetrics.galleryThumbnailHeight, alignment: .leading)
            nameLine
            if isTooWide {
                Text("Too wide for this panel").font(.callout).foregroundStyle(.secondary)
            }
            if needsRepair {
                Text(RepairText.note).font(.callout).foregroundStyle(.secondary)
            }
            if let parked = store.drafts.draft(item.id)?.parkedCount, parked > 0 {
                Text(ParkingText.note(parked)).font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    /// The scene's name, its unsaved dot, its Apply button, and a lock where it is built in.
    private var nameLine: some View {
        HStack {
            Text(item.document.name ?? item.document.id)
            if store.drafts.draft(item.id)?.isUnsaved == true {
                Circle()
                    .frame(width: SceneMetrics.unsavedDotSize, height: SceneMetrics.unsavedDotSize)
                    .foregroundStyle(.secondary)
                    .help("Unsaved")
            }
            Button("Apply", systemImage: "play.rectangle", action: apply)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .disabled(applyReason != nil || isApplying)
                .help(applyReason ?? "Apply")
            Spacer()
            if item.document.builtIn {
                Image(systemName: "lock.fill").foregroundStyle(.secondary)
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
