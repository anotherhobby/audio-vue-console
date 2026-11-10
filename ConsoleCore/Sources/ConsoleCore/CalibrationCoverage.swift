/// Whether a calibration holds at the rate a scene captures at, which the Analysis section warns
/// about only where none does (`scene-settings`, "The scene says when no calibration holds at its
/// rate"; design D7). The panel applies the newest record valid for the device and rate in use,
/// a stale one included, so a stale record holds.
public enum CalibrationCoverage {
    /// The rate a scene with `blocks` captures at: its analysis block's `capture_rate`, else
    /// `installed`, the install's rate.
    public static func rate(of blocks: [String: JSONValue], installed: Int?) -> Int? {
        blocks["analysis"]?["capture_rate"]?.intValue ?? installed
    }

    /// What the Analysis section says for a scene with `blocks`: nil where a calibration holds at
    /// its rate, or where the rate or the host's calibrations are not known.
    public static func note(
        for blocks: [String: JSONValue], installed: Int?,
        calibrations: [Int: CalibratedRate.Status]?
    ) -> String? {
        guard let calibrations, let rate = rate(of: blocks, installed: installed),
            calibrations[rate] == nil
        else { return nil }
        return "No calibration holds at \(RateText.text(rate)), so this scene's readings are "
            + "uncalibrated."
    }
}
