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

    /// One scene to picture: as read, and as its content shows it.
    public typealias Pictured = (scene: LaidOutScene, content: SceneContent)

    /// Shows the thumbnails `cache` keeps for `scenes` as they are now, with no request, and
    /// drops the files of every other scene from it.
    public func restore(_ scenes: [Pictured], context: RenderContext, from cache: ThumbnailCache) {
        var kept: Set<String> = []
        for (scene, content) in scenes {
            guard let file = cache.file(for: Self.request(scene, content, context)) else {
                continue
            }
            kept.insert(file.lastPathComponent)
            if images[scene.document.id] == nil {
                images[scene.document.id] = cache.image(at: file)
            }
        }
        cache.prune(keeping: kept)
    }

    /// Draws each of `scenes` it has no thumbnail for, as its content shows it, through `queue`,
    /// keeping each in `cache` where one is given. A scene the helper cannot draw keeps its
    /// plain boxes, and one with no cards, or too wide for the panel, is not asked for.
    public func draw(
        _ scenes: [Pictured], context: RenderContext, through queue: RenderQueue,
        keeping cache: ThumbnailCache? = nil
    ) async {
        for (scene, content) in scenes
        where images[scene.document.id] == nil && !content.layout.cards.isEmpty
            && !scene.isTooWide(content)
        {
            let request = Self.request(scene, content, context)
            let result = await queue.submit(
                request.message, lane: .thumbnails, key: "thumbnail:\(scene.document.id)")
            guard case .success(let answer)? = result else { continue }
            do throws(RenderFailure) {
                let layers = try RenderedLayer.layers(
                    of: answer, cardIDs: content.layout.cards.map(\.id))
                let image = Thumbnail.flatten(
                    layers: layers, display: context.display, width: Self.width)
                images[scene.document.id] = image
                if let image, let file = cache?.file(for: request) {
                    cache?.keep(image, in: file)
                }
            } catch {
                continue
            }
        }
    }

    private static func request(
        _ scene: LaidOutScene, _ content: SceneContent, _ context: RenderContext
    ) -> RenderRequest {
        RenderRequest(
            doc: scene.doc(for: content), builtIn: scene.document.builtIn, context: context)
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
