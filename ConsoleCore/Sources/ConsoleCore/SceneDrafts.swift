import Foundation
import Observation

/// What the app holds of a panel's scenes while it runs and never writes to the host: each scene's
/// edited layout, and the copies Duplicate made (`scene-canvas`, "Edits last until the app quits";
/// `scene-gallery`, "Duplicate makes an unsaved copy").
@MainActor @Observable
public final class SceneDrafts {
    /// The copies made in the app, newest last.
    public private(set) var copies: [SceneDocument] = []
    private var layouts: [String: SceneLayout] = [:]

    public init() {}

    /// The scene `id`'s layout as last edited, or nil where it has not been.
    public func layout(for id: String) -> SceneLayout? {
        layouts[id]
    }

    public func keep(_ layout: SceneLayout, for id: String) {
        layouts[id] = layout
    }

    /// The host's `scenes` with the app's copies after them.
    public func listing(_ scenes: [SceneDocument]) -> [SceneDocument] {
        scenes + copies
    }

    /// A copy of `scene`, as `laidOut` shows it with any edits kept for it, named for it with
    /// "copy" after it, not built in, kept with the app's copies.
    public func duplicate(_ laidOut: LaidOutScene) -> SceneDocument {
        let scene = laidOut.document
        let name = "\(scene.name ?? scene.id) copy"
        var doc = laidOut.doc(for: layouts[scene.id] ?? laidOut.layout).objectValue ?? [:]
        doc["name"] = .string(name)
        let copy = SceneDocument(
            id: "\(Self.copyPrefix)\(UUID().uuidString)", name: name, builtIn: false, fixed: false,
            doc: .object(doc))
        copies.append(copy)
        return copy
    }

    /// Forgets every edit and copy, as when another panel is shown.
    public func forget() {
        copies = []
        layouts = [:]
    }

    /// Whether `id` names a copy made in the app.
    public static func isCopy(_ id: String) -> Bool {
        id.hasPrefix(copyPrefix)
    }

    private static let copyPrefix = "copy-"
}
