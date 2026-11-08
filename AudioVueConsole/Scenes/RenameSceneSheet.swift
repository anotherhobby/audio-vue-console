import ConsoleCore
import SwiftUI

/// Rename…: a scene's new name, refused when empty (`scene-saving`, "A name is not empty").
struct RenameSceneSheet: View {
    let current: String
    let rename: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: SceneMetrics.gallerySpacing) {
            Text("Rename “\(current)”").font(.headline)
            TextField("Name", text: $name)
                .focused($focused)
                .onSubmit(confirm)
            if PanelScenes.name(name) == nil {
                Text(PanelScenes.needsAName).font(.callout).foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Rename", action: confirm)
                    .keyboardShortcut(.defaultAction)
                    .disabled(PanelScenes.name(name) == nil)
            }
        }
        .padding()
        .frame(width: SceneMetrics.renameSheetWidth)
        .onAppear {
            name = current
            focused = true
        }
    }

    private func confirm() {
        guard let name = PanelScenes.name(name) else { return }
        rename(name)
        dismiss()
    }
}

#Preview("Renaming a scene") {
    RenameSceneSheet(current: "RTA copy") { _ in }
}
