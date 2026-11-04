import ConsoleCore
import SwiftUI

extension FocusedValues {
    /// The editor of the scene canvas in the focused window, for the Arrange menu.
    @Entry var sceneEditor: SceneEditor?
}

/// The Arrange menu: Group (⌘G), enabled only when the selection can be grouped, and Ungroup
/// (⇧⌘G), enabled when it holds a group (`scene-canvas`).
struct ArrangeCommands: Commands {
    @FocusedValue(\.sceneEditor) private var editor

    var body: some Commands {
        CommandMenu("Arrange") {
            Button("Group") { editor?.group() }
                .keyboardShortcut("g")
                .disabled(editor == nil || editor?.groupRefusal != nil)
            Button("Ungroup") { editor?.ungroup() }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                .disabled(editor?.canUngroup != true)
        }
    }
}
