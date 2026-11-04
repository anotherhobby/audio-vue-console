import Foundation
import Testing

/// The `app-boundaries` spec, held by reading the sources: the core imports no UI framework, and the
/// app target does no networking of its own. A text scan is crude, but it runs on every `swift test`.
struct BoundaryTests {
    @Test func theCoreImportsNoUIFramework() throws {
        let scan = try SourceScan(folder: "ConsoleCore/Sources") {
            SourceScan.imports($0, anyOf: ["SwiftUI", "AppKit"])
        }
        #expect(!scan.scanned.isEmpty, "No sources found under ConsoleCore/Sources")
        #expect(scan.offenders.isEmpty, "A UI framework is imported by \(scan.offenders)")
    }

    @Test func theAppDoesNoNetworking() throws {
        let scan = try SourceScan(folder: "AudioVueConsole") {
            SourceScan.imports($0, anyOf: ["Network"]) || $0.contains("URLSession")
        }
        #expect(!scan.scanned.isEmpty, "No sources found under AudioVueConsole")
        #expect(scan.offenders.isEmpty, "Networking in the app target, in \(scan.offenders)")
    }

    @Test(arguments: [
        "import SwiftUI",
        "  import AppKit",
        "@preconcurrency import SwiftUI",
        "public import SwiftUI",
        "@preconcurrency public import struct SwiftUI.Color",
        "import AppKit.NSView",
    ])
    func anImportOfAUIFrameworkIsFound(line: String) {
        #expect(SourceScan.imports("import Foundation\n\(line)\n", anyOf: ["SwiftUI", "AppKit"]))
    }

    @Test(arguments: [
        "import Foundation",
        "import SwiftUIExtras",
        "// import SwiftUI",
        "let text = \"import SwiftUI\"",
    ])
    func otherLinesAreNotImports(line: String) {
        #expect(!SourceScan.imports(line, anyOf: ["SwiftUI", "AppKit"]))
    }
}

/// The Swift files under one folder of the repository, and those a check finds fault with, by their
/// paths from the repository's root.
private struct SourceScan {
    let scanned: [String]
    let offenders: [String]

    /// The repository's root, found from this file: `ConsoleCore/Tests/ConsoleCoreTests/`.
    private static let root = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    init(folder: String, offends: (String) -> Bool) throws {
        var scanned: [String] = []
        var offenders: [String] = []
        let files = FileManager.default.enumerator(
            at: Self.root.appending(path: folder), includingPropertiesForKeys: nil)
        while let url = files?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let path = String(
                url.standardizedFileURL.path(percentEncoded: false)
                    .dropFirst(Self.root.path(percentEncoded: false).count))
            scanned.append(path)
            if offends(try String(contentsOf: url, encoding: .utf8)) { offenders.append(path) }
        }
        self.scanned = scanned
        self.offenders = offenders.sorted()
    }

    private static let accessLevels: Set<Substring> = [
        "public", "package", "internal", "fileprivate", "private",
    ]
    private static let declarationKinds: Set<Substring> = [
        "typealias", "struct", "class", "enum", "protocol", "let", "var", "func",
    ]

    /// Whether any line imports one of `modules`, whatever its attributes, access level or kind:
    /// `@preconcurrency public import struct SwiftUI.Color` imports SwiftUI.
    static func imports(_ source: String, anyOf modules: Set<Substring>) -> Bool {
        source.split(whereSeparator: \.isNewline).contains { line in
            let words = line.split(whereSeparator: \.isWhitespace)
                .drop { $0.hasPrefix("@") || accessLevels.contains($0) }
            guard words.first == "import" else { return false }
            var rest = words.dropFirst()
            if let kind = rest.first, declarationKinds.contains(kind) { rest = rest.dropFirst() }
            guard let module = rest.first?.split(separator: ".").first else { return false }
            return modules.contains(module)
        }
    }
}
