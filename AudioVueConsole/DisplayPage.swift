import ConsoleCore
import SwiftUI

/// The Display page: the panel's display size, and the installation's idle settings, each written
/// to the host's `display` block when changed, saying when the panel takes it (`panel-display`).
/// `PanelScenes` holds the block, so a scene shows a written value at once (design D2).
struct DisplayPage: View {
    let connection: HostConnection
    @Environment(SceneStore.self) private var store
    /// What the last write came to, said under the settings (design D4).
    @State private var note: String?
    @State private var isWriting = false

    var body: some View {
        Form {
            if connection.isPaired != true || store.scenes?.state == .unpaired {
                Text("Pair with the panel on the Panel page to set its display.")
                    .foregroundStyle(.secondary)
            } else if let scenes = store.scenes, scenes.state == .loaded {
                Section("Screen") {
                    LabeledContent("Size", value: Self.size(scenes.display))
                }
                Section {
                    ForEach(Self.declarations(scenes)) { row($0, scenes) }
                } header: {
                    Text("When Idle")
                } footer: {
                    if let note { Text(note) }
                }
            } else {
                ProgressView("Reading the panel's settings…")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Display")
    }

    /// The settings the host's schema declares for its `display` install block, in its order.
    private static func declarations(_ scenes: PanelScenes) -> [SettingDeclaration] {
        scenes.facts?.installSettings[block]?.settings ?? []
    }

    private func row(_ declaration: SettingDeclaration, _ scenes: PanelScenes) -> SettingRow {
        let held = scenes.installed[Self.block]?.objectValue ?? [:]
        let key = declaration.key
        return SettingRow(
            declaration: declaration, value: declaration.value(in: scenes.installed[Self.block]),
            note: nil,
            edit: isWriting
                ? nil
                : SettingEdit(
                    set: { value in write(held.merging([key: value]) { $1 }, to: scenes) },
                    useDefault: { write(held.filter { $0.key != key }, to: scenes) }))
    }

    /// Writes `doc` as the block, then says what came of it.
    private func write(_ doc: [String: JSONValue], to scenes: PanelScenes) {
        isWriting = true
        Task {
            defer { isWriting = false }
            do throws(HostFailure) {
                note = Self.words(try await scenes.writeInstall(doc, block: Self.block).applies)
            } catch {
                note = Self.words(error)
            }
        }
    }

    /// When the panel takes a stored write, in the host's terms.
    private static func words(_ applies: InstallWritten.Applies?) -> String {
        switch applies {
        case .onStart?: "Saved. Applies at the panel's next start."
        case .onReload?: "Saved. Applies when the panel next reloads its scene."
        case .onRestart?, .restarted?, nil: "Saved."
        }
    }

    /// Why a write was not stored: the host's words where it gave them.
    private static func words(_ failure: HostFailure) -> String {
        switch failure {
        case .stale:
            "The panel's settings changed elsewhere. These are its settings now."
        case .invalid(let failures):
            "Not saved: " + failures.map(\.message).joined(separator: "; ")
        default:
            "Not saved: " + ReadFailureText.text(failure)
        }
    }

    private static func size(_ display: PixelSize?) -> String {
        display.map { "\($0.width) × \($0.height)" } ?? "Unknown"
    }

    /// The install block this page shows.
    private static let block = "display"
}
