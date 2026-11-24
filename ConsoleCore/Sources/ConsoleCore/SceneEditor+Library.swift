import Foundation

/// The library card selected and each card's setup (`library-setup`, design D5): settings a card
/// takes when dropped from the library. None of it is an edit of the scene, so nothing here
/// registers undo or reaches `onCommit`, and a read-only scene's library may be set up too.
extension SceneEditor {
    /// Selects the library card `name`, which leaves no card on the canvas selected.
    public func chooseLibraryCard(_ name: String) {
        clearSelection()
        libraryCard = name
    }

    /// Sets the setting `key` of the library card `name`'s setup to `value`.
    public func setSetup(_ key: String, to value: JSONValue, on name: String) {
        setups[name, default: [:]][key] = value
    }

    /// Leaves the setting `key` out of the library card `name`'s setup, so it takes its default.
    public func unsetSetup(_ key: String, on name: String) {
        editSetup(key, on: name) { _ in nil }
    }

    /// Changes the setting `key` of the library card `name`'s setup to `transform` of its value, a
    /// nil result leaving it out. A setup left with no settings is no setup.
    public func editSetup(
        _ key: String, on name: String, _ transform: (JSONValue?) -> JSONValue?
    ) {
        var setup = setups[name] ?? [:]
        setup[key] = transform(setup[key])
        setups[name] = setup.isEmpty ? nil : setup
    }

    /// Returns every setting of the library card `name` to its default.
    public func clearSetup(_ name: String) {
        setups[name] = nil
    }
}
