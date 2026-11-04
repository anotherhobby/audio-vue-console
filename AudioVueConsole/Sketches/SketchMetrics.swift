import SwiftUI

/// Sizes and colours for the UI sketches.
enum SketchMetrics {
    static let windowMinWidth: CGFloat = 900
    static let windowMinHeight: CGFloat = 560
    static let windowDefaultWidth: CGFloat = 1280
    static let windowDefaultHeight: CGFloat = 760

    static let sidebarMinWidth: CGFloat = 200
    static let sidebarIdealWidth: CGFloat = 220
    static let pickerPadding: CGFloat = 10
    static let statusDotSize: CGFloat = 8

    static let libraryMinWidth: CGFloat = 180
    static let libraryIdealWidth: CGFloat = 230
    static let libraryMaxWidth: CGFloat = 320
    static let cardPreviewHeight: CGFloat = 110
    static let galleryTileWidth: CGFloat = 260
    static let galleryThumbnailHeight: CGFloat = 120
    static let gallerySpacing: CGFloat = 20
    static let stripSpacing: CGFloat = 10
    static let stripPadding: CGFloat = 12
    static let tilePadding: CGFloat = 6
    static let tileCornerRadius: CGFloat = 8
    static let selectedOpacity: Double = 0.35
    static let canvasMinWidth: CGFloat = 420
    static let inspectorMinWidth: CGFloat = 220
    static let inspectorIdealWidth: CGFloat = 260
    static let inspectorMaxWidth: CGFloat = 340
    static let defaultBlur: Double = 24
    static let blurRange: ClosedRange<Double> = 0...48
    static let defaultGlassOpacity: Double = 0.6
    static let unitRange: ClosedRange<Double> = 0...1

    static let canvasPadding: CGFloat = 24
    static let mismatchOpacity: Double = 0.45
}
