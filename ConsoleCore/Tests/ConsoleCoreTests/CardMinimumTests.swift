import Foundation
import Testing

@testable import ConsoleCore

/// `card-minimum`: a `minimum` answer decoded, its whole size picked, and its floor read (design D1).
struct CardMinimumTests {
    private static func answer(_ json: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
    }

    /// "The fewest cells".
    @Test func theWholeSizeHasTheFewestCells() {
        let minimum = CardMinimum(whole: [8: 9, 10: 7, 12: 6], readable: [8: 5])
        #expect(minimum.wholeSize == CellSize(cols: 10, rows: 7))
    }

    /// "A tie".
    @Test func aTieTakesTheNarrower() {
        let minimum = CardMinimum(whole: [8: 9, 9: 8], readable: [:])
        #expect(minimum.wholeSize == CellSize(cols: 8, rows: 9))
    }

    /// "Never whole".
    @Test func neverWholeTakesTheSmallestReadable() {
        let minimum = CardMinimum(whole: [:], readable: [10: 6, 12: 5])
        #expect(minimum.wholeSize == CellSize(cols: 10, rows: 6))
    }

    @Test func neitherLeavesTheDeclaredMinimum() {
        #expect(CardMinimum(whole: [:], readable: [:]).wholeSize == nil)
    }

    /// "A narrower card needs more rows" and "A width left out".
    @Test func theFloorDependsOnTheWidth() {
        let floor = CardMinimum(whole: [:], readable: [17: 10, 20: 8]).floor
        #expect(floor.rows(at: 20) == 8)
        #expect(floor.rows(at: 17) == 10)
        #expect(floor.rows(at: 16) == nil)
        #expect(floor.rows(at: 18) == nil)
    }

    @Test func theDeclaredFloorAdmitsEveryWidthFromItsColumns() {
        let floor = MinimumFloor.declared(CellSize(cols: 8, rows: 6))
        #expect(floor.rows(at: 7) == nil)
        #expect(floor.rows(at: 8) == 6 && floor.rows(at: 40) == 6)
    }

    @Test func anAnswerDecodes() throws {
        let header = try Self.answer(
            #"{"ok": true, "whole": [[10, 8], [12, 7]], "readable": [[8, 6], [10, 5]]}"#)
        let minimum = try #require(CardMinimum(answer: header))
        #expect(minimum.whole == [10: 8, 12: 7])
        #expect(minimum.readable == [8: 6, 10: 5])
    }

    @Test func aRefusalOrAMalformedAnswerIsNoAnswer() throws {
        #expect(CardMinimum(answer: try Self.answer(#"{"ok": false, "refused": "no"}"#)) == nil)
        #expect(CardMinimum(answer: try Self.answer(#"{"ok": true, "whole": []}"#)) == nil)
        #expect(
            CardMinimum(answer: try Self.answer(#"{"ok": true, "whole": [[1]], "readable": []}"#))
                == nil)
    }
}
