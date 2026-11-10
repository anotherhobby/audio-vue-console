import Observation

/// This Mac's output for one panel: the device remembered as feeding it, that device's rate and
/// format as Core Audio holds them, and whether Synchronize Rates is on (`mac-output`, design D4).
/// It reads and sets; when to set the rate for synchronization is `RateSync`'s.
@MainActor @Observable
public final class MacOutput {
    /// This Mac's output devices.
    public private(set) var devices: [OutputDevice] = []
    /// The device remembered for the panel, nil where none is or it is not listed.
    public private(set) var device: OutputDevice?
    /// The device's rate and format now.
    public private(set) var current: OutputCurrent?
    public private(set) var isSynchronized: Bool
    /// Why the last set was refused, until the next succeeds.
    public private(set) var refusal: OutputFailure?

    private let hostID: String
    private let control: any OutputControl
    private let memory: PlaybackDeviceMemory

    public init(
        hostID: String, control: any OutputControl = CoreAudioOutputControl(),
        memory: PlaybackDeviceMemory = PlaybackDeviceMemory()
    ) {
        self.hostID = hostID
        self.control = control
        self.memory = memory
        isSynchronized = memory.isSynchronized(for: hostID)
    }

    /// The formats the device offers at its current rate, deepest first.
    public var formatChoices: [OutputFormat] {
        guard let device, let rate = current?.rate else { return [] }
        return device.formats(at: rate)
    }

    /// Lists the devices and reads the remembered one's rate and format.
    public func load() {
        devices = control.list()
        device = memory.chosen(for: hostID, among: devices)
        current = device.flatMap { control.current(uid: $0.uid) }
    }

    /// Reads everything again on each change to the chosen device or the list of devices, until
    /// the calling task is cancelled. Run again when another device is chosen.
    public func follow() async {
        for await _ in control.changes(uid: device?.uid ?? "") {
            load()
        }
    }

    /// Chooses `device` as the one feeding the panel, and remembers it.
    public func choose(_ device: OutputDevice) {
        memory.remember(device, for: hostID)
        refusal = nil
        load()
    }

    /// Sets the device's rate, keeping Core Audio's refusal where it refuses.
    public func setRate(_ hertz: Int) {
        guard let uid = device?.uid else { return }
        set { () throws(OutputFailure) in try control.setRate(uid: uid, hz: hertz) }
    }

    /// Sets the device's format at its current rate, keeping Core Audio's refusal where it refuses.
    public func setFormat(_ format: OutputFormat) {
        guard let uid = device?.uid else { return }
        set { () throws(OutputFailure) in try control.setFormat(uid: uid, format) }
    }

    /// Turns Synchronize Rates on or off for the panel, and remembers it.
    public func setSynchronized(_ isOn: Bool) {
        memory.setSynchronized(isOn, for: hostID)
        isSynchronized = isOn
    }

    private func set(_ change: () throws(OutputFailure) -> Void) {
        do {
            try change()
            refusal = nil
        } catch {
            refusal = error
        }
        load()
    }
}
