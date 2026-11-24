import Foundation

/// The scene's own settings and blocks, each change one undoable step (`scene-settings`, design D2).
extension SceneEditor {
    /// Sets the scene block `block`'s setting `key`, declared as `label`, to `value`
    /// (`scene-settings`, design D2).
    public func setBlock(_ block: String, _ key: String, to value: JSONValue, label: String) {
        var fields = content.blocks[block]?.objectValue ?? [:]
        fields[key] = value
        replace(block: block, with: fields, label: label)
    }

    /// Leaves the scene block `block`'s setting `key`, declared as `label`, unset, so the scene
    /// takes its default. A block left with no settings is removed.
    public func useDefault(block: String, key: String, label: String) {
        var fields = content.blocks[block]?.objectValue ?? [:]
        fields[key] = nil
        commitContent("Use Default for \(label)") { () throws(LayoutRefusal) in
            blocks(content, with: block, as: fields)
        }
    }

    /// Sets the scene's own setting `key`, one outside any block such as its typeface, declared
    /// as `label`, to `value`.
    public func setScene(_ key: String, to value: JSONValue, label: String) {
        commitContent("Change \(label)") { () throws(LayoutRefusal) in
            var edited = content
            edited.blocks[key] = value
            return edited
        }
    }

    /// Leaves the scene's own setting `key`, declared as `label`, unset.
    public func useDefault(scene key: String, label: String) {
        commitContent("Use Default for \(label)") { () throws(LayoutRefusal) in
            var edited = content
            edited.blocks[key] = nil
            return edited
        }
    }

    /// Replaces the whole scene block `block` with `fields`, as one step named for `label`, as a
    /// backdrop's change of source is (design D3). Empty `fields` remove the block.
    public func replace(block: String, with fields: [String: JSONValue], label: String) {
        commitContent("Change \(label)") { () throws(LayoutRefusal) in
            blocks(content, with: block, as: fields)
        }
    }

    /// `content` with the block `block` holding `fields`, or without it where they are empty.
    private func blocks(_ content: SceneContent, with block: String, as fields: [String: JSONValue])
        -> SceneContent
    {
        var edited = content
        edited.blocks[block] = fields.isEmpty ? nil : .object(fields)
        return edited
    }
}
