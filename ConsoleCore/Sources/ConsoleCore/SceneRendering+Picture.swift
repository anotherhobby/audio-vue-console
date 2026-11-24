import CoreGraphics

extension SceneRendering {
    /// Why Export Image cannot save the scene as drawn, or nil where it can (`track-render`,
    /// "Export Image saves the scene as the canvas draws it").
    public var pictureUnavailable: String? {
        guard status == .drawn, backdrop != nil else { return "The scene isn't drawn yet" }
        guard boxedCards.isEmpty else {
            return "Some cards are drawn as boxes, their code differing"
        }
        return nil
    }

    /// The scene as the canvas draws it: the backdrop and every plate, stacked at 16 bits a
    /// component, at the panel's display size. Nil while `pictureUnavailable` says why. Kept at 16
    /// bits, the glass blended over the backdrop keeps its fractions, which 8 bits round into bands
    /// (maintainer, 2026-11-23).
    public var picture: CGImage? {
        guard pictureUnavailable == nil, let backdrop else { return nil }
        return Thumbnail.flatten(
            layers: [backdrop] + orderedPlates.map(\.layer), display: context.display,
            width: context.display.width, bits: Thumbnail.deepBitsPerComponent)
    }
}
