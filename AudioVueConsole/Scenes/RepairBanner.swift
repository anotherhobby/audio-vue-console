import ConsoleCore
import SwiftUI

/// The editor's offer to repair a scene the host's schema no longer takes (`scene-repair`, design
/// D8): how many settings, every change in a popover, and Repair where the scene may be edited and
/// a repair can be made. Nothing changes until Repair is chosen.
struct RepairBanner: View {
    let repair: SceneRepair
    /// Whether the editor may change the scene: a read-only one offers no Repair.
    let editable: Bool
    let onRepair: () -> Void
    @State private var showsChanges = false

    var body: some View {
        HStack {
            Label(RepairText.summary(repair), systemImage: "wrench.and.screwdriver")
            Spacer()
            if repair.canRepair {
                Button("Show Changes") { showsChanges = true }
                    .popover(isPresented: $showsChanges, arrowEdge: .bottom) { changes }
                if editable { Button("Repair", action: onRepair) }
            }
        }
        .font(.callout)
        .padding(.horizontal)
        .padding(.vertical, SceneMetrics.tilePadding)
        .background(.bar)
    }

    private var changes: some View {
        VStack(alignment: .leading, spacing: SceneMetrics.settingSpacing) {
            ForEach(Array(repair.lines.enumerated()), id: \.offset) { Text($0.element) }
        }
        .textSelection(.enabled)
        .padding()
    }
}

/// What the repair banner and the gallery say of a scene that needs a repair.
enum RepairText {
    /// The gallery's note.
    static let note = "Holds settings this panel no longer takes"

    static func summary(_ repair: SceneRepair) -> String {
        guard repair.canRepair else {
            return "This scene holds no card this panel has, so it cannot be repaired."
        }
        let count = repair.changes.count
        let settings = count == 1 ? "1 setting" : "\(count) settings"
        return "This scene holds \(settings) this panel no longer takes. Repair removes or "
            + "corrects them, and Save keeps the result."
    }
}

private enum RepairPreview {
    static func repair(_ doc: JSONValue) -> SceneRepair? {
        SceneShape(schema: schema).repair(of: doc)
    }

    private static func scene(analysis: [String: JSONValue], card: String) -> JSONValue {
        .object([
            "analysis": .object(analysis), "cards": .array([.object(["card": .string(card)])]),
        ])
    }

    /// Enough of the host's schema to hold an analysis block with one setting and a card.
    private static let schema: JSONValue = .object([
        "$defs": .object([
            "scene": .object([
                "type": .string("object"), "additionalProperties": .bool(false),
                "required": .array([.string("cards")]),
                "properties": .object([
                    "analysis": .object([
                        "type": .string("object"), "additionalProperties": .bool(false),
                        "properties": .object(["capture_rate": .object([:])]),
                    ]),
                    "cards": .object([
                        "type": .string("array"), "minItems": .integer(1),
                        "items": .object([
                            "type": .string("object"), "required": .array([.string("card")]),
                            "properties": .object([
                                "card": .object(["enum": .array([.string("rta_bars")])])
                            ]),
                        ]),
                    ]),
                ]),
            ])
        ])
    ])

    static let stale = repair(
        scene(
            analysis: ["rta_hold_s": .integer(1), "rta_weighting": .string("F")], card: "rta_bars"))
    static let hopeless = repair(scene(analysis: [:], card: "spectrum_old"))
}

#Preview("Repair offered") {
    if let repair = RepairPreview.stale {
        RepairBanner(repair: repair, editable: true) {}.frame(width: 720)
    }
}

#Preview("Read-only scene") {
    if let repair = RepairPreview.stale {
        RepairBanner(repair: repair, editable: false) {}.frame(width: 720)
    }
}

#Preview("No card left") {
    if let repair = RepairPreview.hopeless {
        RepairBanner(repair: repair, editable: true) {}.frame(width: 720)
    }
}
