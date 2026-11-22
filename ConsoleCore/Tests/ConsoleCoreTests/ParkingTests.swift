import Foundation
import Testing

@testable import ConsoleCore

/// `card-parking`: cards dragged off the panel, held beside it, and brought back.
struct ParkingTests {
    private static let pane = testPane

    private static func content(_ onGrid: [LayoutCard], parked: [LayoutCard] = []) throws
        -> SceneContent
    {
        SceneContent(layout: try layout(onGrid), parked: parked)
    }

    private static func ids(_ cards: LayoutCard...) -> Set<UUID> {
        Set(cards.map(\.id))
    }

    // MARK: What parked cards reach

    @Test func aParkedCardMarksTheSceneUnsavedAndIsNeverWritten() throws {
        let document = SceneDocument(
            id: "s", name: "S", builtIn: false, fixed: false,
            doc: try JSONDecoder().decode(
                JSONValue.self,
                from: Data(#"{"cards": [{"card": "logo", "colspan": 8, "rowspan": 4}]}"#.utf8)))
        let laid = try LaidOutScene(document, panel: CellSize(cols: 64, rows: 36))
        var draft = Draft(laid)
        draft.content = try laid.content.dragging(
            Set(laid.layout.cards.map(\.id)), by: CellOffset(cols: 0, rows: 40), within: Self.pane)
        #expect(draft.content.parked.count == 1)
        #expect(draft.isUnsaved)
        #expect(draft.doc["cards"]?.arrayValue?.isEmpty == true)
    }

    @Test func aCardParkedPastThePanelsLastColumnIsNotTooWide() throws {
        let document = SceneDocument(
            id: "s", name: "S", builtIn: false, fixed: false,
            doc: try JSONDecoder().decode(JSONValue.self, from: Data(#"{"cards": []}"#.utf8)))
        let laid = try LaidOutScene(document, panel: CellSize(cols: 64, rows: 36))
        let content = SceneContent(
            layout: laid.layout, parked: [card("meter", rect(70, 0, 10, 4))])
        #expect(!laid.isTooWide(content))
    }

    @Test func theRefusalsSayWhy() {
        #expect(
            LayoutRefusal.noRoomOffPanel.description == "There's no room for that off the panel.")
        #expect(
            LayoutRefusal.dragToCross.description
                == "Drag a card to move it onto or off the panel.")
        #expect(
            LayoutRefusal.parkedCannotGroup.description
                == "Move these cards onto the panel to group them.")
    }

    // MARK: Parking

    @Test func startingToCrossTheBottomEdge() throws {
        let meter = card("meter", rect(0, 32, 10, 4))
        let parked = try Self.content([meter]).dragging(
            Self.ids(meter), by: CellOffset(cols: 0, rows: 1), within: Self.pane)
        #expect(parked.layout.cards.isEmpty)
        #expect(parked.parked.map(\.cells) == [rect(0, 36, 10, 4)])
    }

    @Test func crossingACornerTakesTheLeastPush() throws {
        let meter = card("meter", rect(54, 32, 10, 4))
        let parked = try Self.content([meter]).dragging(
            Self.ids(meter), by: CellOffset(cols: 2, rows: 1), within: Self.pane)
        #expect(parked.parked.map(\.cells) == [rect(56, 36, 10, 4)])
    }

    @Test func aGroupParksAsOne() throws {
        let left = card("a", rect(44, 0, 10, 4), group: "g")
        let right = card("b", rect(54, 0, 10, 4), group: "g")
        let parked = try Self.content([left, right]).dragging(
            Self.ids(right), by: CellOffset(cols: 3, rows: 0), within: Self.pane)
        #expect(parked.layout.cards.isEmpty)
        #expect(parked.parked.map(\.cells) == [rect(64, 0, 10, 4), rect(74, 0, 10, 4)])
        #expect(parked.parked.allSatisfy { $0.group == "g" })
    }

    @Test func aMixedSelectionParksAsOneBlock() throws {
        let onGrid = card("a", rect(0, 30, 10, 4))
        let aside = card("b", rect(0, 40, 10, 4))
        let parked = try Self.content([onGrid], parked: [aside]).dragging(
            Self.ids(onGrid, aside), by: CellOffset(cols: 0, rows: 3), within: Self.pane)
        #expect(Set(parked.parked.map(\.cells)) == [rect(0, 36, 10, 4), rect(0, 46, 10, 4)])
    }

    @Test func aDragBeyondThePaneStopsAtItsEdge() throws {
        let aside = card("meter", rect(0, 40, 10, 4))
        let moved = try Self.content([], parked: [aside]).dragging(
            Self.ids(aside), by: CellOffset(cols: 0, rows: 100), within: Self.pane)
        #expect(moved.parked.map(\.cells) == [rect(0, 52, 10, 4)])
    }

    // MARK: Returning

    @Test func returningToFreeCellsKeepsTheSettings() throws {
        var aside = card("meter", rect(0, 40, 10, 4))
        aside.settings = ["style": .string("segments")]
        let returned = try Self.content([], parked: [aside]).dragging(
            Self.ids(aside), by: CellOffset(cols: 5, rows: -30), within: Self.pane)
        #expect(returned.parked.isEmpty)
        #expect(returned.layout.cards.map(\.cells) == [rect(5, 10, 10, 4)])
        #expect(returned.layout.cards.first?.settings == aside.settings)
    }

    @Test func returningHalfOnStaysParked() throws {
        let aside = card("meter", rect(0, 40, 10, 4))
        let moved = try Self.content([], parked: [aside]).dragging(
            Self.ids(aside), by: CellOffset(cols: 0, rows: -6), within: Self.pane)
        #expect(moved.layout.cards.isEmpty)
        #expect(moved.parked.map(\.cells) == [rect(0, 36, 10, 4)])
    }

    @Test func returningOntoACardIsRefused() throws {
        let aside = card("meter", rect(0, 40, 10, 4))
        let content = try Self.content([card("rta", rect(0, 0, 10, 4))], parked: [aside])
        #expect(throws: LayoutRefusal.spaceTaken) {
            try content.dragging(
                Self.ids(aside), by: CellOffset(cols: 0, rows: -40), within: Self.pane)
        }
    }

    // MARK: Refused parking

    @Test func parkingOntoAParkedCardIsRefused() throws {
        let onGrid = card("rta", rect(20, 32, 10, 4))
        let content = try Self.content([onGrid], parked: [card("meter", rect(0, 40, 10, 4))])
        #expect(throws: LayoutRefusal.spaceTaken) {
            try content.dragging(
                Self.ids(onGrid), by: CellOffset(cols: -20, rows: 8), within: Self.pane)
        }
    }

    @Test func noRoomOffThePanel() throws {
        let meter = card("meter", rect(54, 0, 10, 4))
        let content = try Self.content([meter])
        #expect(throws: LayoutRefusal.noRoomOffPanel) {
            try content.dragging(
                Self.ids(meter), by: CellOffset(cols: 5, rows: 0), within: rect(0, -10, 64, 56))
        }
    }

    @Test func tooLittleRoomOffThePanel() throws {
        let meter = card("meter", rect(54, 0, 10, 4))
        let content = try Self.content([meter])
        #expect(throws: LayoutRefusal.noRoomOffPanel) {
            try content.dragging(
                Self.ids(meter), by: CellOffset(cols: 5, rows: 0), within: rect(0, 0, 67, 36))
        }
    }

    // MARK: Nudges

    @Test func aNudgeTowardsThePanelIsRefused() throws {
        let aside = card("meter", rect(0, 36, 10, 4))
        let content = try Self.content([], parked: [aside])
        #expect(throws: LayoutRefusal.dragToCross) {
            try content.nudging(
                Self.ids(aside), by: CellOffset(cols: 0, rows: -1), within: Self.pane)
        }
    }

    @Test func aNudgeOutOfThePaneIsRefused() throws {
        let aside = card("meter", rect(0, 52, 10, 4))
        let content = try Self.content([], parked: [aside])
        #expect(throws: LayoutRefusal.dragToCross) {
            try content.nudging(
                Self.ids(aside), by: CellOffset(cols: 0, rows: 1), within: Self.pane)
        }
    }

    @Test func aNudgeOntoAParkedCardIsRefused() throws {
        let aside = card("meter", rect(0, 40, 10, 4))
        let content = try Self.content([], parked: [aside, card("rta", rect(10, 40, 10, 4))])
        #expect(throws: LayoutRefusal.spaceTaken) {
            try content.nudging(
                Self.ids(aside), by: CellOffset(cols: 1, rows: 0), within: Self.pane)
        }
    }

    @Test func aParkedCardIsNudgedFreely() throws {
        let aside = card("meter", rect(0, 40, 10, 4))
        let moved = try Self.content([], parked: [aside]).nudging(
            Self.ids(aside), by: CellOffset(cols: 4, rows: 0), within: Self.pane)
        #expect(moved.parked.map(\.cells) == [rect(4, 40, 10, 4)])
    }

    @Test func aNudgeOnTheGridStillStopsAtItsEdge() throws {
        let meter = card("meter", rect(52, 0, 10, 4))
        let moved = try Self.content([meter]).nudging(
            Self.ids(meter), by: CellOffset(cols: 4, rows: 0), within: Self.pane)
        #expect(moved.layout.cards.map(\.cells) == [rect(54, 0, 10, 4)])
        #expect(moved.parked.isEmpty)
    }

    // MARK: Wording

    /// `card-parking`, "The canvas says how many cards are parked": "Two parked cards".
    @Test func theCanvasAndGallerySayHowManyAreParked() {
        #expect(
            ParkingText.canvas(2)
                == "2 cards are off the panel. Move them onto the panel to save, apply or duplicate "
                + "this scene.")
        #expect(ParkingText.canvas(1).hasPrefix("1 card is off the panel. Move it onto the panel"))
        #expect(ParkingText.note(2) == "2 cards off the panel")
    }
}
