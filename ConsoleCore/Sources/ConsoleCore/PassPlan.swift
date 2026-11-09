/// The rates a calibration pass runs and the rates it skips, worked out before Start
/// (`calibration-pass`, design D5).
public struct PassPlan: Sendable, Equatable {
    /// The rates to run, lowest first.
    public let runs: [Int]
    /// The host's rates this Mac's output cannot be set to, lowest first.
    public let skipped: [Int]

    public init(runs: [Int], skipped: [Int] = []) {
        self.runs = runs
        self.skipped = skipped
    }

    /// The host's rates split by whether `output` can be set to each.
    public static func make(hostRates: [Int], output: OutputDevice) -> PassPlan {
        let rates = hostRates.sorted()
        return PassPlan(
            runs: rates.filter(output.offers), skipped: rates.filter { !output.offers($0) })
    }
}

/// What became of one rate of a pass.
public enum RateOutcome: Sendable, Equatable {
    /// Its run ended, as `calibration-run` says runs end.
    case ended(CalibrationSession.Ending)
    /// The output could not play it, so it was never run.
    case skipped
    /// The pass ended before it reached the rate.
    case notRun
}

/// One rate of a pass with what became of it, as the summary lists it.
public struct PassOutcome: Sendable, Equatable, Identifiable {
    public let rate: Int
    public let outcome: RateOutcome
    public var id: Int { rate }

    public init(rate: Int, outcome: RateOutcome) {
        self.rate = rate
        self.outcome = outcome
    }
}
