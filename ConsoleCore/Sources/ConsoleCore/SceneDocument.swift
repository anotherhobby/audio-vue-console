/// One scene as the host's store holds it: its listing's facts and its document, kept whole so
/// whatever the app does not edit goes back, and to the render helper, as it came (design D6).
public struct SceneDocument: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String?
    public let builtIn: Bool
    /// A built-in for a process, the calibration scene: not offered to pick or duplicate.
    public let fixed: Bool
    public let doc: JSONValue

    public init(id: String, name: String?, builtIn: Bool, fixed: Bool, doc: JSONValue) {
        self.id = id
        self.name = name
        self.builtIn = builtIn
        self.fixed = fixed
        self.doc = doc
    }
}
