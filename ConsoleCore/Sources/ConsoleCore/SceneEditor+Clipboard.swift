import Foundation

/// Cut and Paste on the canvas (`card-clipboard`). Copy changes nothing, so it reads the selection
/// through `CopiedCards` and needs no edit here.
extension SceneEditor {
    /// `copied`'s cards, read afresh on the panel's grid, added as one step named Paste and
    /// selected, where `SceneContent.pasting` places them within `reach`, the pane in cells, on
    /// the panel's first `panelCols` columns. Copied cards that cannot be read are refused.
    public func paste(
        _ copied: CopiedCards, within reach: CellRect, panelCols: Int, placeable: Set<String>
    ) {
        let pasting: CopiedCards.Pasting
        do throws(LayoutRefusal) {
            pasting = try copied.cards(on: CellSize(cols: panelCols, rows: layout.grid.rows))
        } catch {
            commitContent("Paste") { () throws(LayoutRefusal) in throw error }
            return
        }
        commitContent("Paste", selecting: Set(pasting.cards.map(\.id))) {
            () throws(LayoutRefusal) in
            try content.pasting(
                pasting, within: reach, panelCols: panelCols, placeable: placeable)
        }
    }

    /// The selection removed, whole groups and parked cards included, as one step named Cut. The
    /// canvas copies it first.
    public func cut() {
        commitContent("Cut") { () throws(LayoutRefusal) in content.removing(selection) }
    }
}
