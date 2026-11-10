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
        /// A shape the inspector shows but does not edit, such as a list of colours.
        case other
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
    /// none: a colour that follows the palette.
    public let defaultValue: JSONValue?
    public let shape: Shape

    public var id: String { key }

    public init(
        key: String, label: String, help: String = "", unit: String = "",
        settingClass: String? = nil, standard: Standard = .notApplicable,
        defaultValue: JSONValue? = nil, shape: Shape
    ) {
        self.key = key
        self.label = label
        self.help = help
        self.unit = unit
        self.settingClass = settingClass
        self.standard = standard
        self.defaultValue = defaultValue
        self.shape = shape
    }

    /// The setting `key` as `property` declares it.
    init(key: String, property: JSONValue) {
        self.init(
            key: key, label: property["x-label"]?.stringValue ?? key,
            help: property["x-help"]?.stringValue ?? "",
            unit: property["x-unit"]?.stringValue ?? "",
            settingClass: property["x-class"]?.stringValue,
            standard: Self.standard(property["x-standard"]),
            defaultValue: property["default"], shape: Self.shape(property))
    }

    /// Whether `other` takes the same values and means the same thing: its shape, unit, class and
    /// standard, whatever its label, help and default (design D3).
    func declaresAlike(_ other: SettingDeclaration) -> Bool {
        key == other.key && shape == other.shape && unit == other.unit
            && settingClass == other.settingClass && standard == other.standard
    }

    private static let colourPattern = "^#[0-9a-fA-F]{6}$"

    private static func shape(_ property: JSONValue) -> Shape {
        if let choices = property["enum"]?.arrayValue { return .choice(choices) }
        let limits = Limits(
            minimum: property["minimum"]?.numberValue, maximum: property["maximum"]?.numberValue,
            step: property["x-step"]?.numberValue)
        switch property["type"]?.stringValue {
        case "boolean": return .boolean
        case "number": return .number(limits)
        case "integer": return .integer(limits)
        case "string" where property["pattern"]?.stringValue == colourPattern: return .colour
        default: return .other
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
