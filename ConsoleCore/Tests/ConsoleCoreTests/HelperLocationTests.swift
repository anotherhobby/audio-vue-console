import Foundation
import Testing

@testable import ConsoleCore

/// `render-runtime`: the helper is found under the app's resources, or says what is missing.
struct HelperLocationTests {
    /// A resources folder holding what `parts` names: `python`, `script`, `manifest`.
    private static func resources(with parts: Set<String>) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let files = FileManager.default
        if parts.contains("python") {
            let bin = root.appending(path: "python/bin")
            try files.createDirectory(at: bin, withIntermediateDirectories: true)
            let python = bin.appending(path: "python3")
            try Data("#!/bin/sh\n".utf8).write(to: python)
            try files.setAttributes([.posixPermissions: 0o755], ofItemAtPath: python.path)
        }
        let src = root.appending(path: "render-bundle/src")
        try files.createDirectory(at: src, withIntermediateDirectories: true)
        if parts.contains("script") {
            try Data().write(to: src.appending(path: "render_service.py"))
        }
        if parts.contains("manifest") {
            try Data("{}".utf8).write(to: root.appending(path: "render-bundle/manifest.json"))
        }
        return root
    }

    @Test func everythingInPlace() throws {
        let root = try Self.resources(with: ["python", "script", "manifest"])
        let location = try HelperLocation.resolve(in: root)
        #expect(location.interpreter.lastPathComponent == "python3")
        #expect(location.script.path.hasSuffix("render-bundle/src/render_service.py"))
        #expect(location.manifest.lastPathComponent == "manifest.json")
    }

    @Test(arguments: [
        (Set(["script", "manifest"]), HelperLocation.Missing.interpreter),
        (Set(["python", "manifest"]), HelperLocation.Missing.script),
        (Set(["python", "script"]), HelperLocation.Missing.manifest),
    ])
    func somethingMissing(parts: Set<String>, missing: HelperLocation.Missing) throws {
        let root = try Self.resources(with: parts)
        #expect(throws: missing) { try HelperLocation.resolve(in: root) }
    }
}
