import CoreGraphics
import Foundation
import Observation

/// The gallery's thumbnails, each a scene as the helper draws it, stacked and scaled down
/// (`scene-gallery`, "A thumbnail is the scene as the helper draws it"). They are drawn one after
/// another in the queue's thumbnails lane, so the open scene's requests go first.
@MainActor @Observable
public final class SceneThumbnails {
    /// The width thumbnails are drawn at, in pixels.
    public static let width = 480

    public private(set) var images: [String: CGImage] = [:]

    public init() {}

    /// Draws each of `scenes` it has no thumbnail for, at the layout it shows, through `queue`.
    /// A scene the helper cannot draw keeps its plain boxes.
    public func draw(
        _ scenes: [(scene: LaidOutScene, layout: SceneLayout)], context: RenderContext,
        through queue: RenderQueue
    ) async {
        for (scene, layout) in scenes where images[scene.document.id] == nil {
            let request = RenderRequest(
                doc: scene.doc(for: layout), builtIn: scene.document.builtIn, context: context)
            let result = await queue.submit(
                request.message, lane: .thumbnails, key: "thumbnail:\(scene.document.id)")
            guard case .success(let answer)? = result else { continue }
            do throws(RenderFailure) {
                let layers = try RenderedLayer.layers(
                    of: answer, cardIDs: layout.cards.map(\.id))
                images[scene.document.id] = Thumbnail.flatten(
                    layers: layers, display: context.display, width: Self.width)
            } catch {
                continue
            }
        }
    }

    /// The open scene's thumbnail from the layers the canvas holds, so it follows the edits.
    public func update(_ id: String, from rendering: SceneRendering) {
        guard let backdrop = rendering.backdrop else { return }
        images[id] = Thumbnail.flatten(
            layers: [backdrop] + rendering.orderedPlates.map(\.layer),
            display: rendering.context.display, width: Self.width)
    }

    /// Moves the thumbnail of `old` to `new`, as when a copy's first save gives it the host's id.
    public func move(from old: String, to new: String) {
        images[new] = images.removeValue(forKey: old)
    }

    /// Forgets every thumbnail, as when another panel is shown or the code differs.
    public func forget() {
        images = [:]
    }
}
