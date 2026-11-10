import Foundation
import Testing

@testable import ConsoleCore

/// `mac-output` design D3 on this Mac's real output: reads the device named by
/// `AUDIO_VUE_LIVE_OUTPUT`, sets another rate and another format, follows each change, and puts
/// both back. Skipped without the variable. It changes the device for a moment, so mute what it
/// feeds.
///
///     AUDIO_VUE_LIVE_OUTPUT=D10s xcrun swift test --filter OutputControlLiveTests
@Suite(.enabled(if: LiveOutput.name != nil), .serialized)
struct OutputControlLiveTests {
    private static let rates = [44_100, 48_000, 88_200, 96_000, 192_000]
    private static let settle = Duration.seconds(3)

    private let control = CoreAudioOutputControl()

    private func device() throws -> OutputDevice {
        let name = try #require(LiveOutput.name)
        return try #require(control.list().first { $0.name.localizedCaseInsensitiveContains(name) })
    }

    private static let poll = Duration.milliseconds(100)

    /// Polls until the device reads `expected`, or the settle runs out.
    private func reads(_ uid: String, _ expected: (OutputCurrent) -> Bool) async throws -> Bool {
        let deadline = ContinuousClock.now + Self.settle
        while ContinuousClock.now < deadline {
            if let now = control.current(uid: uid), expected(now) { return true }
            try await Task.sleep(for: Self.poll)
        }
        return false
    }

    /// Runs `change` while following the device, returning whether a change was heard.
    private func heard(_ uid: String, _ change: () async throws -> Void) async throws -> Bool {
        let changes = control.changes(uid: uid)
        let listening = Task { await changes.contains { _ in true } }
        try await change()
        try await Task.sleep(for: Self.poll)
        listening.cancel()
        return await listening.value
    }

    @Test func aRateIsSetFollowedAndPutBack() async throws {
        let device = try device()
        let before = try #require(control.current(uid: device.uid))
        let other = try #require(Self.rates.first { $0 != before.rate && device.offers($0) })
        let wasHeard = try await heard(device.uid) {
            try control.setRate(uid: device.uid, hz: other)
            #expect(try await reads(device.uid) { $0.rate == other })
        }
        #expect(wasHeard)
        try control.setRate(uid: device.uid, hz: before.rate)
        #expect(try await reads(device.uid) { $0.rate == before.rate })
    }

    @Test func aFormatIsSetFollowedAndPutBack() async throws {
        let device = try device()
        let before = try #require(control.current(uid: device.uid))
        let format = try #require(before.format)
        let other = try #require(device.formats(at: before.rate).first { $0 != format })
        let wasHeard = try await heard(device.uid) {
            try control.setFormat(uid: device.uid, other)
            #expect(try await reads(device.uid) { $0.format == other })
        }
        #expect(wasHeard)
        try control.setFormat(uid: device.uid, format)
        #expect(try await reads(device.uid) { $0.format == format })
    }
}

/// The output the run asked for, by the environment.
private enum LiveOutput {
    static let name = ProcessInfo.processInfo.environment["AUDIO_VUE_LIVE_OUTPUT"]
}
