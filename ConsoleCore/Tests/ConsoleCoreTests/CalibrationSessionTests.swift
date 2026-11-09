import Foundation
import Synchronization
import Testing

@testable import ConsoleCore

/// A stimulus written as a WAV header of `seconds` at the run's rate, or refused.
final class ScriptedStimulus: StimulusSource {
    private let refusal: StimulusFailure?
    private let asked = Mutex<[StatedRun]>([])
    let directory: URL

    init(refusal: StimulusFailure? = nil) {
        self.refusal = refusal
        directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    }

    var runs: [StatedRun] { asked.withLock { $0 } }

    func file(for run: StatedRun) async throws(StimulusFailure) -> URL {
        asked.withLock { $0.append(run) }
        if let refusal { throw refusal }
        let url = directory.appending(path: "stimulus.wav")
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
            try WAVHeaderTests.header(rate: run.rate, seconds: 12).write(to: url)
        } catch {
            throw .failed("\(error)")
        }
        return url
    }
}

/// One run's steps, its endings and its cancel (`calibration-run`, design D3).
@MainActor struct CalibrationSessionTests {
    nonisolated static let done = PlayerExit(status: 0, errorOutput: "")
    static let armed = FakeTransport.Answer.status(
        200, #"{"status": "done", "listening": true, "deadline_s": 10, "arm": "a1"}"#)
    static let stated = StatedRun(rate: 96_000)

    struct Rig {
        let session: CalibrationSession
        let launcher: ScriptedPlayerLauncher
        let transport: FakeTransport
        let stimulus: ScriptedStimulus
    }

    /// A session whose rate call exits at once and whose play is held, unless told otherwise.
    static func rig(
        _ answers: [FakeTransport.Route: FakeTransport.Answer] = [.arm: armed],
        stimulus: ScriptedStimulus = ScriptedStimulus(),
        player: @escaping @Sendable ([String]) -> PlayerExit? = { $0.first == "rate" ? done : nil }
    ) -> Rig {
        let launcher = ScriptedPlayerLauncher(player)
        let transport = FakeTransport(answers)
        let session = CalibrationSession(
            player: CalibrationPlayer(launcher: launcher), stimulus: stimulus,
            client: HostClient(transport: transport))
        return Rig(session: session, launcher: launcher, transport: transport, stimulus: stimulus)
    }

    static func start(_ rig: Rig) throws {
        let host = CalibrationHost(
            address: try #require(HostAddress(parsing: "audio-vue")), token: HostToken("secret"))
        #expect(rig.session.start(stated, device: "D10s ", host: host))
    }

    static func state(
        _ word: CalibrationLifecycle?, ended: EndedCalibration? = nil
    ) -> PanelState {
        var state = PanelState(condition: .up)
        state.calibrationLifecycle = word
        state.endedCalibration = ended
        return state
    }

    static func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<1000 where !condition() {
            try await Task.sleep(for: .milliseconds(2))
        }
        #expect(condition())
    }

    static func isPlaying(_ session: CalibrationSession) -> Bool {
        if case .playing = session.step { return true }
        return false
    }

    /// Whether the file is playing: the step says so, and the `play` call has launched and waits.
    /// The step changes a moment before `cal-play` launches, so a test that acts on the player
    /// waits for both.
    static func isPlaying(_ session: CalibrationSession, on launcher: ScriptedPlayerLauncher)
        -> Bool
    {
        isPlaying(session) && launcher.calls.last?.first == "play"
            && launcher.players.last?.isWaiting == true
    }

    @Test func theStepsGoInCalibrationsOrder() async throws {
        let rig = Self.rig()
        try Self.start(rig)
        try await Self.waitUntil { Self.isPlaying(rig.session, on: rig.launcher) }
        #expect(rig.stimulus.runs == [Self.stated])
        let file = rig.stimulus.directory.appending(path: "stimulus.wav").path()
        #expect(rig.launcher.calls == [["rate", "D10s ", "96000"], ["play", "D10s ", file]])
        let requests = await rig.transport.requests
        #expect(requests.map { $0.url?.path() } == ["/v1/commands/arm"])
        let body = try #require(requests.first?.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? NSDictionary)
        #expect(json == ["stated": ["kind": "calibration", "file_rate": 96_000]] as NSDictionary)
    }

    @Test func aRefusedArmPlaysNothing() async throws {
        let refused = #"{"status": "refused", "reason": "still arming"}"#
        let rig = Self.rig([.arm: .status(409, refused)])
        try Self.start(rig)
        try await Self.waitUntil { rig.session.ending != nil }
        #expect(rig.session.ending == .refused("still arming"))
        #expect(rig.launcher.calls.map(\.first) == ["rate"])
    }

    @Test func aRefusedStimulusEndsBeforeTheRate() async throws {
        let stimulus = ScriptedStimulus(refusal: .refused("file_rate must be one of [44100]"))
        let rig = Self.rig(stimulus: stimulus)
        try Self.start(rig)
        try await Self.waitUntil { rig.session.ending != nil }
        #expect(rig.session.ending == .stimulusRefused("file_rate must be one of [44100]"))
        #expect(rig.launcher.calls.isEmpty)
    }

    @Test func theStepFollowsThePanelOnceTheFileHasPlayed() async throws {
        let rig = Self.rig()
        try Self.start(rig)
        try await Self.waitUntil { Self.isPlaying(rig.session, on: rig.launcher) }
        rig.session.observe(Self.state(.running))
        #expect(Self.isPlaying(rig.session))
        rig.launcher.players.last?.end(Self.done)
        try await Self.waitUntil { rig.session.step == .measuring }
        for (word, step) in [
            (CalibrationLifecycle.waiting, CalibrationSession.Step.armed), (.arming, .measuring),
            (.running, .measuring), (.analysing, .analysing),
        ] {
            rig.session.observe(Self.state(word))
            #expect(rig.session.step == step)
        }
    }

    @Test func endedWordsEndNothing() async throws {
        let rig = Self.rig()
        try Self.start(rig)
        try await Self.waitUntil { Self.isPlaying(rig.session, on: rig.launcher) }
        for word in [CalibrationLifecycle.done, .off, .waiting, .off, .expired] {
            rig.session.observe(Self.state(word))
        }
        #expect(rig.session.isUnderWay)
        #expect(rig.session.ending == nil)
    }

    @Test func aCompletedRunEndsFromItsArmsEnding() async throws {
        let rig = Self.rig()
        try Self.start(rig)
        try await Self.waitUntil { Self.isPlaying(rig.session, on: rig.launcher) }
        rig.session.observe(
            Self.state(.off, ended: EndedCalibration(arm: "a0", outcome: .done, runID: "old")))
        #expect(rig.session.isUnderWay)
        let ended = EndedCalibration(arm: "a1", outcome: .done, runID: "r1", applicable: true)
        rig.session.observe(Self.state(.done, ended: ended))
        #expect(rig.session.ending == .completed(runID: "r1", applicable: true, reason: nil))
        #expect(
            !FileManager.default.fileExists(atPath: rig.stimulus.directory.path() + "stimulus.wav"))
    }

    @Test func anExpiryWhilePlayingStopsThePlayer() async throws {
        let rig = Self.rig()
        try Self.start(rig)
        try await Self.waitUntil { Self.isPlaying(rig.session, on: rig.launcher) }
        let reason = "no calibration file heard before the deadline"
        rig.session.observe(
            Self.state(.off, ended: EndedCalibration(arm: "a1", outcome: .expired, reason: reason)))
        #expect(rig.session.ending == .expired(reason: reason))
        #expect(rig.launcher.players.last?.stopCount == 1)
    }

    @Test func aPlayerThatFailsSendsACancel() async throws {
        let rig = Self.rig([.arm: Self.armed, .cancel: .status(200, #"{"status": "done"}"#)])
        try Self.start(rig)
        try await Self.waitUntil { Self.isPlaying(rig.session, on: rig.launcher) }
        rig.launcher.players.last?.end(PlayerExit(status: 1, errorOutput: "device gone\n"))
        try await Self.waitUntil { rig.session.ending != nil }
        #expect(rig.session.ending == .playerFailed("device gone"))
        #expect(await rig.transport.requests(to: .cancel).count == 1)
    }

    /// Design D4: an awaited run returns its ending once the panel names its arm.
    @Test func anAwaitedRunReturnsItsEnding() async throws {
        let rig = Self.rig()
        let host = CalibrationHost(
            address: try #require(HostAddress(parsing: "audio-vue")), token: HostToken("secret"))
        let session = rig.session
        let running = Task { await session.run(Self.stated, device: "D10s ", host: host) }
        try await Self.waitUntil { Self.isPlaying(session, on: rig.launcher) }
        let ended = EndedCalibration(arm: "a1", outcome: .done, runID: "r1", applicable: true)
        session.observe(Self.state(.done, ended: ended))
        #expect(await running.value == .completed(runID: "r1", applicable: true, reason: nil))
    }

    /// Design D4: a pass starts its next rate as soon as `run` returns, so the stopped playback of a
    /// run the panel ended has unwound by then, leaving `cal-play` free.
    @Test func anAwaitedRunReturnsOnlyOnceItsPlaybackHasStopped() async throws {
        let launcher = ScriptedPlayerLauncher(stopDelay: .milliseconds(20)) {
            $0.first == "rate" ? Self.done : nil
        }
        let player = CalibrationPlayer(launcher: launcher)
        let session = CalibrationSession(
            player: player, stimulus: ScriptedStimulus(),
            client: HostClient(transport: FakeTransport([.arm: Self.armed])))
        let host = CalibrationHost(
            address: try #require(HostAddress(parsing: "audio-vue")), token: HostToken("secret"))
        for _ in 0..<3 {
            let running = Task { await session.run(Self.stated, device: "D10s ", host: host) }
            try await Self.waitUntil { Self.isPlaying(session, on: launcher) }
            let ended = EndedCalibration(arm: "a1", outcome: .expired)
            session.observe(Self.state(.off, ended: ended))
            _ = await running.value
            try await player.setRate(device: "D10s ", hz: 48_000)
        }
    }

    @Test func aSecondStartWhileOneRunsIsRefused() async throws {
        let rig = Self.rig()
        try Self.start(rig)
        let host = CalibrationHost(
            address: try #require(HostAddress(parsing: "audio-vue")), token: HostToken("secret"))
        #expect(!rig.session.start(Self.stated, device: "D10s ", host: host))
    }
}
