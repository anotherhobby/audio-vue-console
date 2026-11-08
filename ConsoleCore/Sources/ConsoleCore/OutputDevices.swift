import CoreAudio
import Foundation

/// An output device on this Mac: CoreAudio's unique id, which outlasts a reconnect, and its name,
/// which is what `cal-play` is given (design D2). CoreAudio may end a name with a space, as the
/// D10s's `D10s `; the name is kept as given.
public struct OutputDevice: Sendable, Hashable, Identifiable {
    public let uid: String
    public let name: String
    public var id: String { uid }

    public init(uid: String, name: String) {
        self.uid = uid
        self.name = name
    }
}

/// Lists this Mac's output devices. The app reads CoreAudio; tests list fixed devices.
public protocol OutputDevices: Sendable {
    func list() -> [OutputDevice]
}

/// This Mac's output devices as CoreAudio lists them: every device with an output stream.
public struct CoreAudioOutputDevices: OutputDevices {
    public init() {}

    public func list() -> [OutputDevice] {
        Self.deviceIDs().filter(Self.hasOutput).compactMap { id in
            guard let uid = Self.string(kAudioDevicePropertyDeviceUID, of: id),
                let name = Self.string(kAudioObjectPropertyName, of: id)
            else { return nil }
            return OutputDevice(uid: uid, name: name)
        }
    }

    private static func deviceIDs() -> [AudioDeviceID] {
        var address = Self.address(kAudioHardwarePropertyDevices)
        let system = AudioObjectID(kAudioObjectSystemObject)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else {
            return []
        }
        var ids = [AudioDeviceID](
            repeating: kAudioObjectUnknown, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else {
            return []
        }
        return ids
    }

    private static func hasOutput(_ id: AudioDeviceID) -> Bool {
        var address = Self.address(
            kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeOutput)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr && size > 0
    }

    private static func string(_ selector: AudioObjectPropertySelector, of id: AudioDeviceID)
        -> String?
    {
        var address = Self.address(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = withUnsafeMutablePointer(to: &value) {
            AudioObjectGetPropertyData(id, &address, 0, nil, &size, $0)
        }
        guard status == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }

    private static func address(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }
}
