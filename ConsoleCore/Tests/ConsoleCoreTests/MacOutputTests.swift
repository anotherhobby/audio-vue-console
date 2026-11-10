import Foundation
import Testing

@testable import ConsoleCore

/// This Mac's output for a panel (`mac-output`, design D4), over a scripted Core Audio.
@MainActor struct MacOutputTests {
    private static let int16 = OutputFormat(bits: 16, isFloat: false)
    private static let int24 = OutputFormat(bits: 24, isFloat: false)
    private static let d10s = OutputDevice(
        uid: "d10s", name: "D10s ", availableRates: [44_100...192_000],
        formats: [
            OutputFormatRange(format: int16, rates: 44_100...192_000),
            OutputFormatRange(format: int24, rates: 44_100...192_000),
        ])
    private static let speakers = OutputDevice(
        uid: "speakers", name: "Speakers", availableRates: [48_000...48_000])

    private static func control() -> ScriptedOutputControl {
        ScriptedOutputControl(
            [speakers, d10s],
            current: [
                "d10s": OutputCurrent(rate: 96_000, format: int16),
                "speakers": OutputCurrent(rate: 48_000, format: nil),
            ])
    }

    private func memory() throws -> PlaybackDeviceMemory {
        let suite = "MacOutputTests.\(UUID().uuidString)"
        return PlaybackDeviceMemory(defaults: try #require(UserDefaults(suiteName: suite)))
    }

    /// `mac-output`, "Chosen before".
    @Test func theRememberedDeviceIsChosenWithItsRateAndFormat() throws {
        let memory = try memory()
        memory.remember(Self.d10s, for: "h1")
        let output = MacOutput(hostID: "h1", control: Self.control(), memory: memory)
        output.load()
        #expect(output.device == Self.d10s)
        #expect(output.current == OutputCurrent(rate: 96_000, format: Self.int16))
        #expect(output.formatChoices == [Self.int24, Self.int16])
    }

    /// `mac-output`, "The device is gone".
    @Test func aRememberedDeviceNoLongerListedLeavesNoneChosen() throws {
        let memory = try memory()
        memory.remember(OutputDevice(uid: "gone", name: "Gone"), for: "h1")
        let output = MacOutput(hostID: "h1", control: Self.control(), memory: memory)
        output.load()
        #expect(output.device == nil && output.current == nil)
        #expect(output.formatChoices.isEmpty)
        #expect(output.devices.count == 2)
    }

    @Test func choosingADeviceRemembersIt() throws {
        let memory = try memory()
        let output = MacOutput(hostID: "h1", control: Self.control(), memory: memory)
        output.load()
        output.choose(Self.d10s)
        #expect(output.device == Self.d10s)
        #expect(memory.chosen(for: "h1", among: [Self.d10s]) == Self.d10s)
    }

    /// `mac-output`, "Changed in Audio MIDI Setup".
    @Test func aChangeMadeElsewhereIsReadAgain() async throws {
        let memory = try memory()
        memory.remember(Self.d10s, for: "h1")
        let control = Self.control()
        let output = MacOutput(hostID: "h1", control: control, memory: memory)
        output.load()
        let following = Task { await output.follow() }
        defer { following.cancel() }
        await Task.yield()
        control.change("d10s", to: OutputCurrent(rate: 48_000, format: Self.int16))
        for _ in 0..<100 where output.current?.rate != 48_000 { await Task.yield() }
        #expect(output.current?.rate == 48_000)
    }

    /// `mac-output`, "A new format".
    @Test func aFormatIsSet() throws {
        let memory = try memory()
        memory.remember(Self.d10s, for: "h1")
        let control = Self.control()
        let output = MacOutput(hostID: "h1", control: control, memory: memory)
        output.load()
        output.setFormat(Self.int24)
        #expect(control.formatSets == [Self.int24])
        #expect(output.current?.format == Self.int24)
        #expect(output.refusal == nil)
    }

    /// `mac-output`, "Refused".
    @Test func aRefusedSetKeepsItsReasonAndTheDevicesValues() throws {
        let memory = try memory()
        memory.remember(Self.d10s, for: "h1")
        let control = Self.control()
        control.refuse(with: .refused(-50))
        let output = MacOutput(hostID: "h1", control: control, memory: memory)
        output.load()
        output.setRate(48_000)
        #expect(output.refusal == .refused(-50))
        #expect(output.current?.rate == 96_000)
        control.refuse(with: nil)
        output.setRate(48_000)
        #expect(output.refusal == nil && output.current?.rate == 48_000)
    }

    /// `mac-output`, "A panel not seen before" and "Turned off".
    @Test func synchronizationIsOnByDefaultAndRemembered() throws {
        let memory = try memory()
        let output = MacOutput(hostID: "h1", control: Self.control(), memory: memory)
        #expect(output.isSynchronized)
        output.setSynchronized(false)
        #expect(!output.isSynchronized)
        #expect(!MacOutput(hostID: "h1", control: Self.control(), memory: memory).isSynchronized)
    }
}
