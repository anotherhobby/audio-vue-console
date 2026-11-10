import Testing

@testable import ConsoleCore

/// `mac-output` design D5 and D6, over an output offering 44.1 to 96 kHz.
struct RateSyncTests {
    private static let d10s = OutputDevice(
        uid: "d10s", name: "D10s ", availableRates: [44_100...96_000])
    private static let at48 = OutputCurrent(rate: 48_000, format: nil)
    private static let at96 = OutputCurrent(rate: 96_000, format: nil)

    // MARK: RateMatch

    @Test func theSameRate() {
        #expect(RateMatch.of(output: Self.at96, device: Self.d10s, capture: 96_000) == .same)
    }

    /// `mac-output`, "Different rates".
    @Test func differentRates() {
        #expect(
            RateMatch.of(output: Self.at48, device: Self.d10s, capture: 96_000)
                == .different(output: 48_000, capture: 96_000))
    }

    /// `mac-output`, "A rate the output cannot play".
    @Test func aCaptureRateTheOutputCannotPlay() {
        #expect(
            RateMatch.of(output: Self.at96, device: Self.d10s, capture: 192_000)
                == .cannotPlay(capture: 192_000))
    }

    @Test func nothingToMatchWithoutAnOutputOrACaptureRate() {
        #expect(RateMatch.of(output: nil, device: Self.d10s, capture: 96_000) == .noOutput)
        #expect(RateMatch.of(output: Self.at96, device: nil, capture: 96_000) == .noOutput)
        #expect(RateMatch.of(output: Self.at96, device: Self.d10s, capture: nil) == .noOutput)
    }

    // MARK: RateSync

    /// `mac-output`, "A new capture rate".
    @Test func aStoredCaptureRateIsFollowedWhileSynchronized() {
        let rate = RateSync.afterCapture(
            stored: 96_000, synchronized: true, output: Self.at48, device: Self.d10s)
        #expect(rate == 96_000)
    }

    @Test func aStoredCaptureRateIsNotFollowedWhileNot() {
        let rate = RateSync.afterCapture(
            stored: 96_000, synchronized: false, output: Self.at48, device: Self.d10s)
        #expect(rate == nil)
    }

    @Test func anOutputAlreadyAtTheRateIsNotSet() {
        let rate = RateSync.afterCapture(
            stored: 96_000, synchronized: true, output: Self.at96, device: Self.d10s)
        #expect(rate == nil)
    }

    @Test func aRateTheOutputDoesNotOfferIsNotSet() {
        let rate = RateSync.afterCapture(
            stored: 192_000, synchronized: true, output: Self.at96, device: Self.d10s)
        #expect(rate == nil)
    }

    @Test func choosingAnOutputRateSetsTheOutputWhileNotSynchronized() {
        let action = RateSync.onOutputChosen(88_200, synchronized: false, capture: 96_000)
        #expect(action == .setOutput(88_200))
    }

    /// `mac-output`, "The output rate chosen".
    @Test func choosingAnOutputRateWritesTheCaptureRateWhileSynchronized() {
        let action = RateSync.onOutputChosen(88_200, synchronized: true, capture: 96_000)
        #expect(action == .writeCapture(88_200))
    }

    /// An output put back at the capture rate needs no capture write, which would change nothing.
    @Test func choosingTheCaptureRateForTheOutputOnlySetsTheOutput() {
        let action = RateSync.onOutputChosen(96_000, synchronized: true, capture: 96_000)
        #expect(action == .setOutput(96_000))
    }

    @Test func turningSynchronizationOnSetsTheCaptureRate() {
        #expect(
            RateSync.onSynchronize(capture: 96_000, output: Self.at48, device: Self.d10s)
                == 96_000)
        #expect(
            RateSync.onSynchronize(capture: 96_000, output: Self.at96, device: Self.d10s) == nil)
        #expect(
            RateSync.onSynchronize(capture: 192_000, output: Self.at48, device: Self.d10s) == nil)
    }
}
