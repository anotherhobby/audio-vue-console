import Foundation

/// The scene writes as the app's controls make them (`scene-saving`): each write goes to the host
/// through `PanelScenes`, and its outcome to the drafts and the thumbnails, so a saved copy moves
/// to the host's id with its picture. A copy never saved is renamed and deleted in the app alone.
@MainActor
public struct SceneWrites {
    public let scenes: PanelScenes
    public let drafts: SceneDrafts
    public let thumbnails: SceneThumbnails

    public init(scenes: PanelScenes, drafts: SceneDrafts, thumbnails: SceneThumbnails) {
        self.scenes = scenes
        self.drafts = drafts
        self.thumbnails = thumbnails
    }

    /// Saves the scene `id`'s draft, on `overRev` where given, and answers the scene as stored,
    /// whose id is the host's for a copy's first save.
    public func save(_ id: String, overRev: Int? = nil) async throws(HostFailure) -> SceneDocument {
        guard let draft = drafts.draft(id) else { throw .notFound }
        let stored = try await scenes.save(draft, overRev: overRev)
        drafts.saved(stored, was: id)
        if stored.id != id { thumbnails.move(from: id, to: stored.id) }
        return stored
    }

    /// Apply (design D8): saves the scene `id` where it is unsaved, a copy being created first,
    /// then puts it on the panel. A failed save is thrown and nothing is switched. A save stands
    /// whatever becomes of the switch, so the id the scene now has, the host's for a copy's first
    /// save, comes back with the switch's outcome or why it could not be asked for.
    public func apply(_ id: String) async throws(HostFailure)
        -> (id: String, outcome: Result<CommandOutcome, HostFailure>)
    {
        guard let draft = drafts.draft(id) else { throw .notFound }
        let applied = draft.isUnsaved ? try await save(id).id : id
        do throws(HostFailure) {
            return (applied, .success(try await scenes.switchTo(applied)))
        } catch {
            return (applied, .failure(error))
        }
    }

    /// Saves every unsaved scene in listing order, stopping at the first that fails, which is
    /// thrown with the scene's id.
    public func saveAll() async throws(Failed) {
        for draft in drafts.unsaved(scenes.scenes) {
            do throws(HostFailure) {
                _ = try await save(draft.id)
            } catch {
                throw Failed(id: draft.id, name: draft.name, failure: error)
            }
        }
    }

    /// Drops every unsaved scene's edits, and every copy never saved: Discard.
    public func discardAll() {
        for draft in drafts.unsaved(scenes.scenes) { drafts.discard(draft.id) }
    }

    /// Renames the scene `id`: a stored scene on the host, at once, a copy in the app alone. A name
    /// is trimmed and refused when empty.
    public func rename(_ id: String, to name: String) async throws(HostFailure) {
        guard SceneDrafts.isCopy(id) else {
            drafts.renamed(id, to: try await scenes.rename(id, to: name))
            return
        }
        guard let name = PanelScenes.name(name) else {
            throw .invalid([DocumentFailure(place: "name", message: PanelScenes.needsAName)])
        }
        drafts.renameCopy(id, to: name)
    }

    /// Deletes the scene `id`: a stored scene on the host, a copy in the app alone.
    public func delete(_ id: String) async throws(HostFailure) {
        if !SceneDrafts.isCopy(id) { try await scenes.delete(id) }
        drafts.discard(id)
    }

    /// Drops the scene `id`'s edits and reads the host's scene again: Discard Mine.
    public func discardMine(_ id: String) async throws(HostFailure) {
        drafts.discard(id)
        try await scenes.refresh(id)
    }

    /// A save that failed during a Save All: which scene, and why.
    public struct Failed: Error, Equatable {
        public let id: String
        public let name: String?
        public let failure: HostFailure
    }
}
