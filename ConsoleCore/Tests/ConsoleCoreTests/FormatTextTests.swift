import Testing

@testable import ConsoleCore

/// `mac-output` design D1 and D2: formats in the section's words.
struct FormatTextTests {
    @Test func theHostsCaptureFormats() {
        #expect(FormatText.capture("S16_LE") == "16-bit")
        #expect(FormatText.capture("S32_LE") == "24-bit in 32-bit")
    }

    @Test func anUnknownCaptureFormatIsItsOwnName() {
        #expect(FormatText.capture("S8") == "S8")
    }

    @Test func onlySixteenBitCaptureIsShallow() {
        #expect(FormatText.isShallowCapture("S16_LE"))
        #expect(!FormatText.isShallowCapture("S32_LE"))
    }

    @Test func outputFormatsAsAudioMIDISetupWordsThem() {
        #expect(FormatText.output(OutputFormat(bits: 24, isFloat: false)) == "24-bit Integer")
        #expect(FormatText.output(OutputFormat(bits: 32, isFloat: true)) == "32-bit Float")
    }

    @Test func anOutputUnderTwentyFourBitsIsShallow() {
        #expect(OutputFormat(bits: 16, isFloat: false).isShallow)
        #expect(!OutputFormat(bits: 24, isFloat: false).isShallow)
    }
}
