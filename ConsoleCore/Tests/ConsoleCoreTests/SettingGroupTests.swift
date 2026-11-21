import Foundation
import Testing

@testable import ConsoleCore

/// `card-settings`: shared settings across a selection, the values and notes the inspector shows,
/// and the values it writes (design D3 to D5), read from the trimmed copy of audio-vue's schema.
struct SettingGroupTests {
    private static func facts() throws -> SchemaFacts {
        let file = URL(filePath: #filePath).deletingLastPathComponent()
            .appending(path: "Fixtures/schema-trimmed.json")
        let schema = try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: file))
        return try #require(SchemaFacts(schema: schema))
    }

    private static func groups() throws -> [String: SettingGroup] {
        try facts().settings
    }

    @Test func aColourOfTheSameNameIsSharedSinceItTakesTheSameRole() throws {
        let shared = try Self.shared("rta_bars", "loudness_scope")
        #expect(shared.contains("grid_minor_color"))
        #expect(!shared.contains("grid_major_color"))
        #expect(!shared.contains("band1_color"))
    }

    // MARK: Settings with no effect (`scene-settings`, design D9)

    private static func meter(_ settings: [String: JSONValue]) -> LayoutCard {
        LayoutCard(
            kind: "meter", cells: CellRect(col: 0, row: 0, cols: 8, rows: 6), settings: settings)
    }

    @Test func aZonedFieldLeavesTheBarColoursUnused() throws {
        let groups = try Self.groups()
        let crest = Self.meter(["field": .string("crest_peak")])
        let reason = SettingGroup.unusedReason(
            of: "bar_body_color", across: [crest], declaredBy: groups)
        #expect(reason?.contains("thresholds") == true)
        let plain = Self.meter(["field": .string("crest_rms")])
        #expect(
            SettingGroup.unusedReason(of: "bar_body_color", across: [plain], declaredBy: groups)
                == nil)
    }

    @Test func oneCardWithAnEffectKeepsTheSettingInUse() throws {
        let groups = try Self.groups()
        let cards = [
            Self.meter(["field": .string("crest_peak")]),
            Self.meter(["field": .string("crest_rms")]),
        ]
        #expect(
            SettingGroup.unusedReason(of: "bar_tip_color", across: cards, declaredBy: groups) == nil
        )
    }

    @Test func aTickLeavesOnlyTheBodyUnused() throws {
        let groups = try Self.groups()
        let tick = [Self.meter(["style": .string("tick")])]
        #expect(
            SettingGroup.unusedReason(of: "bar_body_color", across: tick, declaredBy: groups) != nil
        )
        #expect(
            SettingGroup.unusedReason(of: "bar_tip_color", across: tick, declaredBy: groups) == nil)
    }

    @Test func theRTAsMajorLinesNeedBothSettingsOff() throws {
        let groups = try Self.groups()
        let card = { (settings: [String: JSONValue]) in
            LayoutCard(
                kind: "rta_bars", cells: CellRect(col: 0, row: 0, cols: 8, rows: 6),
                settings: settings)
        }
        let gridOff = [card(["major_grid": .bool(false)])]
        #expect(
            SettingGroup.unusedReason(of: "grid_major_color", across: gridOff, declaredBy: groups)
                == nil
        )
        let bothOff = [card(["major_grid": .bool(false), "show_labels": .bool(false)])]
        #expect(
            SettingGroup.unusedReason(of: "grid_major_color", across: bothOff, declaredBy: groups)
                != nil
        )
    }

    // MARK: Scene blocks (`scene-settings`, task 2.4)

    @Test func theRTAWeightingIsNeverOffItsStandard() throws {
        let weighting = try #require(try Self.facts().block("analysis")?.settings["rta_weighting"])
        guard case .choice(let choices) = weighting.shape else {
            Issue.record("rta_weighting is not a choice")
            return
        }
        #expect(choices == [.string("F"), .string("S"), .string("I")])
        #expect(choices.allSatisfy { weighting.note(for: $0) == nil })
        #expect(weighting.note(for: weighting.defaultValue) == nil)
    }

    @Test func theCaptureRateHasNoNoteOfItsOwn() throws {
        let rate = try #require(try Self.facts().block("analysis")?.settings["capture_rate"])
        #expect(rate.note(for: .integer(44_100)) == nil)
        #expect(rate.note(for: nil) == nil)
    }

    private static func declaration(_ kind: String, _ key: String) throws -> SettingDeclaration {
        try #require(try groups()[kind]?[key])
    }

    private static func shared(_ kinds: String...) throws -> [String] {
        let groups = try groups()
        return SettingGroup.shared(kinds.compactMap { groups[$0] }).settings.map(\.key)
    }

    // MARK: Shared settings (design D3)

    @Test func aGaugeAndAPeakMeterShareTheirReadoutScaleAndTheColoursBothDraw() throws {
        #expect(
            try Self.shared("dynamics_gauge", "peak_rms") == [
                "show_readout", "show_scale", "tick_color", "scale_color", "unit_color",
                "notice_color",
            ])
    }

    @Test func sharedSettingsAreLabelledByTheFirstCard() throws {
        let groups = try Self.groups()
        let gaugeFirst = SettingGroup.shared(
            [groups["dynamics_gauge"], groups["peak_rms"]].compactMap { $0 })
        let peakFirst = SettingGroup.shared(
            [groups["peak_rms"], groups["dynamics_gauge"]].compactMap { $0 })
        #expect(gaugeFirst["show_scale"]?.label == groups["dynamics_gauge"]?["show_scale"]?.label)
        #expect(peakFirst["show_scale"]?.label == "Scale and labels")
    }

    @Test func aFloorOfAnotherRangeIsNotShared() throws {
        #expect(try !Self.shared("peak_rms", "rta_bars").contains("floor_db"))
    }

    @Test func cardsOfOneKindShareEverySetting() throws {
        #expect(try Self.shared("peak_rms", "peak_rms_vertical").count == 15)
    }

    @Test func nothingSelectedSharesNothing() {
        #expect(SettingGroup.shared([]).settings.isEmpty)
    }

    // MARK: Values across a selection

    @Test func differingValuesAreMixed() throws {
        let groups = try Self.groups()
        let first = LayoutCard(
            kind: "peak_rms", cells: rect(0, 0, 4, 4), settings: ["hold_s": .integer(2)])
        let second = LayoutCard(kind: "peak_rms", cells: rect(4, 0, 4, 4))
        let value = SettingGroup.value(of: "hold_s", across: [first, second], declaredBy: groups)
        #expect(value == .mixed(isSet: true))
    }

    @Test func equalValuesAreTheSame() throws {
        let groups = try Self.groups()
        let first = LayoutCard(
            kind: "peak_rms", cells: rect(0, 0, 4, 4), settings: ["hold_s": .decimal(1.5)])
        let second = LayoutCard(kind: "peak_rms", cells: rect(4, 0, 4, 4))
        let value = SettingGroup.value(of: "hold_s", across: [first, second], declaredBy: groups)
        #expect(value == .same(.decimal(1.5), isSet: true))
        let unset = SettingGroup.value(of: "hold_s", across: [second], declaredBy: groups)
        #expect(unset == .same(.decimal(1.5), isSet: false))
    }

    @Test func anUnsetCardColourHasNoValue() throws {
        let bars = LayoutCard(kind: "rta_bars", cells: rect(0, 0, 4, 4))
        let value = SettingGroup.value(
            of: "grid_major_color", across: [bars], declaredBy: try Self.groups())
        #expect(value == .same(nil, isSet: false))
    }

    // MARK: Effective values and notes (design D5)

    @Test func anUnsetAlignmentReadsSMPTEAsTheDefault() throws {
        let alignment = try Self.declaration("vu_meter", "alignment")
        #expect(alignment.effectiveValue(in: [:]) == .string("smpte"))
        #expect(alignment.note(for: .string("smpte")) == nil)
    }

    @Test func aCustomAlignmentIsOffItsStandard() throws {
        let alignment = try Self.declaration("vu_meter", "alignment")
        #expect(alignment.note(for: .string("custom")) == .offStandard("ITU-R BS.1726"))
        #expect(alignment.note(for: .string("ebu")) == nil)
    }

    @Test func aSettingNoStandardGovernsIsNeverFlagged() throws {
        let reference = try Self.declaration("vu_meter", "reference_dbfs")
        #expect(reference.note(for: .integer(-12)) == nil)
        let hold = try Self.declaration("peak_rms", "hold_s")
        #expect(hold.note(for: .integer(9)) == nil)
    }

    @Test func aCardsChainSettingHasNoNote() throws {
        let channel = try Self.declaration("vu_meter", "channel")
        #expect(channel.settingClass == "chain")
        #expect(channel.note(for: .string("right")) == nil)
    }

    @Test func aSelectionIsFlaggedWhereAnyCardIsOffItsStandard() throws {
        let custom = LayoutCard(
            kind: "vu_meter", cells: rect(0, 0, 4, 4), settings: ["alignment": .string("custom")])
        let standard = LayoutCard(kind: "vu_meter", cells: rect(4, 0, 4, 4))
        let groups = try Self.groups()
        #expect(
            SettingGroup.note(of: "alignment", across: [standard, custom], declaredBy: groups)
                == .offStandard("ITU-R BS.1726"))
        #expect(SettingGroup.note(of: "alignment", across: [standard], declaredBy: groups) == nil)
    }

    // MARK: Writing values (design D4)

    @Test func aTypedNumberIsKeptToItsRange() throws {
        let lampHold = try Self.declaration("vu_meter", "lamp_hold_s")
        #expect(lampHold.written(9) == .integer(5))
        #expect(lampHold.written(0) == .decimal(0.15))
    }

    @Test func aNumberIsRoundedToItsStepFromTheMinimum() {
        let weight = SettingDeclaration(
            key: "w", label: "W", shape: .number(.init(minimum: 1, maximum: 8, step: 1)))
        #expect(weight.written(2.4) == .integer(2))
        #expect(weight.stepped(.integer(2), by: 1) == .integer(3))
    }

    @Test func aWholeNumberIsWrittenAsAnInteger() throws {
        let floor = try Self.declaration("peak_rms", "floor_db")
        #expect(floor.written(-80) == .integer(-80))
        #expect(floor.written(-83) == .integer(-80))
        let lampHold = try Self.declaration("vu_meter", "lamp_hold_s")
        #expect(lampHold.written(0.9) == .decimal(0.9))
        let weight = try Self.declaration("rta_bars", "major_weight_px")
        #expect(weight.written(4) == .integer(4))
    }

    @Test func steppingLeavesNoBinaryFraction() throws {
        let lampHold = try Self.declaration("vu_meter", "lamp_hold_s")
        #expect(lampHold.stepped(.decimal(0.15), by: 3) == .decimal(0.3))
        #expect(lampHold.stepped(nil, by: -1) == .decimal(0.85))
    }

    @Test func aNonNumberIsNotWritten() throws {
        let alignment = try Self.declaration("vu_meter", "alignment")
        #expect(alignment.written(1) == nil)
        #expect(alignment.stepped(.string("ebu"), by: 1) == nil)
        let stepless = SettingDeclaration(key: "x", label: "X", shape: .number(.init()))
        #expect(stepless.stepped(.integer(1), by: 1) == nil)
        #expect(stepless.written(1.25) == .decimal(1.25))
    }
}
