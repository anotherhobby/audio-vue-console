import ConsoleCore
import SwiftUI

/// A keyed block as a collapsed group with one row per key the cards pick, the keys already set
/// first. A row's three fields are drafts, checked before a change is made, so a refused span is
/// never stored and says why beside its row (`meter-scales-editor`, design D4 and D5).
struct KeyedBlockRows: View {
    let declaration: SettingDeclaration
    /// The keys the cards pick, in the order the block lists them (`card-settings`).
    let block: KeyedBlock
    let keys: [KeyedBlock.Key]
    let value: SettingValue
    /// Writes one key's span on the selected cards; nil where the scene is read-only.
    let set: ((String, KeyedBlock.Span) -> Void)?

    /// What a row's three fields hold as typed.
    private struct Draft: Equatable {
        var lo = ""
        var hi = ""
        var anchor = ""
    }

    @State private var drafts: [String: Draft] = [:]
    @State private var refusals: [String: String] = [:]

    var body: some View {
        DisclosureGroup(declaration.label) {
            ForEach(orderedKeys) { row($0) }
            if case .mixed = value {
                Text(
                    "The selected cards' scales differ. A change applies to each card's own scale."
                )
                .font(.caption).foregroundStyle(.secondary)
            }
        }
        .help(declaration.help)
        .onAppear(perform: reseed)
        .onChange(of: value.shown) { reseed() }
    }

    /// The keys the block sets come first, in the schema's order, then the rest in theirs.
    private var orderedKeys: [KeyedBlock.Key] {
        let set = keys.filter { isSet($0.name) }
        return set + keys.filter { !isSet($0.name) }
    }

    /// A number as a row's field shows it, blank where unset.
    private static func text(_ number: Double?) -> String {
        number.map(Self.number) ?? ""
    }

    /// A number as a person reads it: whole numbers without a decimal point.
    private static func number(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(value)
    }

    private func isSet(_ name: String) -> Bool {
        let span = KeyedBlock.span(of: name, in: value.shown)
        return span.lo != nil || span.hi != nil || span.anchor != nil
    }

    private func reseed() {
        drafts = Dictionary(
            uniqueKeysWithValues: keys.map { key in
                let span = KeyedBlock.span(of: key.name, in: value.shown)
                return (
                    key.name,
                    Draft(
                        lo: Self.text(span.lo), hi: Self.text(span.hi),
                        anchor: Self.text(span.anchor))
                )
            })
        refusals = [:]
    }

    private func row(_ key: KeyedBlock.Key) -> some View {
        VStack(alignment: .leading, spacing: SceneMetrics.settingSpacing) {
            LabeledContent {
                HStack(spacing: SceneMetrics.settingSpacing) {
                    field("Low", key, \.lo, prompt: "Low")
                    field("High", key, \.hi, prompt: "High")
                    field("Anchor", key, \.anchor, prompt: key.anchor.map(Self.number) ?? "Product")
                }
            } label: {
                VStack(alignment: .leading) {
                    Text(key.label)
                    if key.range.count == 2 {
                        Text(
                            "\(Self.number(key.range[0])) to \(Self.number(key.range[1])) \(key.unit)"
                        )
                        .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if let refusal = refusals[key.name] {
                Label(refusal, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
        .disabled(set == nil)
    }

    private func field(
        _ label: String, _ key: KeyedBlock.Key, _ part: WritableKeyPath<Draft, String>,
        prompt: String
    ) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            TextField(label, text: binding(key.name, part), prompt: Text(prompt))
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .frame(width: SceneMetrics.numberFieldWidth)
                .onSubmit { commit(key) }
        }
    }

    private func binding(_ name: String, _ part: WritableKeyPath<Draft, String>) -> Binding<String>
    {
        Binding(
            get: { drafts[name, default: Draft()][keyPath: part] },
            set: { drafts[name, default: Draft()][keyPath: part] = $0 })
    }

    /// Checks the row's typed span and, where it is valid, writes it. A refused span is shown beside
    /// the row and not written; a blank row clears the key.
    private func commit(_ key: KeyedBlock.Key) {
        let draft = drafts[key.name] ?? Draft()
        let typed = [draft.lo, draft.hi, draft.anchor]
        guard typed.allSatisfy({ $0.isBlank || Double($0.trimmed) != nil }) else {
            refusals[key.name] = "not a number"
            return
        }
        let span = KeyedBlock.Span(
            lo: Double(draft.lo.trimmed), hi: Double(draft.hi.trimmed),
            anchor: Double(draft.anchor.trimmed))
        switch block.edit(nil, key: key.name, lo: span.lo, hi: span.hi, anchor: span.anchor) {
        case .failure(let refusal):
            refusals[key.name] = refusal.text
        case .success:
            refusals[key.name] = nil
            set?(key.name, span)
        }
    }
}

extension String {
    fileprivate var trimmed: String { trimmingCharacters(in: .whitespaces) }
    fileprivate var isBlank: Bool { trimmed.isEmpty }
}
