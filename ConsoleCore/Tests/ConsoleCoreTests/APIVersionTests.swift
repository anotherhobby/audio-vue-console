import Testing

@testable import ConsoleCore

/// `host-connection`, "The app checks API compatibility on connect", against a contract stating
/// API 2.0.0, as its scenarios do, so no test names a version the bundled contract will outgrow.
struct APIVersionTests {
    private static let contract = SavedContract(major: 2, openOperations: [])

    @Test(arguments: [
        ("2.4.2", APIVersion.Compatibility.compatible),
        ("2.0.0", .compatible),
        ("3.0.0", .hostNewer),
        ("1.0.0", .hostOlder),
        ("0.9.0", .hostOlder),
        ("2.0.0-rc.1", .compatible),
        ("3.0.0-beta+exp.sha.5114f85", .hostNewer),
        ("2.2.3+build.7", .compatible),
    ])
    func theVerdict(text: String, verdict: APIVersion.Compatibility) throws {
        #expect(
            try #require(APIVersion(parsing: text)).compatibility(with: Self.contract) == verdict)
    }

    /// `host-client`, "A refreshed contract with a new major".
    @Test func aRefreshedContractMovesTheSupportedMajor() throws {
        let three = SavedContract(major: 3, openOperations: [])
        #expect(
            try #require(APIVersion(parsing: "3.0.0")).compatibility(with: three) == .compatible)
        #expect(try #require(APIVersion(parsing: "2.1.0")).compatibility(with: three) == .hostOlder)
    }

    @Test func theBundledContractsMajorIsCompatible() throws {
        let major = SavedContract.bundled.major
        #expect(try #require(APIVersion(parsing: "\(major).4.2")).compatibility == .compatible)
        #expect(try #require(APIVersion(parsing: "\(major + 1).0.0")).compatibility == .hostNewer)
        #expect(try #require(APIVersion(parsing: "\(major - 1).0.0")).compatibility == .hostOlder)
    }

    @Test func aPreReleaseIsReadByItsNumericCore() throws {
        let version = try #require(APIVersion(parsing: "1.4.2-rc.1"))
        #expect((version.major, version.minor, version.patch) == (1, 4, 2))
        #expect(version.description == "1.4.2-rc.1")
    }

    @Test(arguments: [
        "", "1", "1.0", "1.0.0.0", "v1.0.0", "1..0", "1.0.x", " 1.0.0", "1.0.0 ", "+1.0.0",
        "1.-0.0",
        "-1.0.0", "１.0.0",
    ])
    func notSemanticVersioning(text: String) {
        #expect(APIVersion(parsing: text) == nil)
    }
}
