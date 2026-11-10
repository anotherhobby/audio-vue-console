import Foundation

/// What a setting holds across the selected cards (`card-settings`, design D3).
public enum SettingValue: Sendable, Equatable {
    /// Every card takes `value`, nil for a colour left to the palette. `isSet` where any card's
    /// entry sets the setting, so Use Default has something to remove.
    case same(JSONValue?, isSet: Bool)
    /// The cards take different values.
    case mixed(isSet: Bool)

    public var isSet: Bool {
        switch self {
        case .same(_, let isSet), .mixed(let isSet): isSet
        }
    }
}

/// What the inspector says under a setting beside its help (design D5).
public enum SettingNote: Sendable, Equatable {
    /// A measurement setting holds a value its standard, this document, does not define.
    case offStandard(String)
}

extension SettingDeclaration {
    /// The value a card with `settings` takes: its own, else the default, else nil for a colour
    /// that follows the palette.
    public func effectiveValue(in settings: [String: JSONValue]) -> JSONValue? {
        settings[key] ?? defaultValue
    }

    /// The note for `value`: off-standard where this is a measurement setting whose standard does
    /// not define it, and none for any other class, a card's chain setting included.
    public func note(for value: JSONValue?) -> SettingNote? {
        guard settingClass == Self.measurementClass,
            case .document(let document, let values) = standard, let value
        else { return nil }
        return values.contains { Self.same($0, value) } ? nil : .offStandard(document)
    }

    /// `number` as this setting stores it: kept to its range, rounded to its step from the
    /// minimum, and written as an integer where it is whole, so a scene read back after a save
    /// compares equal (design D4). Nil for a setting that is no number.
    public func written(_ number: Double) -> JSONValue? {
        switch shape {
        case .number(let limits): Self.json(limits.fitted(number))
        case .integer(let limits): .integer(Int(limits.fitted(number).rounded()))
        default: nil
        }
    }

    /// The value `steps` steps on from `value`, or from the default where it is unset. Nil for a
    /// setting that is no number, or a decimal one that declares no step.
    public func stepped(_ value: JSONValue?, by steps: Int) -> JSONValue? {
        let step: Double?
        switch shape {
        case .number(let limits): step = limits.step
        case .integer(let limits): step = limits.step ?? 1
        default: step = nil
        }
        guard let step, let current = (value ?? defaultValue)?.numberValue else { return nil }
        return written(current + Double(steps) * step)
    }

    private static let measurementClass = "measurement"

    /// A whole number as an integer and any other as a decimal, the forms `JSONValue` decodes.
    private static func json(_ number: Double) -> JSONValue {
        Int(exactly: number).map(JSONValue.integer) ?? .decimal(number)
    }

    /// Whether two values are the same, numbers by value whatever their form.
    private static func same(_ first: JSONValue, _ second: JSONValue) -> Bool {
        if let one = first.numberValue, let other = second.numberValue { return one == other }
        return first == second
    }
}

extension SettingDeclaration.Limits {
    /// The most decimal places a step or minimum is rounded to.
    private static let maximumPlaces = 9
    private static let tolerance = 1e-9
    /// Places are decimal places.
    private static let radix = 10.0

    /// `number` within the range and, where a step is declared, on the nearest step from the
    /// minimum, rounded to the places of the step and minimum so no binary fraction is left over.
    func fitted(_ number: Double) -> Double {
        let clamped = Self.clamped(number, minimum, maximum)
        guard let step, step > 0 else { return clamped }
        let base = minimum ?? 0
        let stepped = base + ((clamped - base) / step).rounded() * step
        let places = max(Self.places(of: step), Self.places(of: base))
        let scale = pow(Self.radix, Double(places))
        return Self.clamped((stepped * scale).rounded() / scale, minimum, maximum)
    }

    private static func clamped(_ number: Double, _ minimum: Double?, _ maximum: Double?) -> Double
    {
        min(max(number, minimum ?? -.infinity), maximum ?? .infinity)
    }

    /// The decimal places `number` is written with, up to `maximumPlaces`.
    private static func places(of number: Double) -> Int {
        (0...maximumPlaces).first { places in
            let scaled = number * pow(radix, Double(places))
            return abs(scaled - scaled.rounded()) < tolerance * max(1, abs(scaled))
        } ?? maximumPlaces
    }
}

extension SettingGroup {
    /// `key`'s value across `cards`, each card read by its own kind's declaration in `groups`, so
    /// cards with different defaults that leave the setting unset may differ.
    public static func value(
        of key: String, across cards: [LayoutCard], declaredBy groups: [String: SettingGroup]
    ) -> SettingValue {
        let isSet = cards.contains { $0.settings[key] != nil }
        let values = cards.map { card in
            groups[card.kind]?[key]?.effectiveValue(in: card.settings)
        }
        guard let first = values.first, values.allSatisfy({ $0 == first }) else {
            return .mixed(isSet: isSet)
        }
        return .same(first, isSet: isSet)
    }

    /// The note for `key` across `cards`: off its standard where any card's value is.
    public static func note(
        of key: String, across cards: [LayoutCard], declaredBy groups: [String: SettingGroup]
    ) -> SettingNote? {
        cards.lazy.compactMap { card in
            groups[card.kind]?[key].flatMap { $0.note(for: $0.effectiveValue(in: card.settings)) }
        }.first
    }
}
