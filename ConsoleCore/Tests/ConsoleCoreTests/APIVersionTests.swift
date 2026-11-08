import Testing

@testable import ConsoleCore

/// `host-connection`, "The app checks API compatibility on connect", against a contract stating
/// API 2.5.0, as its scenarios do, so no test names a version the bundled contract will outgrow.
struct APIVersionTests {
    private static func contract(_ text: String = "2.5.0") throws -> SavedContract {
        SavedContract(version: try #require(APIVersion(parsing: text)), openOperations: [])
    }

    @Test(arguments: [
        ("2.5.0", APIVersion.Compatibility.compatible),
        ("2.5.0+abc", .compatible),
        ("2.5.0-rc.1", .compatible),
        ("2.4.0", .hostOlder),
        ("2.4.9", .hostOlder),
        ("2.5.1", .hostNewer),
        ("2.6.0", .hostNewer),
        ("3.0.0", .hostNewer),
        ("1.9.9", .hostOlder),
        ("3.0.0-beta+exp.sha.5114f85", .hostNewer),
    ])
    func theVerdict(text: String, verdict: APIVersion.Compatibility) throws {
        #expect(
            try #require(APIVersion(parsing: text)).compatibility(with: Self.contract()) == verdict)
    }

    /// `host-client`, "A refreshed contract with a new major" and "... with a new minor".
    @Test func aRefreshedContractMovesTheSupportedVersion() throws {
        let three = try Self.contract("3.0.0")
        let current = try Self.contract()
        #expect(
            try #require(APIVersion(parsing: "3.0.0")).compatibility(with: three) == .compatible)
        #expect(try #require(APIVersion(parsing: "2.1.0")).compatibility(with: three) == .hostOlder)
        #expect(
            try #require(APIVersion(parsing: "2.5.0")).compatibility(with: current) == .compatible)
        #expect(
            try #require(APIVersion(parsing: "2.4.0")).compatibility(with: current) == .hostOlder)
    }

    @Test func onlyTheBundledContractsVersionIsCompatible() throws {
        let version = SavedContract.bundled.version
        let (major, minor, patch) = (version.major, version.minor, version.patch)
        #expect(
            try #require(APIVersion(parsing: "\(major).\(minor).\(patch)")).compatibility
                == .compatible)
        #expect(
            try #require(APIVersion(parsing: "\(major).\(minor + 1).\(patch)")).compatibility
                == .hostNewer)
        #expect(
            try #require(APIVersion(parsing: "\(major).\(minor).\(patch + 1)")).compatibility
                == .hostNewer)
        #expect(
            try #require(APIVersion(parsing: "\(major + 1).0.0")).compatibility == .hostNewer)
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
