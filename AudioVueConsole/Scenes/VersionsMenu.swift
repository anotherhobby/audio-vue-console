import ConsoleCore
import SwiftUI

/// Versions: the scene's current version and each revision the host keeps, newest first, by local
/// date and time (`scene-saving`, "Versions lists the scene's kept revisions"). Choosing one loads
/// it as an unsaved edit; choosing the current version reverts.
struct VersionsMenu: View {
    let session: SceneSession

    var body: some View {
        Menu("Versions", systemImage: "clock.arrow.circlepath") {
            VersionRows(revisions: session.revisions, current: { session.revert() }) {
                session.load($0)
            }
        }
        .disabled(!session.hasVersions)
        .task(id: session.draft?.rev) { await session.readRevisions() }
    }
}

/// The Versions menu's entries: the current version, then each kept revision.
struct VersionRows: View {
    let revisions: [SceneRevision]
    let current: () -> Void
    let load: (SceneRevision) -> Void

    var body: some View {
        Button("Current Version", action: current)
        if !revisions.isEmpty { Divider() }
        ForEach(revisions) { revision in
            Button(revision.savedAt.formatted(date: .abbreviated, time: .shortened)) {
                load(revision)
            }
        }
    }
}

#Preview("Versions, three entries") {
    VStack(alignment: .leading) {
        VersionRows(
            revisions: [
                SceneRevision(
                    rev: 4, savedAt: Date(timeIntervalSince1970: 1_794_085_205), doc: .null),
                SceneRevision(
                    rev: 3, savedAt: Date(timeIntervalSince1970: 1_793_957_400), doc: .null),
            ],
            current: {}, load: { _ in })
    }
    .buttonStyle(.borderless)
    .padding()
}
