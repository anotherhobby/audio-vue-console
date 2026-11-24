import SwiftUI

/// Sizes for the Scenes page: the gallery, the card library and the editor's columns. The canvas's
/// own are `CanvasMetrics`, and the window's `PanelMetrics`.
enum SceneMetrics {
    static let libraryMinWidth: CGFloat = 180
    /// The Grid button's colour well, fixed so its popover's layout settles in one pass.
    static let gridWellWidth: CGFloat = 44
    static let gridWellHeight: CGFloat = 24
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
    /// The inspector's one width, its widest, whatever it shows.
    static let inspectorWidth: CGFloat = 340
    static let canvasPadding: CGFloat = 24
    static let renameSheetWidth: CGFloat = 320
    static let nameFieldWidth: CGFloat = 320
    /// The space before Reset in the editor's toolbar: wider than a named button.
    static let toolbarGap: CGFloat = 80
    static let unsavedDotSize: CGFloat = 7
    /// The space between a setting's control, help and footer in the inspector.
    static let settingSpacing: CGFloat = 4
    static let numberFieldWidth: CGFloat = 64
    /// Every colour well's size, fixed so a form row's layout settles (`ColourWell`).
    static let colourWellWidth: CGFloat = 64
    static let colourWellHeight: CGFloat = 24
    static let amountSliderWidth: CGFloat = 120
    static let amountTextWidth: CGFloat = 40
    /// How long the colour panel's colour rests before it is written as one step (`card-settings`,
    /// design D8).
    static let colourSettleSeconds: Double = 0.5
    /// A swatch's chip in a menu of swatches.
    static let swatchChipSide: CGFloat = 12
    static let swatchChipRadius: CGFloat = 2
    /// A palette colour's cell: its well and its name beneath.
    static let swatchCellWidth: CGFloat = 64
    /// A backdrop image's thumbnail in the picker.
    static let imageThumbnailWidth: CGFloat = 140
    static let imageThumbnailHeight: CGFloat = 80
    static let imagePickerWidth: CGFloat = 520
    static let imagePickerHeight: CGFloat = 420
    /// A thumbnail's box while its image is fetched.
    static let placeholderOpacity: Double = 0.15
    /// The Render with Track sheet, its picture at the panel's aspect within it.
    static let trackSheetWidth: CGFloat = 720
    static let trackPictureMinHeight: CGFloat = 200
    static let secondsFieldWidth: CGFloat = 72
}
