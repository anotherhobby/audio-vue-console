import SwiftUI

/// Sizes for the Scenes page: the gallery, the card library and the editor's columns. The canvas's
/// own are `CanvasMetrics`, and the window's `PanelMetrics`.
enum SceneMetrics {
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
    static let canvasMinWidth: CGFloat = 420
    static let inspectorMinWidth: CGFloat = 220
    static let inspectorIdealWidth: CGFloat = 260
    static let inspectorMaxWidth: CGFloat = 340
    static let canvasPadding: CGFloat = 24
    static let renameSheetWidth: CGFloat = 320
    static let nameFieldWidth: CGFloat = 320
    /// The space before Reset in the editor's toolbar: wider than a named button.
    static let toolbarGap: CGFloat = 80
    static let unsavedDotSize: CGFloat = 7
}
