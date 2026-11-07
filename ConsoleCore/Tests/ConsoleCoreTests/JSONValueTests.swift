import Foundation
import OpenAPIRuntime
import Testing

@testable import ConsoleCore

/// Design D6: a document passes through the app as the host wrote it.
struct JSONValueTests {
    /// A scene as a store holds one, keys sorted as `encoded()` writes them.
    private static let scene =
        ##"{"backdrop":{"angle":120,"blur":24,"gradient":["#2a1a6e","#0e4a6a"]},"##
        + ##""cards":[{"card":"rta_bars","col":0,"colspan":48,"params":{"ceiling_db":0.5,"##
        + ##""floor_db":-80.25,"major_color":"#2a3550","show":true},"row":0,"rowspan":36}],"##
        + ##""glass":{"opacity":0.6},"grid":{"cols":96,"rows":36},"name":"RTA","plate":null}"##

    private static func decoded(_ text: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
    }

    private static func text(of value: JSONValue) throws -> String? {
        String(bytes: try value.encoded(), encoding: .utf8)
    }

    @Test func aSceneRoundTripsByteForByte() throws {
        #expect(try Self.text(of: Self.decoded(Self.scene)) == Self.scene)
    }

    @Test func anIntegerStaysAnInteger() throws {
        let value = try Self.decoded(#"{"col":48}"#)
        #expect(value["col"] == .integer(48))
        #expect(try Self.text(of: value) == #"{"col":48}"#)
    }

    @Test func aFractionIsADecimal() throws {
        #expect(try Self.decoded("[0.6, -80.25]") == .array([.decimal(0.6), .decimal(-80.25)]))
    }

    @Test func aFlagIsNotANumber() throws {
        #expect(try Self.decoded("[true, 1]") == .array([.bool(true), .integer(1)]))
    }

    @Test func theGeneratedContainerReadsTheSame() throws {
        let container = try JSONDecoder().decode(
            OpenAPIObjectContainer.self, from: Data(Self.scene.utf8))
        let value = try JSONValue(container)
        #expect(try Self.text(of: value) == Self.scene)
        #expect(value["grid"]?["cols"] == .integer(96))
    }
}
