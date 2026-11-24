import Foundation

/// A sample rate in the words every page shows it in: `44.1 kHz`, `96 kHz`.
public enum RateText {
    private static let hertzPerKilohertz = 1000.0

    /// `hertz` in kilohertz, with a tenth or a hundredth only where it has one: `22.05 kHz`.
    public static func text(_ hertz: Int) -> String {
        let kilohertz = Double(hertz) / hertzPerKilohertz
        return "\(kilohertz.formatted(.number.precision(.fractionLength(0...2)))) kHz"
    }
}
