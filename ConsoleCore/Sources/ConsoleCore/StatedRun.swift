import Foundation

/// What a run states about itself: its kind and the rate its file is played at, as `make
/// calibrate`'s `KIND` and `CAL_RATE` (`calibration-run`). The file and the arm are both made from
/// one, so they state the same run. A run states nothing it cannot measure (maintainer,
/// 2026-11-08).
public struct StatedRun: Sendable, Equatable {
    /// A calibration sets and checks the reference frame; a characterization does that and plays
    /// every other stimulus too.
    public enum Kind: String, Sendable, CaseIterable {
        case calibration
        case characterization
    }

    public var kind: Kind
    /// The rate the file is written, played and captured at: the panel's installed capture rate.
    public var rate: Int

    public init(kind: Kind = .calibration, rate: Int) {
        self.kind = kind
        self.rate = rate
    }
}
