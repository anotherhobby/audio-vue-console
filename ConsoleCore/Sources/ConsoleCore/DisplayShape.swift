/// A display's or a grid's shape, its width over its height, by which a scene is tied to a panel
/// (`product.md`: scenes are tied to a display shape).
public struct DisplayShape: Sendable, Hashable, CustomStringConvertible {
    public let width: Int
    public let height: Int

    /// How far apart two aspects may be and still be one shape.
    static let tolerance = 0.01

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    public var aspect: Double { Double(width) / Double(height) }

    public func matches(_ other: DisplayShape) -> Bool {
        abs(aspect - other.aspect) < Self.tolerance
    }

    /// The shape in lowest terms: `1920 x 720` is `8:3`.
    public var description: String {
        let divisor = Self.gcd(width, height)
        guard divisor > 0 else { return "?" }
        return "\(width / divisor):\(height / divisor)"
    }

    private static func gcd(_ lhs: Int, _ rhs: Int) -> Int {
        rhs == 0 ? lhs : gcd(rhs, lhs % rhs)
    }
}
