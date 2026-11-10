import CoreAudio

/// Reads and writes one Core Audio object's properties, on its global scope unless told otherwise
/// (`mac-output` design D3).
struct CoreAudioObject {
    let id: AudioObjectID

    static let system = CoreAudioObject(id: AudioObjectID(kAudioObjectSystemObject))

    static func address(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    /// A property holding an array of `T`, empty where it cannot be read.
    func array<T: BitwiseCopyable>(
        _ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope, empty: T
    ) -> [T] {
        var address = Self.address(selector, scope: scope)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr else {
            return []
        }
        var values = [T](repeating: empty, count: Int(size) / MemoryLayout<T>.stride)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &values) == noErr else {
            return []
        }
        return values
    }

    /// A property holding one `T`, nil where it cannot be read.
    func value<T: BitwiseCopyable>(_ selector: AudioObjectPropertySelector, empty: T) -> T? {
        var address = Self.address(selector)
        var value = empty
        var size = UInt32(MemoryLayout<T>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr else {
            return nil
        }
        return value
    }

    /// A string property, nil where it cannot be read.
    func string(_ selector: AudioObjectPropertySelector) -> String? {
        var address = Self.address(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = withUnsafeMutablePointer(to: &value) {
            AudioObjectGetPropertyData(id, &address, 0, nil, &size, $0)
        }
        guard status == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }

    /// Sets a property holding one `T`, returning Core Audio's status.
    func set<T: BitwiseCopyable>(_ selector: AudioObjectPropertySelector, to value: T) -> OSStatus {
        var address = Self.address(selector)
        var value = value
        return AudioObjectSetPropertyData(
            id, &address, 0, nil, UInt32(MemoryLayout<T>.size), &value)
    }

    /// The device's output streams, first first.
    var outputStreams: [CoreAudioObject] {
        array(
            kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeOutput,
            empty: AudioStreamID(kAudioObjectUnknown)
        ).map(CoreAudioObject.init)
    }
}
