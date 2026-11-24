import Foundation

/// A card setting that is a block of keys, each key taking the same few numbers, as the schema
/// declares it under `x-keys` with each key's own settings under `properties` (`meter-scales-editor`,
/// design D1). The meter's `scales` is one: a span per field, with an optional anchor and segment
/// size (`meter-segment-size`).
public struct KeyedBlock: Sendable, Equatable {
    /// One key the block takes, as `x-keys` lists it: its name, label, unit, the product's range,
    /// anchor and segment size for it, and the settings its entry under `properties` declares.
    public struct Key: Sendable, Equatable, Identifiable {
        public let name: String
        public let label: String
        public let unit: String
        /// The product's low and high ends for the key, or none where the schema gives none.
        public let range: [Double]
        /// The product's anchor for the key, nil where it has none.
        public let anchor: Double?
        /// The product's segment size for the key, nil where its segments are a count.
        public let segment: Double?
        /// The settings the key takes, in their declared order.
        public let settings: SettingGroup

        public var id: String { name }
    }

    /// The keys in the order `x-keys` lists them.
    public let keys: [Key]
    /// The card setting that picks the key a card shows, as `x-keyed-by` names it.
    public let keyedBy: String
    /// The segment sizes a key may take, in the schema's order: the choices of its `segment`
    /// setting, alike for every key (design D1).
    public let sizes: [Double]

    public init(keys: [Key], keyedBy: String) {
        self.keys = keys
        self.keyedBy = keyedBy
        sizes = Self.sizes(of: keys)
    }

    /// The block `property` declares, or nil where it lists no keys or names no picking setting: a
    /// keyed block with neither is not one this app edits (`card-settings`).
    init?(property: JSONValue) {
        guard let listed = property["x-keys"]?.arrayValue,
            let keyedBy = property["x-keyed-by"]?.stringValue
        else { return nil }
        let nested = property["properties"]?.objectValue ?? [:]
        let keys = listed.compactMap { entry -> Key? in
            guard let name = entry["name"]?.stringValue else { return nil }
            return Key(
                name: name, label: entry["label"]?.stringValue ?? name,
                unit: entry["unit"]?.stringValue ?? "",
                range: (entry["range"]?.arrayValue ?? []).compactMap(\.numberValue),
                anchor: entry["anchor"]?.numberValue, segment: entry["segment"]?.numberValue,
                settings: SettingGroup(definition: nested[name] ?? .null))
        }
        self.init(keys: keys, keyedBy: keyedBy)
    }

    /// What the schema calls `size` among the column's choices, else the number as the panel
    /// writes it.
    public func label(ofSize size: Double) -> String {
        guard let index = sizes.firstIndex(of: size),
            let labels = keys.first?.settings["segment"]?.choiceLabels,
            labels.indices.contains(index)
        else { return SpanRefusal.number(size) }
        return labels[index]
    }

    private static func sizes(of keys: [Key]) -> [Double] {
        guard case .choice(let choices) = keys.first?.settings["segment"]?.shape else { return [] }
        return choices.compactMap(\.numberValue)
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

    /// A key's span as a block holds it: its low, high, anchor and segment size, each nil where
    /// unset.
    public struct Span: Sendable, Equatable {
        public let lo: Double?
        public let hi: Double?
        public let anchor: Double?
        public let segment: Double?

        public init(lo: Double?, hi: Double?, anchor: Double?, segment: Double? = nil) {
            self.lo = lo
            self.hi = hi
            self.anchor = anchor
            self.segment = segment
        }

        /// Whether the row sets nothing, so the key is removed.
        var isEmpty: Bool { lo == nil && hi == nil && anchor == nil && segment == nil }
    }

    /// The span `name` holds in `block`.
    public static func span(of name: String, in block: JSONValue?) -> Span {
        let entry = block?[name]
        return Span(
            lo: entry?["lo"]?.numberValue, hi: entry?["hi"]?.numberValue,
            anchor: entry?["anchor"]?.numberValue, segment: entry?["segment"]?.numberValue)
    }

    /// The block after `name` takes `span` (design D2). A span setting nothing removes the key; a
    /// block left with no keys is nil, stored as unset. Otherwise the span is checked as the card
    /// checks it, and a refused span leaves the block as it was.
    public func edit(
        _ block: JSONValue?, key name: String, span: Span
    ) -> Result<JSONValue?, SpanRefusal> {
        guard let key = self[key: name] else { return .failure(.unknownKey(name)) }
        var keys = block?.objectValue ?? [:]
        if span.isEmpty {
            keys[name] = nil
            return .success(keys.isEmpty ? nil : .object(keys))
        }
        if let refusal = refusal(of: span, for: key) { return .failure(refusal) }
        let parts: [(String, Double?)] = [
            ("lo", span.lo), ("hi", span.hi), ("anchor", span.anchor), ("segment", span.segment),
        ]
        keys[name] = .object(
            Dictionary(
                uniqueKeysWithValues: parts.compactMap { part, number in
                    number.map { (part, SettingDeclaration.json($0)) }
                }))
        return .success(.object(keys))
    }

    /// Why `span` cannot be `key`'s, in the panel's order, or nil: one end alone, the ends
    /// inverted, the anchor outside the range, a size on a count field, or a size that does not
    /// cut the range into whole segments. A span giving no ends is judged on the product's range.
    private func refusal(of span: Span, for key: Key) -> SpanRefusal? {
        if (span.lo == nil) != (span.hi == nil) { return .oneEnd }
        if let lo = span.lo, let hi = span.hi, hi <= lo { return .notAbove(low: lo) }
        guard let low = span.lo ?? key.range.first, let high = span.hi ?? key.range.last else {
            return nil
        }
        if let anchor = span.anchor ?? key.anchor, !(low <= anchor && anchor <= high) {
            return .anchorOutside(anchor: anchor, low: low, high: high)
        }
        if span.segment != nil, key.segment == nil { return .countField }
        guard let size = span.segment ?? key.segment, !Self.divides(high - low, size) else {
            return nil
        }
        return .notDividing(size: size, span: high - low, dividing: dividing(high - low))
    }

    /// How far a segment count may lie from whole and still count as whole: the panel's
    /// `abs_tol` (audio-vue `bar_styles.divides`).
    private static let wholeTolerance = 1e-9

    /// Whether `size` cuts `span` into a whole number of segments, at the panel's tolerance.
    static func divides(_ span: Double, _ size: Double) -> Bool {
        let count = span / size
        return abs(count - count.rounded()) <= wholeTolerance
    }

    /// The block's sizes that divide `span`, as the panel words them (design D4).
    public func dividing(_ span: Double) -> String {
        let fitting = sizes.filter { Self.divides(span, $0) }.map(SpanRefusal.number)
        guard let last = fitting.last else { return "no segment size divides it" }
        let listed =
            fitting.count == 1 ? last : "\(fitting.dropLast().joined(separator: ", ")) and \(last)"
        return "\(listed) divide it"
    }
}

/// Why a span is refused, in the card's own words (audio-vue `meter`, `checked_scales`).
public enum SpanRefusal: Error, Sendable, Equatable {
    case oneEnd
    case notAbove(low: Double)
    case anchorOutside(anchor: Double, low: Double, high: Double)
    case countField
    case notDividing(size: Double, span: Double, dividing: String)
    case unknownKey(String)

    /// What the inspector says beside the row.
    public var text: String {
        switch self {
        case .oneEnd: "a scale needs both a low and a high end, or neither"
        case .notAbove(let low): "must be above the low end \(low)"
        case .anchorOutside(let anchor, let low, let high):
            "the anchor \(anchor) is outside \(low) to \(high)"
        case .countField: "its segments are a count, so it takes no segment size"
        case .notDividing(let size, let span, let dividing):
            "a segment of \(Self.number(size)) does not divide \(Self.number(span)); \(dividing)"
        case .unknownKey(let name): "\(name) is not a field with a scale"
        }
    }

    /// A number as Python's `:g` writes it: "48", "2.5", "1.25" (design D4).
    static func number(_ value: Double) -> String {
        String(format: "%g", value)
    }
}
