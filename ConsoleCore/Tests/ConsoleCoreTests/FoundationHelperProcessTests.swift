import Foundation
import Synchronization
import Testing

@testable import ConsoleCore

/// Design D2: the helper's process, its pipes and its error output.
struct FoundationHelperProcessTests {
    private static func caches() -> URL {
        FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    }

    @Test func aFrameEchoesThroughThePipes() async throws {
        let launcher = FoundationHelperLauncher(
            executable: URL(filePath: "/bin/cat"), arguments: [], caches: Self.caches(),
            errorLine: { _ in })
        let helper = try launcher.launch()
        defer { helper.stop() }
        try helper.write(try HelperFrame.encode(.object(["op": .string("hello")])))
        var reader = HelperAnswerReader()
        var answer: HelperAnswer?
        while answer == nil, let chunk = await helper.nextChunk() {
            reader.append(chunk)
            answer = try reader.next()
        }
        #expect(answer?.header["op"] == .string("hello"))
    }

    @Test func standardErrorIsSentOnByLine() async throws {
        let lines = Mutex<[String]>([])
        let launcher = FoundationHelperLauncher(
            executable: URL(filePath: "/bin/sh"), arguments: ["-c", "echo one >&2; echo two >&2"],
            caches: Self.caches(), errorLine: { line in lines.withLock { $0.append(line) } })
        let helper = try launcher.launch()
        while await helper.nextChunk() != nil {}
        for _ in 0..<100 where lines.withLock({ $0.count }) < 2 {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(lines.withLock { $0 } == ["one", "two"])
    }

    @Test func theCachesAreMadeInTheGivenPlace() throws {
        let caches = Self.caches()
        let launcher = FoundationHelperLauncher(
            executable: URL(filePath: "/usr/bin/true"), arguments: [], caches: caches,
            errorLine: { _ in })
        try launcher.launch().stop()
        #expect(FileManager.default.fileExists(atPath: caches.appending(path: "numba").path))
        #expect(FileManager.default.fileExists(atPath: caches.appending(path: "pycache").path))
    }

    @Test func aLineSplitAcrossChunks() {
        let lines = Mutex<[String]>([])
        let splitter = LineSplitter { line in lines.withLock { $0.append(line) } }
        splitter.take(Data("Trace".utf8))
        splitter.take(Data("back\nlast".utf8))
        splitter.take(Data())
        #expect(lines.withLock { $0 } == ["Traceback", "last"])
    }
}
