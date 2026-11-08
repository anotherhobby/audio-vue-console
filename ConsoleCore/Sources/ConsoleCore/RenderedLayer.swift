import CoreGraphics
import Foundation

/// One layer the helper drew: the backdrop, or a plate with its cards, at its rect on the display,
/// as 8-bit premultiplied RGBA in sRGB (design D4; audio-vue `scene-render`).
public struct RenderedLayer: Sendable {
    public enum Kind: String, Sendable {
        case backdrop
        case plate
    }

    public let kind: Kind
    /// The cards the layer holds, by the ids of the layout the request was made from.
    public let cardIDs: [UUID]
    /// Where the layer sits, in display pixels from the top left.
    public let rect: CGRect
    /// The cards in it that cannot show their reading at the size drawn, by name.
    public let unfit: [String]
    public let image: CGImage

    public init(kind: Kind, cardIDs: [UUID], rect: CGRect, unfit: [String], image: CGImage) {
        self.kind = kind
        self.cardIDs = cardIDs
        self.rect = rect
        self.unfit = unfit
        self.image = image
    }

    /// The layers of `answer`, its placements read as the cards `cardIDs` lists in placement order.
    static func layers(of answer: HelperAnswer, cardIDs: [UUID]) throws(RenderFailure)
        -> [RenderedLayer]
    {
        var offset = answer.payload.startIndex
        var layers: [RenderedLayer] = []
        for header in answer.header["layers"]?.arrayValue ?? [] {
            guard let count = header["bytes"]?.intValue,
                offset + count <= answer.payload.endIndex
            else { throw .ended }
            let bytes = answer.payload[offset..<(offset + count)]
            offset += count
            layers.append(try layer(header, bytes: Data(bytes), cardIDs: cardIDs))
        }
        return layers
    }

    private static func layer(_ header: JSONValue, bytes: Data, cardIDs: [UUID])
        throws(RenderFailure) -> RenderedLayer
    {
        guard let kind = header["kind"]?.stringValue.flatMap(Kind.init(rawValue:)),
            let rect = Self.rect(header["rect"]),
            let image = Self.image(bytes, width: Int(rect.width), height: Int(rect.height))
        else { throw .ended }
        let placements = header["placements"]?.arrayValue?.compactMap(\.intValue) ?? []
        guard placements.allSatisfy(cardIDs.indices.contains) else { throw .ended }
        return RenderedLayer(
            kind: kind, cardIDs: placements.map { cardIDs[$0] }, rect: rect,
            unfit: header["unfit"]?.arrayValue?.compactMap(\.stringValue) ?? [], image: image)
    }

    /// A layer's `rect`, `[x, top, width, height]` in whole pixels, or nil where it is not that.
    private static func rect(_ value: JSONValue?) -> CGRect? {
        var fields = (value?.arrayValue ?? []).makeIterator()
        guard let x = fields.next()?.intValue, let top = fields.next()?.intValue,
            let width = fields.next()?.intValue, let height = fields.next()?.intValue,
            fields.next() == nil
        else { return nil }
        return CGRect(x: x, y: top, width: width, height: height)
    }

    private static let bytesPerPixel = 4
    private static let bitsPerComponent = 8

    /// `bytes` as a `width` x `height` image, or nil where they are not that many pixels.
    static func image(_ bytes: Data, width: Int, height: Int) -> CGImage? {
        let rowBytes = width * bytesPerPixel
        guard width > 0, height > 0, bytes.count == rowBytes * height,
            let provider = CGDataProvider(data: bytes as CFData),
            let space = CGColorSpace(name: CGColorSpace.sRGB)
        else { return nil }
        return CGImage(
            width: width, height: height, bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerComponent * bytesPerPixel, bytesPerRow: rowBytes, space: space,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}
