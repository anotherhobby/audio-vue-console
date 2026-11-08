import Foundation
import Observation

/// The app's render helper, started once the app is paired (`render-helper`, design D9): it asks
/// which code the helper carries, then has it make the default run at the preview rate, and holds
/// the queue every scene is drawn through.
@MainActor @Observable
public final class Renderer {
    public enum Phase: Sendable, Hashable {
        /// Not started: the app is not paired yet, or this is a preview.
        case idle
        case starting
        /// Making the first run.
        case preparing
        /// Ready to draw, carrying the code of this digest.
        case ready(digest: String)
        /// The helper could not start or ended before its first run, and why.
        case failed(String)
    }

    public private(set) var phase = Phase.idle
    /// The queue scenes are drawn through, once ready.
    public private(set) var queue: RenderQueue?
    /// The manifest of the code the app carries, where it carries one.
    public let bundledManifest: CardManifest?
    /// How the code the helper carries compares with the paired panel's, once checked
    /// (`card-code`), or nil before then.
    public private(set) var verdict: CardCodeVerdict?

    private let helper: RenderHelper?
    private let missing: String?

    /// A renderer starting helpers with `launcher`, or, with none, saying why in `missing`.
    public init(
        launcher: (any HelperLauncher)?, missing: String? = nil,
        bundledManifest: CardManifest? = nil
    ) {
        helper = launcher.map { RenderHelper(launcher: $0) }
        self.missing = missing
        self.bundledManifest = bundledManifest
    }

    /// The helper the app carries, under its resources, or none in a preview, which runs a copy of
    /// the app that must start no helper (`pitfalls.md`).
    public static func app(environment: [String: String] = ProcessInfo.processInfo.environment)
        -> Renderer
    {
        if environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" { return Renderer(launcher: nil) }
        guard let resources = Bundle.main.resourceURL else {
            return Renderer(launcher: nil, missing: HelperLocation.Missing.script.description)
        }
        let location: HelperLocation
        do {
            location = try HelperLocation.resolve(in: resources)
        } catch {
            return Renderer(launcher: nil, missing: error.description)
        }
        let manifest: CardManifest
        do {
            manifest = try CardCodeCheck.bundledManifest(at: location.manifest)
        } catch {
            return Renderer(launcher: nil, missing: "This build's renderer manifest can't be read.")
        }
        return Renderer(
            launcher: FoundationHelperLauncher(location: location), bundledManifest: manifest)
    }

    /// Starts the helper and makes its first run, unless it is under way or ready.
    public func start() async {
        switch phase {
        case .starting, .preparing, .ready: return
        case .idle, .failed: break
        }
        guard let helper else {
            if let missing { phase = .failed(missing) }
            return
        }
        phase = .starting
        do throws(RenderFailure) {
            let digest = try await helper.hello()
            phase = .preparing
            try await helper.prepare(analysis: .object([:]), rate: RenderRequest.previewRate)
            queue = RenderQueue(helper: helper)
            phase = .ready(digest: digest)
        } catch {
            phase = .failed(Self.reason(error))
        }
    }

    /// Compares the code the helper carries with the panel's, through `scenes`, once ready. Reading
    /// the panel's scenes is not needed for this, so they are not loaded.
    public func checkCode(with scenes: PanelScenes) async {
        guard case .ready(let digest) = phase else { return }
        verdict =
            await scenes.cardCode(helperDigest: digest, bundled: bundledManifest) ?? .unreadable
    }

    /// The stimulus a calibration plays, written by this renderer's helper, or nil where the app
    /// carries no helper (design D4).
    public var stimulus: (any StimulusSource)? {
        helper.map { HelperStimulus(helper: $0) }
    }

    /// Forgets the comparison, as when the app is no longer paired with that panel.
    public func forgetCode() {
        verdict = nil
    }

    /// Ends the helper, as the app does when it quits.
    public func stop() async {
        await helper?.stop()
    }

    private static func reason(_ failure: RenderFailure) -> String {
        switch failure {
        case .unavailable(let reason), .refused(let reason), .failed(let reason): reason
        case .ended: "The renderer stopped before its first frame."
        }
    }
}
