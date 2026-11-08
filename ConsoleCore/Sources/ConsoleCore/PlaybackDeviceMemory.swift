import Foundation

/// The output device chosen for each panel, by the host's id, kept between launches in the app's
/// `UserDefaults`, beside the addresses (`calibration-run`, "A run names the output device feeding
/// the panel"; design D2).
public struct PlaybackDeviceMemory {
    private static let prefix = "playbackDevice."
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Remembers `device` as the one feeding the panel `hostID` names.
    public func remember(_ device: OutputDevice, for hostID: String) {
        defaults.set(["uid": device.uid, "name": device.name], forKey: Self.prefix + hostID)
    }

    /// The device remembered for the panel, only where its id is among `listed`.
    public func chosen(for hostID: String, among listed: [OutputDevice]) -> OutputDevice? {
        guard let kept = defaults.dictionary(forKey: Self.prefix + hostID),
            let uid = kept["uid"] as? String
        else { return nil }
        return listed.first { $0.uid == uid }
    }
}
