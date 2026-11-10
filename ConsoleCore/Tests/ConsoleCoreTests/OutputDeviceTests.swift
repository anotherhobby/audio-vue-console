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

/// `mac-output` design D2: the formats a device offers at a rate, deepest first.
struct OutputDeviceFormatTests {
    private static let int16 = OutputFormat(bits: 16, isFloat: false)
    private static let int24 = OutputFormat(bits: 24, isFloat: false)
    private static let int32 = OutputFormat(bits: 32, isFloat: false)
    private static let float32 = OutputFormat(bits: 32, isFloat: true)

    /// 16 and 24 bits at every rate, 32-bit integer only up to 96 kHz, and 32-bit float at 48 kHz.
    private static let device = OutputDevice(
        uid: "d10s", name: "D10s ", availableRates: [44_100...192_000],
        formats: [
            OutputFormatRange(format: int16, rates: 44_100...192_000),
            OutputFormatRange(format: int24, rates: 44_100...192_000),
            OutputFormatRange(format: int32, rates: 44_100...96_000),
            OutputFormatRange(format: float32, rates: 48_000...48_000),
            OutputFormatRange(format: int24, rates: 44_100...44_100),
        ])

    @Test func theFormatsAtARateDeepestFirstEachOnce() {
        #expect(
            Self.device.formats(at: 48_000) == [Self.int32, Self.float32, Self.int24, Self.int16])
    }

    @Test func aFormatOfferedOnlyAtSomeRatesIsLeftOutElsewhere() {
        #expect(Self.device.formats(at: 192_000) == [Self.int24, Self.int16])
    }

    @Test func theDeepestIntegerAtARate() {
        #expect(Self.device.deepestInteger(at: 96_000) == 32)
        #expect(Self.device.deepestInteger(at: 192_000) == 24)
    }

    @Test func aDeviceWithOnlyFloatHasNoDeepestInteger() {
        let float = OutputDevice(
            uid: "f", name: "F",
            formats: [OutputFormatRange(format: Self.float32, rates: 48_000...48_000)])
        #expect(float.deepestInteger(at: 48_000) == nil)
        #expect(float.formats(at: 48_000) == [Self.float32])
    }
}
