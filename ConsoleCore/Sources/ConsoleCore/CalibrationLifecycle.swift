/// Where a calibration has got to, as the contract declares the panel's words (audio-vue
/// `control-api`, "The contract declares the lifecycle words"). The words pass: `done`, `failed`
/// and `expired` drop to `off` once the panel is given back, so a run's ending is never read from
/// them (design D3).
public enum CalibrationLifecycle: String, Sendable, Equatable {
    /// Not listening: the panel's resting state.
    case off
    /// Armed, listening for the file's marker.
    case waiting
    /// The marker was heard, for one poll before the run starts.
    case arming
    /// The run is being captured.
    case running
    /// The run is captured and being measured.
    case analysing
    /// The run completed and wrote its record.
    case done
    /// The run did not complete, and wrote no record.
    case failed
    /// The arm's deadline passed with no file heard.
    case expired
}
