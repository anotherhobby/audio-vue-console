import Testing

@testable import ConsoleCore

/// `scene-gallery`, "My scenes, then the built-ins, then other shapes".
struct GallerySectionsTests {
    private struct Scene: GalleryEntry {
        let name: String
        let builtIn: Bool
        let grid: CellSize?
    }

    private static let wide = CellSize(cols: 96, rows: 36)
    private static let sixteenByNine = CellSize(cols: 64, rows: 36)
    private static let eightByThree = DisplayShape(width: 1920, height: 720)

    /// In the host's order: the built-in RTA and Default (no grid), then the stored "My RTA" and
    /// "Wide".
    private let listing = [
        Scene(name: "RTA", builtIn: true, grid: wide),
        Scene(name: "Default", builtIn: true, grid: nil),
        Scene(name: "My RTA", builtIn: false, grid: wide),
        Scene(name: "Wide", builtIn: false, grid: sixteenByNine),
    ]

    private func sections(_ scenes: [Scene], panel: DisplayShape) -> GallerySections<Scene> {
        GallerySections(scenes, panel: panel, defaultGrid: Self.sixteenByNine)
    }

    private static func names(_ scenes: [Scene]) -> [String] { scenes.map(\.name) }

    @Test func anEightByThreePanel() {
        let sections = sections(listing, panel: Self.eightByThree)
        #expect(Self.names(sections.mine) == ["My RTA"])
        #expect(Self.names(sections.builtIn) == ["RTA"])
        #expect(Self.names(sections.otherShapes) == ["Default", "Wide"])
    }

    @Test func aSixteenByNinePanel() {
        let sections = sections(listing, panel: DisplayShape(width: 1920, height: 1080))
        #expect(Self.names(sections.mine) == ["Wide"])
        #expect(Self.names(sections.builtIn) == ["Default"])
        #expect(Self.names(sections.otherShapes) == ["RTA", "My RTA"])
    }

    @Test func aSceneThatCannotBeLaidOutTakesTheDefaultGrid() {
        let broken = Scene(name: "Broken", builtIn: false, grid: nil)
        let sections = GallerySections(
            [broken], panel: Self.eightByThree, defaultGrid: Self.wide)
        #expect(Self.names(sections.mine) == ["Broken"])
    }

    @Test func aCopyComesAfterTheStoredScenes() {
        let copy = Scene(name: "RTA copy", builtIn: false, grid: Self.wide)
        let sections = sections(listing + [copy], panel: Self.eightByThree)
        #expect(Self.names(sections.mine) == ["My RTA", "RTA copy"])
    }

    @Test func everySceneFits() {
        let sections = sections(listing.filter { $0.grid == Self.wide }, panel: Self.eightByThree)
        #expect(sections.otherShapes.isEmpty)
    }
}
