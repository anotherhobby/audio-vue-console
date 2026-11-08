import Foundation

/// The app's stimulus: written by the render helper from the audio-vue code the app carries, into
/// a fresh file in the container's temporary directory, which the player's sandbox can read (design
/// D4). The session removes the file when its run ends.
public struct HelperStimulus: StimulusSource {
    let helper: RenderHelper
    let directory: URL

    public init(helper: RenderHelper, directory: URL = HelperStimulus.defaultDirectory) {
        self.helper = helper
        self.directory = directory
    }

    public static var defaultDirectory: URL {
        FileManager.default.temporaryDirectory.appending(path: "Calibration")
    }

    public func file(for run: StatedRun) async throws(StimulusFailure) -> URL {
        let file = directory.appending(path: "\(UUID().uuidString).wav")
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
        } catch {
            throw .failed(error.localizedDescription)
        }
        do {
            try await helper.stimulus(run, to: file)
        } catch {
            throw Self.failure(error)
        }
        return file
    }

    private static func failure(_ failure: RenderFailure) -> StimulusFailure {
        switch failure {
        case .refused(let reason): .refused(reason)
        case .failed(let reason), .unavailable(let reason): .failed(reason)
        case .ended: .failed("The renderer stopped while writing the file.")
        }
    }
}
