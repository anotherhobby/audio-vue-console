import Testing

@testable import ConsoleCore

/// `scene-gallery`, "My scenes, then the built-ins".
struct GallerySectionsTests {
    private struct Scene: GalleryEntry {
        let name: String
        let builtIn: Bool
    }

    /// In the host's order: the built-in RTA and Default, then the stored "My RTA" and "Wide".
    private let listing = [
        Scene(name: "RTA", builtIn: true),
        Scene(name: "Default", builtIn: true),
        Scene(name: "My RTA", builtIn: false),
        Scene(name: "Wide", builtIn: false),
    ]

    private static func names(_ scenes: [Scene]) -> [String] { scenes.map(\.name) }

    @Test func mineThenTheBuiltIns() {
        let sections = GallerySections(listing)
        #expect(Self.names(sections.mine) == ["My RTA", "Wide"])
        #expect(Self.names(sections.builtIn) == ["RTA", "Default"])
    }

    @Test func aCopyComesAfterTheStoredScenes() {
        let sections = GallerySections(listing + [Scene(name: "RTA copy", builtIn: false)])
        #expect(Self.names(sections.mine) == ["My RTA", "Wide", "RTA copy"])
    }

    @Test func noScenesOfTheUsers() {
        let sections = GallerySections(listing.filter(\.builtIn))
        #expect(sections.mine.isEmpty)
    }
}
