import ConsoleCore
import SwiftUI

/// What follows the scene's edits beside the canvas: the library's tiles, drawn again when the
/// scene's settings or a card's setup change, and the selected card's minimum, asked for as its
/// handles show and again when its or the scene's settings change, so a resize reads a held answer
/// (`scene-settings` design D6; `library-setup`; `card-minimum` design D5).
struct FollowingEdits: ViewModifier {
    let editor: SceneEditor?
    let tiles: EditorTiles
    /// Draws the plain and set-up tiles in the scene's settings as edited.
    let drawTiles: () async -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: editor?.content.blocks) { Task { await drawTiles() } }
            .onChange(of: editor?.setups) { old, new in
                Task { await tiles.drawChanged(from: old ?? [:], to: new ?? [:]) }
            }
            .task(id: ResizeTarget(editor)) {
                if let card = editor?.resizableCard { await tiles.askMinimum(of: card) }
            }
    }

    /// What the selected card's minimum depends on: the card that shows handles, without its
    /// cells, and the scene's settings.
    private struct ResizeTarget: Equatable {
        let kind: String?
        let settings: [String: JSONValue]?
        let blocks: [String: JSONValue]?

        @MainActor init(_ editor: SceneEditor?) {
            let card = editor?.resizableCard
            kind = card?.kind
            settings = card?.settings
            blocks = editor?.content.blocks
        }
    }
}
