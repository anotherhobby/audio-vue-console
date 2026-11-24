import Foundation

/// The shape a scene must have, as the host's settings schema exports it under `$defs`, and the
/// smallest edit that gives a scene that shape (`scene-repair`, design D1 and D2). Only the
/// export's shape is judged: what validation checks beyond it, such as a grid's reach or an
/// image's presence, is left to the helper's refusal.
public struct SceneShape: Sendable, Equatable {
    let definitions: [String: JSONValue]
    /// This reading of the schema, so a repair held for it is known without comparing schemas.
    let identity = UUID()

    /// No shape: nothing needs a repair.
    public static let none = SceneShape(definitions: [:])

    init(definitions: [String: JSONValue]) {
        self.definitions = definitions
    }

    /// Two shapes are equal where their schemas are, however they were read.
    public static func == (one: SceneShape, other: SceneShape) -> Bool {
        one.definitions == other.definitions
    }

    /// The shape in `schema`, the body of `/v1/schema`.
    public init(schema: JSONValue) {
        self.init(definitions: schema["$defs"]?.objectValue ?? [:])
    }

    /// The repair `doc`, a scene document, needs, or nil where it has the shape already.
    public func repair(of doc: JSONValue) -> SceneRepair? {
        guard let scene = definitions[Self.scene] else { return nil }
        var walk = ShapeWalk(definitions: definitions)
        let fitted = walk.fit(doc, to: scene, at: [])
        // Every edit the walk makes is recorded, so none recorded is the scene as it was.
        if fitted != nil, walk.changes.isEmpty { return nil }
        return SceneRepair(original: doc, doc: fitted, changes: walk.changes)
    }

    private static let scene = "scene"

    /// Every JSON Schema keyword the walk judges by, and the annotations it reads past: what a
    /// test holds the export to, so a keyword added there is noticed.
    static let keywords: Set<String> = [
        "type", "const", "enum", "pattern", "minLength", "minimum", "maximum", "properties",
        "additionalProperties", "required", "dependentRequired", "$ref", "anyOf", "allOf", "if",
        "then", "items",
        "minItems", "maxItems", "uniqueItems", "default", "$schema", "$defs",
    ]
}

/// One walk of a document against the schema, gathering the changes it makes. A value that
/// cannot be made to fit answers nil and leaves no change of its own: its parent records it.
struct ShapeWalk {
    let definitions: [String: JSONValue]
    private(set) var changes: [RepairChange] = []
    private let patterns: PatternCache

    init(definitions: [String: JSONValue], patterns: PatternCache = PatternCache()) {
        self.definitions = definitions
        self.patterns = patterns
    }

    /// `value` as `schema` takes it, or nil where no edit of it fits, the changes made recorded
    /// under `path`.
    mutating func fit(
        _ value: JSONValue, to schema: JSONValue, at path: [RepairChange.Step]
    ) -> JSONValue? {
        let mark = changes.count
        let fitted = fitting(value, to: resolved(schema), at: path)
        if fitted == nil { changes.removeSubrange(mark...) }
        return fitted
    }

    private mutating func fitting(
        _ value: JSONValue, to schema: JSONValue, at path: [RepairChange.Step]
    ) -> JSONValue? {
        guard takes(value, schema) else { return nil }
        var fitted = clamped(value, to: schema, at: path)
        var parts = schema["allOf"]?.arrayValue ?? []
        if let condition = schema["if"], let then = schema["then"], conforms(fitted, to: condition)
        {
            parts.append(then)
        }
        for part in parts {
            guard let next = fit(fitted, to: part, at: path) else { return nil }
            fitted = next
        }
        if let branches = schema["anyOf"]?.arrayValue,
            !branches.contains(where: { conforms(fitted, to: $0) })
        {
            return nil
        }
        switch fitted {
        case .object(let fields) where Self.judges(schema, Self.objectKeywords):
            return fitObject(fields, to: schema, at: path)
        case .array(let items) where Self.judges(schema, Self.arrayKeywords):
            return fitArray(items, to: schema, at: path)
        default: return fitted
        }
    }

    /// Whether `schema` holds any of `keywords`: one that holds none judges nothing of an object's
    /// keys or a list's items, so they are not walked.
    private static func judges(_ schema: JSONValue, _ keywords: [String]) -> Bool {
        keywords.contains { schema[$0] != nil }
    }

    private static let objectKeywords = [
        "properties", "additionalProperties", "required", "dependentRequired",
    ]
    private static let arrayKeywords = ["items", "minItems", "maxItems", "uniqueItems"]

    /// `schema` with each `$ref` it starts with followed, its own keys over the definition's.
    private func resolved(_ schema: JSONValue) -> JSONValue {
        guard let ref = schema["$ref"]?.stringValue,
            let target = definitions[String(ref.split(separator: "/").last ?? "")]
        else { return schema }
        var merged = resolved(target).objectValue ?? [:]
        for (key, own) in schema.objectValue ?? [:] where key != "$ref" { merged[key] = own }
        return .object(merged)
    }

    /// Whether `value` passes the checks no edit but removal answers: type, const, choices,
    /// pattern and length.
    private func takes(_ value: JSONValue, _ schema: JSONValue) -> Bool {
        if let type = schema["type"], !Self.types(type).contains(where: { Self.has(value, $0) }) {
            return false
        }
        if let constant = schema["const"], !Self.same(value, constant) { return false }
        if let choices = schema["enum"]?.arrayValue,
            !choices.contains(where: { Self.same(value, $0) })
        {
            return false
        }
        guard let text = value.stringValue else { return true }
        if let least = schema["minLength"]?.intValue, text.count < least { return false }
        if let pattern = schema["pattern"]?.stringValue, !patterns.matches(text, pattern) {
            return false
        }
        return true
    }

    /// `value` brought back to the bound it crosses, the change recorded.
    private mutating func clamped(
        _ value: JSONValue, to schema: JSONValue, at path: [RepairChange.Step]
    ) -> JSONValue {
        guard let number = value.numberValue else { return value }
        let bound: JSONValue? =
            if let low = schema["minimum"], let least = low.numberValue, number < least {
                low
            } else if let high = schema["maximum"], let most = high.numberValue, number > most {
                high
            } else {
                nil
            }
        guard let bound, let limit = bound.numberValue else { return value }
        let set: JSONValue =
            value.intValue != nil && limit == limit.rounded() ? .integer(Int(limit)) : bound
        changes.append(RepairChange(path: path, outcome: .clamped(from: value, to: set)))
        return set
    }

    /// An object with each declared key fitted, each undeclared key removed where the object is
    /// closed, and nil where a key it requires, or a key a kept key depends on, is missing.
    private mutating func fitObject(
        _ fields: [String: JSONValue], to schema: JSONValue, at path: [RepairChange.Step]
    ) -> JSONValue? {
        let properties = schema["properties"]?.objectValue ?? [:]
        let closed = schema["additionalProperties"] == .bool(false)
        var kept: [String: JSONValue] = [:]
        for key in fields.keys.sorted() {
            guard let child = fields[key] else { continue }
            kept[key] = fitField(
                child, declared: properties[key], closed: closed, at: path + [.key(key)])
        }
        return Self.isWhole(kept, schema) ? .object(kept) : nil
    }

    /// Whether `kept` holds every key `schema` requires, and every key a key it holds depends on
    /// (`dependentRequired`).
    private static func isWhole(_ kept: [String: JSONValue], _ schema: JSONValue) -> Bool {
        let required = schema["required"]?.arrayValue?.compactMap(\.stringValue) ?? []
        let dependents = schema["dependentRequired"]?.objectValue ?? [:]
        let needed = dependents.filter { kept[$0.key] != nil }.values
            .flatMap { $0.arrayValue?.compactMap(\.stringValue) ?? [] }
        return (required + needed).allSatisfy { kept[$0] != nil }
    }

    /// One key's value as its object takes it: fitted to its declaration, kept as it is in an
    /// open object, or nil, the removal recorded, where it is undeclared in a closed one or does
    /// not fit.
    private mutating func fitField(
        _ child: JSONValue, declared: JSONValue?, closed: Bool, at path: [RepairChange.Step]
    ) -> JSONValue? {
        guard let declared else {
            if closed { changes.append(RepairChange(path: path, outcome: .removed)) }
            return closed ? nil : child
        }
        if let fitted = fit(child, to: declared, at: path) { return fitted }
        changes.append(RepairChange(path: path, outcome: .unset(was: child)))
        return nil
    }

    /// A list with each item fitted, an item that cannot be removed with its change recorded, a
    /// repeat removed where items are unique and any past the most allowed, and nil where fewer
    /// than the least allowed are left.
    private mutating func fitArray(
        _ items: [JSONValue], to schema: JSONValue, at path: [RepairChange.Step]
    ) -> JSONValue? {
        let unique = schema["uniqueItems"] == .bool(true)
        let most = schema["maxItems"]?.intValue ?? .max
        var kept: [JSONValue] = []
        for (index, item) in items.enumerated() {
            let fitted =
                schema["items"].map { fit(item, to: $0, at: path + [.index(index)]) } ?? item
            guard let fitted, kept.count < most, !(unique && kept.contains(fitted)) else {
                let change = RepairChange(
                    path: path + [.index(index)], outcome: .removedItem(was: item))
                changes.append(change)
                continue
            }
            kept.append(fitted)
        }
        return kept.count < schema["minItems"]?.intValue ?? 0 ? nil : .array(kept)
    }

    /// Whether `value` has `schema`'s shape as it is, with nothing to change.
    private func conforms(_ value: JSONValue, to schema: JSONValue) -> Bool {
        var probe = ShapeWalk(definitions: definitions, patterns: patterns)
        return probe.fit(value, to: schema, at: []) != nil && probe.changes.isEmpty
    }

    private static func types(_ type: JSONValue) -> [String] {
        type.arrayValue?.compactMap(\.stringValue) ?? [type.stringValue].compactMap { $0 }
    }

    /// Whether `value` is of the JSON Schema type `type`; a decimal with no fraction is an integer.
    private static func has(_ value: JSONValue, _ type: String) -> Bool {
        switch (type, value) {
        case ("object", .object), ("array", .array), ("string", .string), ("boolean", .bool),
            ("null", .null), ("number", .integer), ("number", .decimal), ("integer", .integer):
            true
        case ("integer", .decimal(let number)): number == number.rounded()
        default: false
        }
    }

    /// Whether two values are equal, numbers by their value whether written as integers or not.
    private static func same(_ first: JSONValue, _ second: JSONValue) -> Bool {
        if let one = first.numberValue, let other = second.numberValue { return one == other }
        return first == second
    }
}

/// The patterns a walk has compiled, shared by its probes.
final class PatternCache {
    private var compiled: [String: NSRegularExpression?] = [:]

    /// Whether `text` matches `pattern`; a pattern that does not compile judges nothing (design
    /// D2).
    func matches(_ text: String, _ pattern: String) -> Bool {
        guard let expression = expression(pattern) else { return true }
        let range = NSRange(text.startIndex..., in: text)
        return expression.firstMatch(in: text, range: range) != nil
    }

    private func expression(_ pattern: String) -> NSRegularExpression? {
        if let held = compiled[pattern] { return held }
        let made: NSRegularExpression?
        do {
            made = try NSRegularExpression(pattern: pattern)
        } catch {
            made = nil
        }
        compiled[pattern] = .some(made)
        return made
    }
}
