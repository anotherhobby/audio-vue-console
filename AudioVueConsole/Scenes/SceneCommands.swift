import SwiftUI

/// What the File menu may do to the open scene: each action is nil while it is disabled.
struct SceneFileActions {
    var save: (() -> Void)?
    var revert: (() -> Void)?
}

extension FocusedValues {
    /// The File menu's actions on the scene open in the focused window.
    @Entry var sceneFile: SceneFileActions?
}

/// The File menu's Save (⌘S) and Revert to Saved, acting on the open scene (`scene-saving`).
struct SceneCommands: Commands {
    @FocusedValue(\.sceneFile) private var file

    var body: some Commands {
        CommandGroup(replacing: .saveItem) {
            Button("Save") { file?.save?() }
                .keyboardShortcut("s")
                .disabled(file?.save == nil)
        }
        CommandGroup(after: .saveItem) {
            Button("Revert to Saved") { file?.revert?() }
                .disabled(file?.revert == nil)
        }
    }
}
