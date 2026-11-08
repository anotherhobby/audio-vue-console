import Foundation

/// Why a run's stimulus could not be had (design D4).
public enum StimulusFailure: Error, Equatable, Sendable {
    /// The writer refused what the run states, with the panel's own words.
    case refused(String)
    /// The writer could not write the file.
    case failed(String)
    /// The run was cancelled while the file was being written.
    case cancelled
}

/// Writes a run's stimulus into the app's container and gives its file, whole. The app's renders
/// it with the bundled audio-vue code; tests give a file of their own.
public protocol StimulusSource: Sendable {
    func file(for run: StatedRun) async throws(StimulusFailure) -> URL
}

/// Where a run arms and cancels: the panel's host and the app's token for it.
public struct CalibrationHost: Sendable, Equatable {
    public let address: HostAddress
    public let token: HostToken

    public init(address: HostAddress, token: HostToken) {
        self.address = address
        self.token = token
    }
}
