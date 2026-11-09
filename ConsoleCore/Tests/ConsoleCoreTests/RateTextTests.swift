import Testing

@testable import ConsoleCore

/// Design D9: every page words a rate one way.
struct RateTextTests {
    @Test(arguments: [(44_100, "44.1 kHz"), (96_000, "96 kHz"), (88_200, "88.2 kHz")])
    func aRateInKilohertz(hertz: Int, text: String) {
        #expect(RateText.text(hertz) == text)
    }
}
