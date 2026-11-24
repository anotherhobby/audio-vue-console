import ConsoleCore
import SwiftUI

/// The light grid across the canvas pane, its cells the panel's cells as drawn and lined up with
/// them, so parked cards sit on it. The bezelled panel is drawn over it, so no line falls on the
/// panel (`scene-canvas`, "The pane around the panel is a grid of the panel's cells").
struct PaneGrid: View {
    /// The panel's grid, placed in the pane.
    let geometry: GridGeometry
    @AppStorage(PaneGridColour.key) private var stored: String?

    var body: some View {
        Canvas { context, size in
            let (columns, rows) = geometry.lines(in: size)
            var path = Path()
            for x in columns {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in rows {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(
                path, with: .color(PaneGridColour.colour(stored)),
                lineWidth: CanvasMetrics.paneGridLineWidth)
        }
        .opacity(CanvasMetrics.paneGridOpacity)
        .allowsHitTesting(false)
    }
}

/// The colour the pane's grid is drawn in, chosen with the editor's Grid button and kept for every
/// scene and across launches as `#RRGGBB` (`scene-canvas`, "The Grid button picks the grid's
/// colour").
enum PaneGridColour {
    static let key = "paneGridColour"

    /// The stored colour, or the secondary label colour where none is stored.
    static func colour(_ stored: String?) -> Color {
        guard let hex = stored.flatMap({ HexColour($0) }) else { return .secondary }
        return Color(.sRGB, red: hex.red, green: hex.green, blue: hex.blue)
    }
}

/// The Grid button's popover: a colour for the pane's grid, and the way back to the default. A
/// plain stack, not a `Form`: a grouped form is a table view, and one in this window's toolbar
/// crashed the app (`pitfalls.md`, "A SwiftUI List crashed inside the scene editor").
struct PaneGridPicker: View {
    @AppStorage(PaneGridColour.key) private var stored: String?

    var body: some View {
        VStack(alignment: .leading, spacing: SceneMetrics.stripSpacing) {
            HStack {
                Text("Grid Colour")
                ColourWell(hex: stored) { value in
                    if case .string(let hex) = value { stored = hex }
                }
                .frame(width: SceneMetrics.gridWellWidth, height: SceneMetrics.gridWellHeight)
            }
            Button("Use Default") { stored = nil }
                .disabled(stored == nil)
        }
        .padding()
        .fixedSize()
    }
}
