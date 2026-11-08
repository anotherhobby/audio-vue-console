import Foundation

/// How what each step met becomes the run's step or ending (design D3).
extension CalibrationSession {
    /// The step the panel's word gives, where it gives one: listening is armed, the marker heard
    /// and the capture are measuring. An ended word gives none, since it passes.
    static func step(_ word: CalibrationLifecycle?) -> Step? {
        switch word {
        case .waiting?: .armed
        case .arming?, .running?: .measuring
        case .analysing?: .analysing
        case nil, .off?, .done?, .failed?, .expired?: nil
        }
    }

    static func ending(_ ended: EndedCalibration) -> Ending {
        switch ended.outcome {
        case .done:
            .completed(
                runID: ended.runID, applicable: ended.applicable ?? true, reason: ended.reason)
        case .failed: .failed(reason: ended.reason)
        case .expired: .expired(reason: ended.reason)
        case .cancelled: .cancelled
        }
    }

    static func ending(_ failure: StimulusFailure) -> Ending {
        switch failure {
        case .refused(let reason): .stimulusRefused(reason)
        case .failed(let reason): .stimulusFailed(reason)
        case .cancelled: .cancelled
        }
    }

    static func ending(_ failure: PlayerFailure) -> Ending {
        switch failure {
        case .cancelled: .cancelled
        case .failed(let reason), .couldNotStart(let reason): .playerFailed(reason)
        case .busy: .playerFailed("cal-play is already running.")
        }
    }

    /// A command's outcome in the panel's words, or what it came to where it gave none.
    static func words(_ outcome: CommandOutcome) -> String {
        switch outcome {
        case .refused(let reason), .expired(let reason), .unknown(let reason):
            reason.isEmpty ? "The panel didn't take it." : reason
        case .noPanel: "The panel isn't running."
        case .done: "Done."
        }
    }
}
