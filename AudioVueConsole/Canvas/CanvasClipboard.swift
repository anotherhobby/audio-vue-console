import AppKit
import ConsoleCore
import SwiftUI
import UniformTypeIdentifiers

/// The canvas's Copy, Cut and Paste, while it has focus (`card-clipboard`, design D4). Copy and Cut
/// write the pasteboard themselves, so a refused Cut leaves what was copied before; Paste is enabled
/// only while the pasteboard holds copied cards. A text field with focus keeps its own.
struct CanvasClipboard: ViewModifier {
    let editor: SceneEditor
    /// The scene as read, which writes each copied card's entry; nil where it cannot be read.
    let laidOut: LaidOutScene?
    /// Where a paste may park cards: the pane in cells.
    let reach: CellRect
    let panelCols: Int
    /// The cards the panel's schema marks placeable, by name.
    let placeable: Set<String>

    private static let type = UTType(exportedAs: CopiedCards.typeIdentifier)
    private static let pasteboardType = NSPasteboard.PasteboardType(CopiedCards.typeIdentifier)

    func body(content: Content) -> some View {
        content
            .onCommand(#selector(NSText.copy(_:))) { copy() }
            .onCommand(#selector(NSText.cut(_:))) { cut() }
            .onPasteCommand(of: [Self.type], validator: { _ in Self.copied() }, perform: paste)
    }

    /// Puts the selection on the pasteboard; nothing where nothing is selected.
    @discardableResult
    private func copy() -> Bool {
        guard let laidOut,
            let copied = CopiedCards(editor.selection, of: editor.content, in: laidOut)
        else { return false }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(copied.data, forType: Self.pasteboardType)
        return true
    }

    /// Copies the selection and removes it, or, on a scene that cannot be edited, says why and
    /// copies nothing.
    private func cut() {
        guard editor.readOnly == nil else {
            editor.cut()
            return
        }
        if copy() { editor.cut() }
    }

    /// The cards on the pasteboard, or nil where it holds none.
    private static func copied() -> CopiedCards? {
        guard let data = NSPasteboard.general.data(forType: pasteboardType) else { return nil }
        return CopiedCards(data: data)
    }

    private func paste(_ copied: CopiedCards) {
        editor.paste(copied, within: reach, panelCols: panelCols, placeable: placeable)
    }
}
