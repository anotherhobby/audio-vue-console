/// Feeds the render helper one request at a time: the canvas's first, then the library's, then the
/// thumbnails' (`scene-render` design D3, `library-render` design D2). Within the canvas's lane and
/// the library's, a newer request with the same key replaces one of its own lane not yet sent, so a
/// resize sends the size it is at once the helper is free, never every step it passed through, and
/// a scene switch leaves no tile of the last scene waiting.
@MainActor
public final class RenderQueue {
    public enum Lane: Sendable {
        case canvas
        case library
        case thumbnails

        /// Whether a newer request replaces a waiting one with the same key.
        var replaces: Bool { self != .thumbnails }
    }

    private struct Job {
        let lane: Lane
        let key: String
        let message: JSONValue
        let answer: CheckedContinuation<Result<HelperAnswer, RenderFailure>?, Never>
    }

    private let helper: RenderHelper
    private var pending: [Job] = []
    private var isSending = false

    public init(helper: RenderHelper) {
        self.helper = helper
    }

    /// How many requests wait to be sent.
    var waiting: Int { pending.count }

    /// Sends `message` when its turn comes, answering with the helper's answer or failure, or nil
    /// where a newer request with the same `key` replaced it before it was sent.
    public func submit(_ message: JSONValue, lane: Lane, key: String) async
        -> Result<HelperAnswer, RenderFailure>?
    {
        await withCheckedContinuation { answer in
            if lane.replaces,
                let index = pending.firstIndex(where: { $0.lane == lane && $0.key == key })
            {
                pending[index].answer.resume(returning: nil)
                pending.remove(at: index)
            }
            pending.append(Job(lane: lane, key: key, message: message, answer: answer))
            sendNext()
        }
    }

    private func sendNext() {
        guard !isSending, let index = nextIndex() else { return }
        let job = pending.remove(at: index)
        isSending = true
        Task {
            let result: Result<HelperAnswer, RenderFailure>
            do throws(RenderFailure) {
                result = .success(try await helper.ask(job.message))
            } catch {
                result = .failure(error)
            }
            job.answer.resume(returning: result)
            isSending = false
            sendNext()
        }
    }

    /// The first job of the canvas's lane, or else the first of the library's, or else the first.
    private func nextIndex() -> Int? {
        pending.firstIndex { $0.lane == .canvas }
            ?? pending.firstIndex { $0.lane == .library }
            ?? pending.indices.first
    }
}
