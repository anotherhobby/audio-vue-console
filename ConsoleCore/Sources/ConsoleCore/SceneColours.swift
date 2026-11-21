/// The colours a scene draws in, as the host's schema declares them: a colour per role, the things
/// seen on screen, and the steps of each meaning scale, with the lookup that resolves a card's
/// colour as the panel does (audio-vue `card-colours`; `scene-settings`, design D8). Every name
/// and default is read; no rule is copied.
public struct SceneColours: Sendable, Equatable {
    /// One thing cards draw, such as titles, holding a colour a scene may set.
    public struct Role: Sendable, Equatable, Identifiable {
        public let id: String
        /// The group the inspector lists it under, such as `text`.
        public let group: String
        public let label: String
        /// The colour where a scene leaves it unset.
        public let defaultColour: HexColour

        public init(id: String, group: String, label: String, defaultColour: HexColour) {
            self.id = id
            self.group = group
            self.label = label
            self.defaultColour = defaultColour
        }
    }

    /// A meaning scale, such as Warnings, and its steps' keys in the scene's colours.
    public struct Scale: Sendable, Equatable, Identifiable {
        public let id: String
        public let label: String
        public let steps: [String]

        public init(id: String, label: String, steps: [String]) {
            self.id = id
            self.label = label
            self.steps = steps
        }
    }

    /// The colour settings listed under one heading: a group of roles, or a scale's steps.
    public struct Group: Sendable, Equatable, Identifiable {
        public let label: String
        public let settings: [SettingDeclaration]

        public var id: String { label }
    }

    /// The scene block that holds a colour per role and step.
    public static let block = "colors"

    /// The roles in declared order.
    public let roles: [Role]
    /// The scales in declared order.
    public let scales: [Scale]

    public static let none = SceneColours(roles: [], scales: [])

    public init(roles: [Role], scales: [Scale]) {
        self.roles = roles
        self.scales = scales
    }

    /// The colours in `schema`, the body of `/v1/schema`: the root's `x-roles` and `x-scales`, in
    /// their order, each role labelled as `block.colors` labels its setting.
    public init(schema: JSONValue) {
        let declared = SettingGroup(definition: schema["$defs"]?["block.colors"] ?? .null)
        let roles = (schema["x-roles"]?.arrayValue ?? []).compactMap { entry -> Role? in
            guard let id = entry["id"]?.stringValue, let group = entry["group"]?.stringValue,
                let colour = entry["default"]?.stringValue.flatMap(HexColour.init)
            else { return nil }
            return Role(
                id: id, group: group, label: declared[id]?.label ?? id, defaultColour: colour)
        }
        let scales = (schema["x-scales"]?.arrayValue ?? []).compactMap { entry -> Scale? in
            guard let id = entry["id"]?.stringValue, let label = entry["label"]?.stringValue
            else { return nil }
            let steps = (entry["steps"]?.arrayValue ?? []).compactMap { $0["id"]?.stringValue }
            return Scale(id: id, label: label, steps: steps)
        }
        self.init(roles: roles, scales: scales)
    }

    public func role(_ id: String) -> Role? {
        roles.first { $0.id == id }
    }

    /// The colour a scene with `blocks` gives `role`: its own, else the role's default.
    public func colour(of role: String, in blocks: [String: JSONValue]) -> HexColour? {
        blocks[Self.block]?[role]?.stringValue.flatMap(HexColour.init)
            ?? self.role(role)?.defaultColour
    }

    /// `settings`, the colours block's, under their headings: each group of roles in the order it
    /// first appears, then each scale. A setting that is neither, such as the shadow's amount, is
    /// in none.
    public func groups(of settings: SettingGroup) -> [Group] {
        var order: [String] = []
        var members: [String: [SettingDeclaration]] = [:]
        for role in roles {
            guard let setting = settings[role.id] else { continue }
            if members[role.group] == nil { order.append(role.group) }
            members[role.group, default: []].append(setting)
        }
        let grouped = order.map { Group(label: $0.capitalized, settings: members[$0] ?? []) }
        let scaled = scales.map { scale in
            Group(label: scale.label, settings: scale.steps.compactMap { settings[$0] })
        }
        return (grouped + scaled).filter { !$0.settings.isEmpty }
    }

    /// The colours block's settings no heading holds, in declared order.
    public func ungrouped(of settings: SettingGroup) -> [SettingDeclaration] {
        let held = Set(groups(of: settings).flatMap(\.settings).map(\.key))
        return settings.settings.filter { !held.contains($0.key) }
    }
}

/// The colour a card's colour setting is drawn in, and the scene's role it comes from where it is
/// not a colour of the card's own (`card-settings`, "A setting shows the scene's value or the
/// card's default").
public struct DrawnColour: Sendable, Equatable {
    public let colour: HexColour
    /// The role whose colour this is, or nil for a colour the card holds itself.
    public let role: SceneColours.Role?

    /// What the inspector says under the colour, such as "Uses the scene's Title colour"; nil for
    /// a colour of the card's own.
    public var caption: String? {
        role.map { "Uses the scene's \($0.label) colour" }
    }
}
