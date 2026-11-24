import Foundation

/// The install blocks a scene inherits from, held with their revisions and written on them
/// (`panel-display`; `track-native-logo` design D2). `PanelScenes` holds the app's one copy, so a
/// write shows at once in the Display page and in every scene that leaves the setting unset.
extension PanelScenes {
    /// Stores `doc` as the install block `block`'s next revision, made on the revision held. A
    /// stored write is held as written. A stale one reads the blocks again, so the host's values
    /// are shown, and is thrown back.
    public func writeInstall(_ doc: [String: JSONValue], block: String)
        async throws(HostFailure) -> InstallWritten
    {
        let token = pairing.token
        do throws(HostFailure) {
            let written = try await client.writeInstall(
                doc, block: block, base: installRevisions[block] ?? 0, at: address, token: token)
            installed[block] = .object(doc)
            installRevisions[block] = written.rev
            return written
        } catch {
            if case .stale = error { await readInstall() }
            throw unpairing(error)
        }
    }

    /// Holds `blocks` as the host gave them: each document, its revision, and the viewing block
    /// every request carries.
    func hold(_ blocks: [String: InstallBlockState]) {
        installed = blocks.mapValues { .object($0.doc) }
        installRevisions = blocks.mapValues(\.rev)
        viewing = installed["viewing"] ?? .object([:])
    }

    /// Reads the install blocks again, keeping those held where the host cannot be read.
    private func readInstall() async {
        do throws(HostFailure) {
            hold(try await client.installBlocks(at: address, token: pairing.token))
        } catch {
            _ = unpairing(error)
        }
    }
}
