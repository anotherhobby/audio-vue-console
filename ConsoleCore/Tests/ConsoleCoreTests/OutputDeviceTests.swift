import Testing

@testable import ConsoleCore

/// Design D6: an output offers a rate where one of its CoreAudio ranges holds it.
struct OutputDeviceTests {
    private static let device = OutputDevice(
        uid: "d10s", name: "D10s ", availableRates: [44_100...48_000, 96_000...96_000])

    @Test(arguments: [44_100, 48_000, 96_000])
    func aRateInARangeIsOffered(hertz: Int) {
        #expect(Self.device.offers(hertz))
    }

    @Test(arguments: [88_200, 192_000])
    func aRateOutsideEveryRangeIsNot(hertz: Int) {
        #expect(!Self.device.offers(hertz))
    }

    @Test func aDeviceWithNoRangesOffersNothing() {
        #expect(!OutputDevice(uid: "x", name: "X").offers(48_000))
    }
}
