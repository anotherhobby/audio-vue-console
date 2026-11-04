import SwiftUI

/// Sizes and colours for the scene canvas and what draws scenes like it. Plates are coloured by
/// card kind until the host renders each card's tile.
enum CanvasMetrics {
    static let palette: [Color] = [.blue, .purple, .pink, .orange, .teal, .indigo, .mint, .cyan]
    static let backdrop = LinearGradient(
        colors: [.indigo, .black, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)

    static let plateFillOpacity: Double = 0.55
    static let plateCornerRadius: CGFloat = 6
    static let plateInset: CGFloat = 1.5
    static let thumbnailCornerRadius: CGFloat = 2
    static let thumbnailInset: CGFloat = 0.5
    static let memberStrokeOpacity: Double = 0.5
    static let labelPadding: CGFloat = 4

    static let canvasPadding: CGFloat = 24
    static let bezelWidth: CGFloat = 10
    static let bezelCornerRadius: CGFloat = 14
    static let selectionLineWidth: CGFloat = 2
    static let marqueeFillOpacity: Double = 0.15

    /// A resize handle as drawn, and the larger square that takes its clicks.
    static let handleSize: CGFloat = 8
    static let handleHitSize: CGFloat = 16
    /// Below three hit areas across, 48 pt, a card shows only its lower-right handle (`design.md`).
    static let crowdedCardSize: CGFloat = 48

    /// How far a press must travel before it is a drag rather than a click.
    static let dragMinimumDistance: CGFloat = 2
    static let marqueeMinimumDistance: CGFloat = 3

    /// An arrow key's nudge, and a shifted one's, in cells.
    static let nudge = 1
    static let shiftedNudge = 4

    /// A steady colour per card kind, so the same card looks the same everywhere.
    static func color(for kind: String) -> Color {
        let sum = kind.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[sum % palette.count]
    }
}
