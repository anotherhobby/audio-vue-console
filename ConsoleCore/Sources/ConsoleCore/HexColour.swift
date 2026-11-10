/// A colour setting's `#rrggbb` as sRGB components from 0 to 1, and back as `#RRGGBB`, so a colour
/// read, shown in the system colour panel and written back unchanged keeps its hex (`card-settings`,
/// design D8).
public struct HexColour: Sendable, Equatable {
    public let red: Double
    public let green: Double
    public let blue: Double

    /// Components in sRGB, each clamped to 0 to 1.
    public init(red: Double, green: Double, blue: Double) {
        self.red = Self.clamped(red)
        self.green = Self.clamped(green)
        self.blue = Self.clamped(blue)
    }

    /// `text` read as `#rrggbb` in either case, or nil for anything else.
    public init?(_ text: String) {
        guard text.count == Self.length, text.first == "#" else { return nil }
        let digits = text.dropFirst()
        guard digits.allSatisfy(\.isHexDigit), let value = Int(digits, radix: Self.radix)
        else { return nil }
        self.init(
            red: Self.component(value >> Self.redShift),
            green: Self.component(value >> Self.greenShift), blue: Self.component(value))
    }

    /// `#RRGGBB`, each component rounded to the nearest of its 255 steps.
    public var hex: String {
        "#" + [red, green, blue].map(Self.byte).joined()
    }

    private static let length = 7
    private static let radix = 16
    private static let maximum = 255
    private static let redShift = 16
    private static let greenShift = 8

    private static func component(_ shifted: Int) -> Double {
        Double(shifted & maximum) / Double(maximum)
    }

    private static func clamped(_ component: Double) -> Double {
        min(max(component, 0), 1)
    }

    /// One component as two upper-case hex digits.
    private static func byte(_ component: Double) -> String {
        let text = String(
            Int((component * Double(maximum)).rounded()), radix: radix, uppercase: true)
        return text.count == 1 ? "0" + text : text
    }
}
