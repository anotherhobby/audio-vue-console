import CoreAudio
import Dispatch

/// An output device's rate and format now, as Core Audio holds them.
public struct OutputCurrent: Sendable, Equatable {
    /// The nominal rate, in Hz.
    public let rate: Int
    /// The first output stream's physical format, nil where it is not linear PCM.
    public let format: OutputFormat?

    public init(rate: Int, format: OutputFormat?) {
        self.rate = rate
        self.format = format
    }
}

/// Why an output device was not set as asked.
public enum OutputFailure: Error, Equatable {
    /// This Mac no longer lists the device.
    case notFound
    /// The device does not offer the format at its current rate.
    case formatNotOffered
    /// Core Audio refused, with its status.
    case refused(OSStatus)
}

/// Reads, sets and follows this Mac's output devices (`mac-output` design D3). The app uses Core
/// Audio; tests script a device.
public protocol OutputControl: Sendable {
    /// Every device with an output stream, with its rates and formats.
    func list() -> [OutputDevice]
    /// The device's rate and format now, or nil where it is not listed.
    func current(uid: String) -> OutputCurrent?
    func setRate(uid: String, hz: Int) throws(OutputFailure)
    func setFormat(uid: String, _ format: OutputFormat) throws(OutputFailure)
    /// Yields whenever the device's rate or format, or the list of devices, changes.
    func changes(uid: String) -> AsyncStream<Void>
}

/// This Mac's output devices as Core Audio holds them.
public struct CoreAudioOutputControl: OutputControl {
    public init() {}

    public func list() -> [OutputDevice] {
        Self.devices().compactMap { device in
            guard let uid = device.string(kAudioDevicePropertyDeviceUID),
                let name = device.string(kAudioObjectPropertyName)
            else { return nil }
            return OutputDevice(
                uid: uid, name: name, availableRates: Self.rates(of: device),
                formats: Self.formats(of: device))
        }
    }

    public func current(uid: String) -> OutputCurrent? {
        guard let device = Self.device(uid),
            let rate = device.value(kAudioDevicePropertyNominalSampleRate, empty: Float64(0))
        else { return nil }
        let physical = device.outputStreams.first?.value(
            kAudioStreamPropertyPhysicalFormat, empty: AudioStreamBasicDescription())
        return OutputCurrent(rate: Int(rate.rounded()), format: physical.flatMap(Self.format))
    }

    public func setRate(uid: String, hz: Int) throws(OutputFailure) {
        guard let device = Self.device(uid) else { throw .notFound }
        let status = device.set(kAudioDevicePropertyNominalSampleRate, to: Float64(hz))
        guard status == noErr else { throw .refused(status) }
    }

    public func setFormat(uid: String, _ format: OutputFormat) throws(OutputFailure) {
        guard let device = Self.device(uid), let stream = device.outputStreams.first,
            let rate = current(uid: uid)?.rate
        else { throw .notFound }
        guard var description = Self.available(on: stream, format, at: rate) else {
            throw .formatNotOffered
        }
        description.mSampleRate = Float64(rate)
        let status = stream.set(kAudioStreamPropertyPhysicalFormat, to: description)
        guard status == noErr else { throw .refused(status) }
    }

    public func changes(uid: String) -> AsyncStream<Void> {
        AsyncStream { continuation in
            let watch = OutputWatch(device: Self.device(uid)) { continuation.yield() }
            continuation.onTermination = { _ in watch.stop() }
        }
    }

    // MARK: Reading

    private static func devices() -> [CoreAudioObject] {
        CoreAudioObject.system.array(
            kAudioHardwarePropertyDevices, scope: kAudioObjectPropertyScopeGlobal,
            empty: AudioDeviceID(kAudioObjectUnknown)
        ).map(CoreAudioObject.init).filter { !$0.outputStreams.isEmpty }
    }

    private static func device(_ uid: String) -> CoreAudioObject? {
        devices().first { $0.string(kAudioDevicePropertyDeviceUID) == uid }
    }

    private static func rates(of device: CoreAudioObject) -> [ClosedRange<Double>] {
        device.array(
            kAudioDevicePropertyAvailableNominalSampleRates,
            scope: kAudioObjectPropertyScopeGlobal, empty: AudioValueRange()
        ).compactMap { $0.mMinimum <= $0.mMaximum ? $0.mMinimum...$0.mMaximum : nil }
    }

    private static func formats(of device: CoreAudioObject) -> [OutputFormatRange] {
        rangedFormats(of: device.outputStreams.first).compactMap { ranged in
            guard let format = format(ranged.mFormat),
                ranged.mSampleRateRange.mMinimum <= ranged.mSampleRateRange.mMaximum
            else { return nil }
            let range = ranged.mSampleRateRange
            return OutputFormatRange(format: format, rates: range.mMinimum...range.mMaximum)
        }
    }

    private static func rangedFormats(of stream: CoreAudioObject?)
        -> [AudioStreamRangedDescription]
    {
        stream?.array(
            kAudioStreamPropertyAvailablePhysicalFormats, scope: kAudioObjectPropertyScopeGlobal,
            empty: AudioStreamRangedDescription()) ?? []
    }

    /// The stream's available description for `format` at `rate`.
    private static func available(on stream: CoreAudioObject, _ format: OutputFormat, at rate: Int)
        -> AudioStreamBasicDescription?
    {
        let hertz = Double(rate)
        return rangedFormats(of: stream).first {
            Self.format($0.mFormat) == format && $0.mSampleRateRange.mMinimum <= hertz
                && hertz <= $0.mSampleRateRange.mMaximum
        }?.mFormat
    }

    /// A linear PCM description's bits and kind, nil for any other.
    private static func format(_ description: AudioStreamBasicDescription) -> OutputFormat? {
        guard description.mFormatID == kAudioFormatLinearPCM else { return nil }
        let isFloat = description.mFormatFlags & kAudioFormatFlagIsFloat != 0
        return OutputFormat(bits: Int(description.mBitsPerChannel), isFloat: isFloat)
    }
}
