import ConsoleCore
import Observation

/// Each scene's layout while the app runs, by scene spec. Edits are kept here until the app quits
/// and never saved, since there is no host to save to yet (`scene-canvas`).
@MainActor @Observable
final class SceneStore {
    private(set) var layouts: [String: SceneLayout] = [:]
    /// The card kind being dragged from the library, set as the drag starts, so the canvas can
    /// preview its size before the drop delivers it.
    var draggedKind: String?

    init(scenes: [SketchScene] = SketchData.shared.scenes) {
        for scene in scenes {
            do {
                layouts[scene.spec] = try Self.layout(of: scene)
            } catch {
                assertionFailure("Stub scene \(scene.spec) is not a valid layout: \(error)")
            }
        }
    }

    func layout(for scene: SketchScene) -> SceneLayout? {
        layouts[scene.spec]
    }

    func keep(_ layout: SceneLayout, for scene: SketchScene) {
        layouts[scene.spec] = layout
    }

    /// The stub scene as a layout: new card ids, the same group names.
    private static func layout(of scene: SketchScene) throws(LayoutRefusal) -> SceneLayout {
        let cards = scene.cards.map { card in
            let cells = CellRect(
                col: card.col, row: card.row, cols: card.colspan, rows: card.rowspan)
            return LayoutCard(kind: card.card, cells: cells, group: card.group)
        }
        return try SceneLayout(grid: CellSize(cols: scene.cols, rows: scene.rows), cards: cards)
    }
}
