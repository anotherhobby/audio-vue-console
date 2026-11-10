import CoreAudio
import Dispatch

/// Core Audio listeners on one device's rate, its first output stream's format, and the list of
/// devices, calling `changed` from a queue of their own until stopped (`mac-output` design D3).
final class OutputWatch: Sendable {
    private struct Registration: Sendable {
        let object: AudioObjectID
        let address: AudioObjectPropertyAddress
    }

    private static let queue = DispatchQueue(label: "ConsoleCore.OutputWatch")
    private let registrations: [Registration]
    /// A listener block that may be called from any queue.
    private typealias Listener =
        @Sendable @convention(block) (UInt32, UnsafePointer<AudioObjectPropertyAddress>) -> Void

    /// The one block every listener was added with, so the same block removes each.
    private let block: Listener

    init(device: CoreAudioObject?, changed: @escaping @Sendable () -> Void) {
        let block: Listener = { _, _ in changed() }
        self.block = block
        registrations = Self.watched(device).compactMap { object, selector in
            var address = CoreAudioObject.address(selector)
            let status = AudioObjectAddPropertyListenerBlock(object.id, &address, Self.queue, block)
            return status == noErr ? Registration(object: object.id, address: address) : nil
        }
    }

    /// Removes every listener.
    func stop() {
        for registration in registrations {
            var address = registration.address
            AudioObjectRemovePropertyListenerBlock(
                registration.object, &address, Self.queue, block)
        }
    }

    private static func watched(_ device: CoreAudioObject?)
        -> [(CoreAudioObject, AudioObjectPropertySelector)]
    {
        var watched = [(CoreAudioObject.system, kAudioHardwarePropertyDevices)]
        guard let device else { return watched }
        watched.append((device, kAudioDevicePropertyNominalSampleRate))
        if let stream = device.outputStreams.first {
            watched.append((stream, kAudioStreamPropertyPhysicalFormat))
        }
        return watched
    }
}
