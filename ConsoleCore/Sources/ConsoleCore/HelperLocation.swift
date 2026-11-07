import Foundation

/// Where the render helper the app carries is: its interpreter, its script and its manifest, under
/// the app's resources, where the build phase "Embed the render runtime" puts them
/// (`render-runtime`, design D1a).
public struct HelperLocation: Sendable, Equatable {
    /// Why the app carries no helper it can start.
    public enum Missing: Error, Sendable, Equatable, CustomStringConvertible {
        case interpreter
        case script
        case manifest

        public var description: String {
            switch self {
            case .interpreter: "This build carries no Python to run the renderer."
            case .script: "This build carries no renderer."
            case .manifest: "This build's renderer has no manifest."
            }
        }
    }

    public let interpreter: URL
    public let script: URL
    public let manifest: URL

    /// The helper under `resources`, or why there is none to start.
    public static func resolve(in resources: URL) throws(Missing) -> HelperLocation {
        let interpreter = resources.appending(path: "python/bin/python3")
        let bundle = resources.appending(path: "render-bundle")
        let script = bundle.appending(path: "src/render_service.py")
        let manifest = bundle.appending(path: "manifest.json")
        let files = FileManager.default
        guard files.isExecutableFile(atPath: interpreter.path) else { throw .interpreter }
        guard files.fileExists(atPath: script.path) else { throw .script }
        guard files.fileExists(atPath: manifest.path) else { throw .manifest }
        return HelperLocation(interpreter: interpreter, script: script, manifest: manifest)
    }
}
