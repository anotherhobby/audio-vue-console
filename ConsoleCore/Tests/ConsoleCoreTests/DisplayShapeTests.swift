import Testing

@testable import ConsoleCore

/// `scene-gallery`, "My scenes, then the built-ins, then other shapes".
struct DisplayShapeTests {
    private let panel = DisplayShape(width: 1920, height: 720)

    @Test func aWideGridFitsAnEightByThreePanel() {
        #expect(panel.matches(DisplayShape(width: 96, height: 36)))
    }

    @Test func aSixteenByNineGridDoesNot() {
        #expect(!panel.matches(DisplayShape(width: 64, height: 36)))
    }

    @Test func theShapesName() {
        #expect(panel.description == "8:3")
        #expect(DisplayShape(width: 64, height: 36).description == "16:9")
    }
}
