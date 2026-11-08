import Foundation
import Testing

@testable import ConsoleCore

/// `host-client`, "The supported API is the saved contract's".
struct SavedContractTests {
    @Test func theBundledContractReads() {
        let contract = SavedContract.bundled
        #expect(contract.version.major > 0)
        #expect(
            contract.openOperations == [
                "version_v1_version_get", "ask_v1_pairing_post", "confirm_v1_pairing_confirm_post",
            ])
    }

    @Test func anOperationWithSecurityIsNotOpen() throws {
        let contract = try SavedContract(json: Self.contract(version: "3.1.0"))
        #expect(contract.version.description == "3.1.0")
        #expect(contract.openOperations == ["open_get"])
    }

    @Test func aPathItemsOtherKeysAreIgnored() throws {
        let json = #"""
            {"info": {"version": "1.0.0"},
             "paths": {"/a": {"summary": "A", "parameters": [], "get": {"operationId": "a"}}}}
            """#
        #expect(try SavedContract(json: Data(json.utf8)).openOperations == ["a"])
    }

    @Test func aContractWithoutAVersionIsRefused() {
        #expect(throws: SavedContract.Unreadable.notAContract) {
            try SavedContract(json: Data(#"{"info": {}, "paths": {}}"#.utf8))
        }
    }

    @Test func aVersionThatIsNotSemanticIsRefused() {
        #expect(throws: SavedContract.Unreadable.versionNotSemantic("two")) {
            try SavedContract(json: Self.contract(version: "two"))
        }
    }

    @Test func somethingElseIsRefused() {
        #expect(throws: SavedContract.Unreadable.notAContract) {
            try SavedContract(json: Data("not json".utf8))
        }
    }

    /// A contract with one open operation and one that takes a token.
    private static func contract(version: String) -> Data {
        Data(
            #"""
            {"info": {"version": "\#(version)"},
             "paths": {
               "/open": {"get": {"operationId": "open_get"}},
               "/closed": {"post": {"operationId": "closed_post",
                                    "security": [{"HTTPBearer": []}]}}}}
            """#.utf8)
    }
}
