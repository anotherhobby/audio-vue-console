import Foundation
import Observation

/// What the editor's banner says of the last Apply or Reset (design D7): the panel's outcome, or
/// why it could not be asked.
public struct EditorNote: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case apply
        case reset
    }

    public let kind: Kind
    public let result: Result<CommandOutcome, HostFailure>

    public init(kind: Kind, result: Result<CommandOutcome, HostFailure>) {
        self.kind = kind
        self.result = result
    }
}

/// One open scene's writes and what they leave to show (`scene-saving`): Save, Rename, Discard
/// Mine, Revert to Saved and Versions, the failure to show, and the kept revisions. A change of
/// parse, from a version, a revert from one, or Discard Mine, is counted in `parses`, so the
/// canvas draws the new parse; the editor's undo never reaches across one (design D9).
@MainActor @Observable
public final class SceneSession {
    public let id: String
    /// The failed write to show, until the user answers it.
    public var failure: HostFailure?
    /// The scene's kept earlier revisions, newest first, as last read.
    public private(set) var revisions: [SceneRevision] = []
    /// How many times the draft's parse has changed under the editor.
    public private(set) var parses = 0
    /// The last Apply's or Reset's outcome, until the next, or the next edit clears it.
    public var note: EditorNote?

    @ObservationIgnored private let writes: SceneWrites
    @ObservationIgnored private weak var editor: SceneEditor?

    public init(id: String, writes: SceneWrites) {
        self.id = id
        self.writes = writes
    }

    /// Edits through `editor`, the one the canvas shows for this scene.
    public func attach(_ editor: SceneEditor) {
        self.editor = editor
    }

    public var draft: Draft? { writes.drafts.draft(id) }

    public var isUnsaved: Bool { draft?.isUnsaved ?? false }

    /// Whether the scene may be written: shown in an editor that may edit it.
    private var isEditable: Bool { editor != nil && editor?.readOnly == nil }

    public var canSave: Bool { isEditable && isUnsaved }

    /// Revert to Saved: an unsaved scene the host holds a revision of.
    public var canRevert: Bool { isEditable && isUnsaved && draft?.rev != nil }

    /// Versions: an editable scene the host stores.
    public var hasVersions: Bool { isEditable && draft?.rev != nil }

    /// Saves the draft, on `overRev` where the user chose Save Over It, answering the scene as
    /// stored, or nil where the save failed and `failure` says why.
    @discardableResult
    public func save(overRev: Int? = nil) async -> SceneDocument? {
        do throws(HostFailure) {
            return try await writes.save(id, overRev: overRev)
        } catch {
            failure = error
            return nil
        }
    }

    /// Renames the scene: a stored scene on the host at once, a copy in the app.
    public func rename(_ name: String) async {
        do throws(HostFailure) {
            try await writes.rename(id, to: name)
        } catch {
            failure = error
        }
    }

    /// Drops this edit and shows the host's scene, read again.
    public func discardMine() async {
        guard let grid = draft?.layout.grid else { return }
        do throws(HostFailure) {
            try await writes.discardMine(id)
        } catch {
            failure = error
        }
        guard let base = writes.scenes.scenes.first(where: { $0.id == id }) else { return }
        do throws(LayoutRefusal) {
            _ = try writes.drafts.draft(for: base, defaultGrid: grid)
        } catch {
            failure = .invalid([DocumentFailure(place: "", message: error.description)])
            return
        }
        newParse()
    }

    /// Reads the scene's kept revisions for the Versions menu.
    public func readRevisions() async {
        guard draft?.rev != nil else { return }
        do throws(HostFailure) {
            revisions = try await writes.scenes.revisions(id)
        } catch {
            revisions = []
        }
    }

    /// Shows `revision` as an unsaved edit under the scene's current name.
    public func load(_ revision: SceneRevision) {
        do throws(LayoutRefusal) {
            try writes.drafts.load(revision, for: id)
        } catch {
            failure = .invalid([DocumentFailure(place: "", message: error.description)])
            return
        }
        newParse()
    }

    /// Puts the scene back as the host holds it: an undoable Revert on the same parse, or the
    /// host's document read afresh after a version was loaded.
    public func revert() {
        guard let base = writes.scenes.scenes.first(where: { $0.id == id }) else { return }
        do throws(LayoutRefusal) {
            guard let reverted = try writes.drafts.revert(id, to: base) else { return }
            if reverted.newParse {
                newParse()
            } else {
                editor?.revert(to: reverted.layout)
            }
        } catch {
            failure = .invalid([DocumentFailure(place: "", message: error.description)])
        }
    }

    /// Apply (`scene-apply`): saves where unsaved, then puts the scene on the panel, the outcome
    /// in `note`. Answers the scene's id after it, the host's for a copy's first save, or nil
    /// where the save failed and `failure` says why.
    public func apply() async -> String? {
        do throws(HostFailure) {
            let applied = try await writes.apply(id)
            note = EditorNote(kind: .apply, result: applied.outcome)
            return applied.id
        } catch {
            failure = error
            return nil
        }
    }

    /// Reset: restarts the panel's measurement, the outcome in `note`.
    public func reset() async {
        do throws(HostFailure) {
            note = EditorNote(kind: .reset, result: .success(try await writes.scenes.reset()))
        } catch {
            note = EditorNote(kind: .reset, result: .failure(error))
        }
    }

    /// Shows the draft's new parse, with no undo left from the old one.
    private func newParse() {
        if let draft { editor?.replace(with: draft.layout) }
        parses += 1
    }
}
