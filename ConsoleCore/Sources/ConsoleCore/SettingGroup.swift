/// One setting as the host's schema declares it: what the inspector shows for it and what values it
/// takes (`card-settings`, design D2).
public struct SettingDeclaration: Sendable, Equatable, Identifiable {
    /// The range and step a number keeps to, each where the schema gives one.
    public struct Limits: Sendable, Equatable {
        public let minimum: Double?
        public let maximum: Double?
        /// The increment the setting moves by; it never constrains a value (audio-vue `x-step`).
        public let step: Double?

        public init(minimum: Double? = nil, maximum: Double? = nil, step: Double? = nil) {
            self.minimum = minimum
            self.maximum = maximum
            self.step = step
        }
    }

    /// The kind of control a setting takes, from its declared type.
    public enum Shape: Sendable, Equatable {
        case boolean
        case number(Limits)
        case integer(Limits)
        /// One of the declared choices, as the schema gives them.
        case choice([JSONValue])
        /// `#rrggbb`.
        case colour
        /// A scene role by its id, one of `roles`, or `#rrggbb`: a card's colour setting.
        case roleColour(roles: [String])
        /// A list of `#rrggbb` colours holding at least `minimum`, such as a gradient's stops.
        case colours(minimum: Int)
        /// A shape the inspector shows but does not edit, such as a list of colours.
        case other
    }

    /// One case in which a setting has no effect: where every setting `when` names holds one of the
    /// values listed for it (audio-vue `settings-schema`, "A setting says when it has no effect").
    public struct UnusedCase: Sendable, Equatable {
        /// The card's other settings, by key, each with the values that make up the case.
        public let when: [String: [JSONValue]]
        /// Why the setting has no effect, written for a person.
        public let reason: String

        public init(when: [String: [JSONValue]], reason: String) {
            self.when = when
            self.reason = reason
        }
    }

    /// Where a card's unset colour comes from: the scene's role it takes, or the default of a
    /// colour of its own; neither for any other setting.
    public struct ColourDefault: Sendable, Equatable {
        public let role: String?
        public let own: String?

        public static let none = ColourDefault()

        public init(role: String? = nil, own: String? = nil) {
            self.role = role
            self.own = own
        }
    }

    /// The block an unset setting takes its value from, the setting of the same key there
    /// (audio-vue `x-inherits`, `<document>.<block>`): a scene's display timeouts take the
    /// install's, a card's shadow the scene's colours'.
    public struct Source: Sendable, Equatable {
        /// The document holding the block: `install` or `scene`.
        public let document: String
        public let block: String

        /// What the scene's document is called.
        public static let scene = "scene"
        /// What the install's document is called.
        public static let install = "install"

        public init(document: String, block: String) {
            self.document = document
            self.block = block
        }

        /// The source `name` names, or nil where it is not a document and a block.
        init?(_ name: String?) {
            let parts = (name ?? "").split(separator: ".", maxSplits: 1).map(String.init)
            guard let document = parts.first, let block = parts.last, parts.count > 1 else {
                return nil
            }
            self.init(document: document, block: block)
        }
    }

    /// The standard governing a measurement setting (audio-vue `settings-schema`).
    public enum Standard: Sendable, Equatable {
        /// The setting is not of the measurement class.
        case notApplicable
        /// A measurement setting no standard governs.
        case governedByNone
        /// The standard's document, and the values it defines.
        case document(String, values: [JSONValue])
    }

    public let key: String
    public let label: String
    public let help: String
    /// The unit shown beside a number, empty for none.
    public let unit: String
    /// The setting's class, such as `measurement` or `appearance`, or nil where it declares none.
    public let settingClass: String?
    public let standard: Standard
    /// The value a card takes when the scene leaves the setting unset, or nil where it declares
    /// none: a colour that follows the scene's.
    public let defaultValue: JSONValue?
    public let shape: Shape
    /// The scene role a card's colour setting takes where it is unset (audio-vue `x-role`), or nil
    /// for any other setting (`scene-settings`, design D8).
    public let role: String?
    /// What a colour of the card's own takes where it is unset, a role's id or `#rrggbb`
    /// (audio-vue `x-own`), or nil for any other setting.
    public let ownDefault: String?
    /// What each choice is called, in the choices' order; empty where a choice is its own name
    /// (audio-vue `x-choice-labels`).
    public let choiceLabels: [String]
    /// The cases in which the setting has no effect, in declared order; none where it always has
    /// one (audio-vue `x-unused-when`; `scene-settings` design D9).
    public let unusedWhen: [UnusedCase]
    /// Where the setting's value comes from while it is unset, in place of a default of its own;
    /// nil for a setting that takes its own default.
    public private(set) var inherits: Source?

    public var id: String { key }

    public init(
        key: String, label: String, help: String = "", unit: String = "",
        settingClass: String? = nil, standard: Standard = .notApplicable,
        defaultValue: JSONValue? = nil, shape: Shape, colour: ColourDefault = .none,
        choiceLabels: [String] = [], unusedWhen: [UnusedCase] = []
    ) {
        self.key = key
        self.label = label
        self.help = help
        self.unit = unit
        self.settingClass = settingClass
        self.standard = standard
        self.defaultValue = defaultValue
        self.shape = shape
        role = colour.role
        ownDefault = colour.own
        self.choiceLabels = choiceLabels
        self.unusedWhen = unusedWhen
    }

    /// The setting `key` as `property` declares it.
    init(key: String, property: JSONValue) {
        self.init(
            key: key, label: property["x-label"]?.stringValue ?? key,
            help: property["x-help"]?.stringValue ?? "",
            unit: property["x-unit"]?.stringValue ?? "",
            settingClass: property["x-class"]?.stringValue,
            standard: Self.standard(property["x-standard"]),
            defaultValue: property["default"], shape: Self.shape(property),
            colour: ColourDefault(
                role: property["x-role"]?.stringValue,
                own: property["x-own"]?["default"]?.stringValue),
            choiceLabels: (property["x-choice-labels"]?.arrayValue ?? []).compactMap(\.stringValue),
            unusedWhen: Self.unusedCases(property["x-unused-when"]))
        inherits = Source(property["x-inherits"]?.stringValue)
    }

    /// Whether `other` takes the same values and means the same thing: its shape, unit, class,
    /// standard and the role it takes, whatever its label, help and default (design D3;
    /// `scene-settings` design D8).
    func declaresAlike(_ other: SettingDeclaration) -> Bool {
        key == other.key && shape == other.shape && unit == other.unit
            && settingClass == other.settingClass && standard == other.standard
            && role == other.role
    }

    /// What `choice` is called: its declared label, else the choice itself.
    public func label(of choice: JSONValue) -> String {
        guard case .choice(let choices) = shape, let index = choices.firstIndex(of: choice),
            choiceLabels.indices.contains(index)
        else { return choice.text }
        return choiceLabels[index]
    }

    private static let colourPattern = "^#[0-9a-fA-F]{6}$"

    private static func shape(_ property: JSONValue) -> Shape {
        if let choices = property["enum"]?.arrayValue { return .choice(choices) }
        if let either = property["anyOf"]?.arrayValue,
            either.contains(where: { $0["pattern"]?.stringValue == colourPattern }),
            let roles = either.lazy.compactMap({ $0["enum"]?.arrayValue }).first
        {
            return .roleColour(roles: roles.compactMap(\.stringValue))
        }
        let limits = Limits(
            minimum: property["minimum"]?.numberValue, maximum: property["maximum"]?.numberValue,
            step: property["x-step"]?.numberValue)
        switch property["type"]?.stringValue {
        case "boolean": return .boolean
        case "number": return .number(limits)
        case "integer": return .integer(limits)
        case "string" where property["pattern"]?.stringValue == colourPattern: return .colour
        case "array" where property["items"]?["pattern"]?.stringValue == colourPattern:
            return .colours(minimum: property["minItems"]?.intValue ?? 0)
        default: return .other
        }
    }

    /// The export's `x-unused-when`: a list of `{when: {setting: [values]}, reason}`.
    private static func unusedCases(_ value: JSONValue?) -> [UnusedCase] {
        (value?.arrayValue ?? []).compactMap { entry in
            guard let reason = entry["reason"]?.stringValue,
                let when = entry["when"]?.objectValue?.compactMapValues(\.arrayValue),
                !when.isEmpty
            else { return nil }
            return UnusedCase(when: when, reason: reason)
        }
    }

    private static func standard(_ value: JSONValue?) -> Standard {
        guard let value, value != .null else { return .notApplicable }
        guard let document = value["document"]?.stringValue else { return .governedByNone }
        return .document(document, values: value["values"]?.arrayValue ?? [])
    }
}

/// A card's or a block's settings in the order it declares them (`card-settings`, design D2).
public struct SettingGroup: Sendable, Equatable {
    public let settings: [SettingDeclaration]

    public init(_ settings: [SettingDeclaration]) {
        self.settings = settings
    }

    /// The settings `definition` declares under `properties`, in its `x-settings` order. A key
    /// `x-settings` leaves out follows, by name, so no declared setting is lost.
    public init(definition: JSONValue) {
        let properties = definition["properties"]?.objectValue ?? [:]
        let listed = (definition["x-settings"]?.arrayValue ?? []).compactMap(\.stringValue)
        let unlisted = properties.keys.filter { !listed.contains($0) }.sorted()
        self.init(
            (listed + unlisted).compactMap { key in
                properties[key].map { SettingDeclaration(key: key, property: $0) }
            })
    }

    public subscript(key: String) -> SettingDeclaration? {
        settings.first { $0.key == key }
    }

    /// The settings every one of `groups` declares alike, labelled and ordered as the first
    /// declares them: what several selected cards are edited together by (design D3).
    public static func shared(_ groups: [SettingGroup]) -> SettingGroup {
        guard let first = groups.first else { return SettingGroup([]) }
        let others = groups.dropFirst()
        return SettingGroup(
            first.settings.filter { setting in
                others.allSatisfy { $0[setting.key]?.declaresAlike(setting) == true }
            })
    }
}
