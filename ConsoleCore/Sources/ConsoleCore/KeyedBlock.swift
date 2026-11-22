import Foundation

/// A card setting that is a block of keys, each key taking the same few numbers, as the schema
/// declares it under `x-keys` with each key's own settings under `properties` (`meter-scales-editor`,
/// design D1). The meter's `scales` is one: a span per field, with an optional anchor.
public struct KeyedBlock: Sendable, Equatable {
    /// One key the block takes, as `x-keys` lists it: its name, label, unit, the product's range and
    /// anchor for it, and the settings its entry under `properties` declares.
    public struct Key: Sendable, Equatable, Identifiable {
        public let name: String
        public let label: String
        public let unit: String
        /// The product's low and high ends for the key, or none where the schema gives none.
        public let range: [Double]
        /// The product's anchor for the key, nil where it has none.
        public let anchor: Double?
        /// The settings the key takes, in their declared order.
        public let settings: SettingGroup
        /// The settings the key must set, as its declaration names them.
        public let required: [String]

        public var id: String { name }
    }

    /// The keys in the order `x-keys` lists them.
    public let keys: [Key]
    /// The card setting that picks the key a card shows, as `x-keyed-by` names it.
    public let keyedBy: String

    public init(keys: [Key], keyedBy: String) {
        self.keys = keys
        self.keyedBy = keyedBy
    }

    /// The block `property` declares, or nil where it lists no keys or names no picking setting: a
    /// keyed block with neither is not one this app edits (`card-settings`).
    init?(property: JSONValue) {
        guard let listed = property["x-keys"]?.arrayValue,
            let keyedBy = property["x-keyed-by"]?.stringValue
        else { return nil }
        self.keyedBy = keyedBy
        let nested = property["properties"]?.objectValue ?? [:]
        keys = listed.compactMap { entry in
            guard let name = entry["name"]?.stringValue else { return nil }
            let declaration = nested[name] ?? .null
            return Key(
                name: name, label: entry["label"]?.stringValue ?? name,
                unit: entry["unit"]?.stringValue ?? "",
                range: (entry["range"]?.arrayValue ?? []).compactMap(\.numberValue),
                anchor: entry["anchor"]?.numberValue,
                settings: SettingGroup(definition: declaration),
                required: (declaration["required"]?.arrayValue ?? []).compactMap(\.stringValue))
        }
    }

    /// The keys the picked names select, in the order `x-keys` lists them.
    public func keys(picked: Set<String>) -> [Key] {
        keys.filter { picked.contains($0.name) }
    }

    /// The keys the cards pick under `keyedBy`, each card read by its own kind's declaration in
    /// `groups` so an unset pick takes the default it declares.
    public static func picked(
        by setting: String, across cards: [LayoutCard], declaredBy groups: [String: SettingGroup]
    ) -> Set<String> {
        Set(
            cards.compactMap { card in
                groups[card.kind]?[setting]?.effectiveValue(in: card.settings)?.stringValue
            })
    }

    /// The key `name` names, or nil where the block takes no such key.
    public subscript(key name: String) -> Key? {
        keys.first { $0.name == name }
    }

    /// A key's span as a block holds it: its low, high and anchor, each nil where unset.
    public struct Span: Sendable, Equatable {
        public let lo: Double?
        public let hi: Double?
        public let anchor: Double?

        public init(lo: Double?, hi: Double?, anchor: Double?) {
            self.lo = lo
            self.hi = hi
            self.anchor = anchor
        }
    }

    /// The span `name` holds in `block`.
    public static func span(of name: String, in block: JSONValue?) -> Span {
        let entry = block?[name]
        return Span(
            lo: entry?["lo"]?.numberValue, hi: entry?["hi"]?.numberValue,
            anchor: entry?["anchor"]?.numberValue)
    }

    /// The block after `name` takes the span `lo`, `hi` and `anchor` (design D2). Both ends cleared
    /// removes the key; a block left with no keys is nil, stored as unset. Otherwise the span is
    /// checked as the card checks it, and a refused span leaves the block as it was. The anchor, set
    /// or else the product's, must lie between the ends.
    public func edit(
        _ block: JSONValue?, key name: String, lo: Double?, hi: Double?, anchor: Double?
    ) -> Result<JSONValue?, SpanRefusal> {
        guard let key = self[key: name] else { return .failure(.unknownKey(name)) }
        var keys = block?.objectValue ?? [:]
        if lo == nil, hi == nil, anchor == nil {
            keys[name] = nil
            return .success(keys.isEmpty ? nil : .object(keys))
        }
        guard let lo, let hi else { return .failure(.missingEnd) }
        guard hi > lo else { return .failure(.notAbove(low: lo)) }
        if let effective = anchor ?? key.anchor, !(lo <= effective && effective <= hi) {
            return .failure(.anchorOutside(anchor: effective, low: lo, high: hi))
        }
        var span: [String: JSONValue] = [
            "lo": SettingDeclaration.json(lo), "hi": SettingDeclaration.json(hi),
        ]
        if let anchor { span["anchor"] = SettingDeclaration.json(anchor) }
        keys[name] = .object(span)
        return .success(.object(keys))
    }
}

/// Why a span is refused, in the card's own words (audio-vue `meter`, `checked_scales`).
public enum SpanRefusal: Error, Sendable, Equatable {
    case missingEnd
    case notAbove(low: Double)
    case anchorOutside(anchor: Double, low: Double, high: Double)
    case unknownKey(String)

    /// What the inspector says beside the row.
    public var text: String {
        switch self {
        case .missingEnd: "a scale needs both a low and a high end"
        case .notAbove(let low): "must be above the low end \(low)"
        case .anchorOutside(let anchor, let low, let high):
            "the anchor \(anchor) is outside \(low) to \(high)"
        case .unknownKey(let name): "\(name) is not a field with a scale"
        }
    }
}
