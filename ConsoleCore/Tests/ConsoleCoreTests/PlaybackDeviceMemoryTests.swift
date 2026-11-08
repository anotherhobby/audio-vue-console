import Foundation
import Testing

@testable import ConsoleCore

/// The output device remembered per panel, and this Mac's devices (`calibration-run`).
struct PlaybackDeviceMemoryTests {
    private static let d10s = OutputDevice(uid: "AppleUSBAudioEngine:D10s:1", name: "D10s ")
    private static let speakers = OutputDevice(uid: "BuiltInSpeakerDevice", name: "Speakers")

    private func memory() throws -> PlaybackDeviceMemory {
        let suite = "PlaybackDeviceMemoryTests.\(UUID().uuidString)"
        return PlaybackDeviceMemory(defaults: try #require(UserDefaults(suiteName: suite)))
    }

    @Test func rememberedForOnePanelAndNotAnother() throws {
        let memory = try memory()
        memory.remember(Self.d10s, for: "h1")
        #expect(memory.chosen(for: "h1", among: [Self.speakers, Self.d10s]) == Self.d10s)
        #expect(memory.chosen(for: "h2", among: [Self.speakers, Self.d10s]) == nil)
    }

    @Test func aRememberedDeviceNotListedIsNotChosen() throws {
        let memory = try memory()
        memory.remember(Self.d10s, for: "h1")
        #expect(memory.chosen(for: "h1", among: [Self.speakers]) == nil)
    }

    @Test func thisMacListsAnOutputDevice() {
        let devices = CoreAudioOutputDevices().list()
        #expect(!devices.isEmpty)
        #expect(devices.allSatisfy { !$0.uid.isEmpty && !$0.name.isEmpty })
    }
}
