import CoreGraphics

/// A scene's layers stacked into one image (`scene-gallery`, "A thumbnail is the scene as the helper
/// draws it"): each over the ones before it, premultiplied, as audio-vue stacks them, scaled to the
/// width asked for. At the display's own width it is the stacked scene itself.
public enum Thumbnail {
    /// `layers`, in stacking order, placed on a `display` and drawn `width` pixels wide, or nil
    /// where no image can be made.
    public static func flatten(layers: [RenderedLayer], display: PixelSize, width: Int) -> CGImage?
    {
        guard display.width > 0, display.height > 0, width > 0 else { return nil }
        let scale = Double(width) / Double(display.width)
        let height = Int((Double(display.height) * scale).rounded())
        guard height > 0, let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent,
                bytesPerRow: 0, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.interpolationQuality = .high
        for layer in layers {
            // Core Graphics counts rows from the bottom; a layer's rect counts from the top.
            let rect = CGRect(
                x: layer.rect.minX * scale,
                y: (Double(display.height) - layer.rect.maxY) * scale,
                width: layer.rect.width * scale, height: layer.rect.height * scale)
            context.draw(layer.image, in: rect)
        }
        return context.makeImage()
    }

    private static let bitsPerComponent = 8
}
