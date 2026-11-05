import Testing

@testable import ConsoleCore

/// `host-pairing`, "The app names itself by the Mac's name".
struct ClientNameTests {
    @Test func aShortNameIsSentAsItIs() {
        #expect(ClientName.fitted("Dan's MacBook Pro") == "Dan's MacBook Pro")
    }

    @Test func aLongNameIsCutTo64() {
        let name = String(repeating: "m", count: 70)
        #expect(ClientName.fitted(name) == String(repeating: "m", count: 64))
    }

    @Test func theCutCountsScalarsAsTheHostDoes() {
        // "é" as "e" and a combining accent is two scalars, one character: the 63rd and 64th
        // scalars, so the whole character is kept and the 64-scalar limit is met.
        let name = String(repeating: "m", count: 62) + "e\u{301}" + "tail"
        let fitted = ClientName.fitted(name)
        #expect(fitted.unicodeScalars.count == 64)
        #expect(fitted == String(repeating: "m", count: 62) + "e\u{301}")
    }

    @Test func anEmptyNameFallsBackToTheApp() {
        #expect(ClientName.fitted("") == ClientName.fallback)
    }

    @Test func theCurrentNameFits() {
        let name = ClientName.current
        #expect(!name.isEmpty)
        #expect(name.unicodeScalars.count <= ClientName.maxLength)
    }
}
