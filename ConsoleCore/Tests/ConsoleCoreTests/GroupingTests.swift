import Testing

@testable import ConsoleCore

/// `scene-layout`, "Cards group only when they tile a rectangle", "A new group replaces the groups
/// it takes in", "A group moves and is removed as one" and "Ungrouping leaves the cards in place".
struct GroupingTests {
    @Test func twoCardsThatTileARectangle() throws {
        let pair = [card("a", rect(0, 0, 4, 4)), card("b", rect(4, 0, 4, 4))]
        let grouped = try layout(pair).grouping(Set(pair.map(\.id)))
        #expect(grouped.cards.map(\.group) == ["group-1", "group-1"])
    }

    @Test func cardsThatLeaveAHole() throws {
        let three = [
            card("a", rect(0, 0, 4, 4)), card("b", rect(4, 0, 4, 4)), card("c", rect(0, 4, 4, 4)),
        ]
        #expect(throws: LayoutRefusal.notARectangle) {
            try layout(three).grouping(Set(three.map(\.id)))
        }
    }

    @Test func anotherCardInside() throws {
        let corners = [card("a", rect(0, 0, 4, 4)), card("b", rect(4, 4, 4, 4))]
        let scene = try layout(corners + [card("inside", rect(4, 0, 4, 4))])
        #expect(throws: LayoutRefusal.cardInTheWay) { try scene.grouping(Set(corners.map(\.id))) }
    }

    @Test func oneCard() throws {
        let alone = card("a", rect(0, 0, 4, 4))
        #expect(throws: LayoutRefusal.tooFewCards) { try layout([alone]).grouping([alone.id]) }
    }

    @Test func aGroupAlready() throws {
        let pair = [
            card("a", rect(0, 0, 4, 4), group: "pair"), card("b", rect(4, 0, 4, 4), group: "pair"),
        ]
        #expect(throws: LayoutRefusal.alreadyAGroup) {
            try layout(pair).grouping([pair[0].id])
        }
    }

    @Test func cardsThatHappenToTileARectangleStayUngrouped() throws {
        let scene = try layout([card("a", rect(0, 0, 4, 4)), card("b", rect(4, 0, 4, 4))])
        #expect(scene.groups.isEmpty)
    }

    @Test func aGroupAndALooseCardBecomeOneNewGroup() throws {
        let pair = [
            card("a", rect(0, 0, 4, 4), group: "pair"), card("b", rect(4, 0, 4, 4), group: "pair"),
        ]
        let loose = card("c", rect(8, 0, 4, 4))
        let grouped = try layout(pair + [loose]).grouping([pair[0].id, loose.id])
        #expect(Set(grouped.cards.map(\.group)) == ["group-1"])
        #expect(grouped.groups["pair"] == nil)
    }

    @Test func aNewGroupTakesTheLowestFreeNumber() throws {
        let taken = [
            card("a", rect(0, 0, 4, 4), group: "group-1"),
            card("b", rect(4, 0, 4, 4), group: "group-1"),
        ]
        let pair = [card("c", rect(0, 10, 4, 4)), card("d", rect(4, 10, 4, 4))]
        let grouped = try layout(taken + pair).grouping(Set(pair.map(\.id)))
        #expect(grouped.card(pair[0].id)?.group == "group-2")
    }

    @Test func ungroupingLeavesTheCardsInPlace() throws {
        let pair = [
            card("a", rect(0, 0, 4, 4), group: "pair"), card("b", rect(4, 0, 4, 4), group: "pair"),
        ]
        let ungrouped = try layout(pair).ungrouping([pair[1].id])
        #expect(ungrouped.cards.map(\.group) == [nil, nil])
        #expect(ungrouped.cards.map(\.cells) == pair.map(\.cells))
    }

    @Test func removingAMemberRemovesTheGroup() throws {
        let pair = [
            card("a", rect(0, 0, 4, 4), group: "pair"), card("b", rect(4, 0, 4, 4), group: "pair"),
        ]
        let loose = card("c", rect(20, 0, 4, 4))
        let removed = try layout(pair + [loose]).removing([pair[0].id])
        #expect(removed.cards == [loose])
    }
}
