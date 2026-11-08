import SwiftUI

/// "Scene:" and the scene's name above the canvas, with "Edited" beside it while unsaved (design D7),
/// as the Panel page's toolbar says "Panel:". Where the scene may be renamed, a double-click edits
/// the name in place: Return or leaving the field commits it as one rename, and Escape puts it back.
struct SceneNameTitle: View {
    let name: String
    let isUnsaved: Bool
    /// Renames the scene, nil for a built-in, which is never renamed.
    let rename: ((String) async -> Void)?
    /// The name being typed, while the field is open.
    @State private var typed: String?
    /// A committed name the host has not yet answered for, shown in its place meanwhile.
    @State private var pending: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Scene:")
            if typed != nil {
                field
            } else {
                label
            }
        }
        .font(.title3.weight(.semibold))
        .onChange(of: name) { pending = nil }
    }

    private var label: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(pending ?? name)
            if isUnsaved {
                Text("Edited").font(.callout).foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            if rename != nil { typed = pending ?? name }
        }
        .help(rename == nil ? "" : "Double-click to rename")
    }

    private var field: some View {
        TextField("Scene Name", text: Binding(get: { typed ?? "" }, set: { typed = $0 }))
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.center)
            .frame(maxWidth: SceneMetrics.nameFieldWidth)
            .focused($isFocused)
            .onAppear { isFocused = true }
            .onSubmit(commit)
            .onExitCommand { typed = nil }
            .onChange(of: isFocused) { _, focused in if !focused { commit() } }
    }

    /// Commits the typed name once: the field closes first, so its losing focus commits nothing.
    private func commit() {
        guard let typed, let rename else { return }
        self.typed = nil
        guard typed != (pending ?? name) else { return }
        pending = typed
        Task {
            await rename(typed)
            pending = nil
        }
    }
}

#Preview("Name, edited") {
    VStack(spacing: SceneMetrics.gallerySpacing) {
        SceneNameTitle(name: "My RTA", isUnsaved: true) { _ in }
        SceneNameTitle(name: "Stereo (built-in)", isUnsaved: false, rename: nil)
    }
    .padding()
}
