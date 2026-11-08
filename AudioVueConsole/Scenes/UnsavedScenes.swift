import AppKit
import ConsoleCore
import Observation
import SwiftUI

/// Settles unsaved scenes before a quit or a switch of panel would lose them (design D6): it asks
/// Save All, Discard or Cancel, naming them, and goes on only after Save All has saved every one
/// or after Discard.
@MainActor @Observable
final class UnsavedScenes {
    /// The question being asked, and what follows each answer.
    struct Question {
        let names: [String]
        let writes: SceneWrites
        let proceed: () -> Void
        let cancelled: () -> Void
    }

    /// The question, while it is asked in a window.
    private(set) var question: Question?
    /// The save that stopped a Save All, while it is shown.
    var failure: SceneWrites.Failed?

    /// Runs `proceed` at once where nothing is unsaved, and otherwise asks first; `cancelled`
    /// runs after Cancel or a failed save.
    func settle(
        _ writes: SceneWrites?, then proceed: @escaping () -> Void,
        cancelled: @escaping () -> Void = {}
    ) {
        guard let writes, case let names = Self.names(writes), !names.isEmpty else {
            proceed()
            return
        }
        question = Question(
            names: names, writes: writes, proceed: proceed, cancelled: cancelled)
    }

    /// Asks with an alert of its own, for a quit with no window to show it in.
    func askModally(
        _ writes: SceneWrites?, then proceed: @escaping () -> Void,
        cancelled: @escaping () -> Void
    ) {
        guard let writes, case let names = Self.names(writes), !names.isEmpty else {
            proceed()
            return
        }
        let alert = NSAlert()
        alert.messageText = Self.title
        alert.informativeText = Self.message(names)
        for answer in ["Save All", "Discard", "Cancel"] { alert.addButton(withTitle: answer) }
        let asked = Question(names: names, writes: writes, proceed: proceed, cancelled: cancelled)
        switch alert.runModal() {
        case .alertFirstButtonReturn: Task { await saveAll(asked, modally: true) }
        case .alertSecondButtonReturn: discard(asked)
        default: cancelled()
        }
    }

    func saveAll() {
        guard let asked = question else { return }
        question = nil
        Task { await saveAll(asked, modally: false) }
    }

    func discard() {
        guard let asked = question else { return }
        question = nil
        discard(asked)
    }

    func cancel() {
        question?.cancelled()
        question = nil
    }

    private func saveAll(_ asked: Question, modally: Bool) async {
        do throws(SceneWrites.Failed) {
            try await asked.writes.saveAll()
            asked.proceed()
        } catch {
            asked.cancelled()
            guard modally else {
                failure = error
                return
            }
            let alert = NSAlert()
            alert.messageText = Self.failureTitle(error)
            alert.informativeText = WriteFailureText.message(error.failure)
            alert.runModal()
        }
    }

    private func discard(_ asked: Question) {
        asked.writes.discardAll()
        asked.proceed()
    }

    private static func names(_ writes: SceneWrites) -> [String] {
        writes.drafts.unsaved(writes.scenes.scenes).map { $0.name ?? $0.id }
    }

    static let title = "Some Scenes Aren't Saved"

    static func message(_ names: [String]) -> String {
        """
        \(names.joined(separator: ", ")). Save All stores them on the panel; Discard drops the \
        changes.
        """
    }

    static func failureTitle(_ failed: SceneWrites.Failed) -> String {
        "“\(failed.name ?? failed.id)” Wasn't Saved"
    }
}

extension View {
    /// The unsaved scenes' question and a failed Save All, shown in this view's window while
    /// `shown`.
    func unsavedScenesAlerts(_ unsaved: UnsavedScenes, shown: Bool = true) -> some View {
        alert(
            UnsavedScenes.title,
            isPresented: Binding(get: { shown && unsaved.question != nil }, set: { _ in }),
            presenting: unsaved.question
        ) { _ in
            Button("Save All") { unsaved.saveAll() }
            Button("Discard", role: .destructive) { unsaved.discard() }
            Button("Cancel", role: .cancel) { unsaved.cancel() }
        } message: { question in
            Text(UnsavedScenes.message(question.names))
        }
        .alert(
            unsaved.failure.map(UnsavedScenes.failureTitle) ?? "",
            isPresented: Binding(
                get: { shown && unsaved.failure != nil }, set: { if !$0 { unsaved.failure = nil } }),
            presenting: unsaved.failure
        ) { _ in
            Button("OK") {}
        } message: { failed in
            Text(WriteFailureText.message(failed.failure))
        }
    }
}
