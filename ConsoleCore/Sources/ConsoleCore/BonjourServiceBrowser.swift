import Foundation
import Network
import Synchronization
import dnssd

/// The app's browser (design D1): Network's `NetworkBrowser` for the announcements and their TXT
/// records, and dnssd's `DNSServiceResolve` for the host target and port `URLSession` needs, which
/// Network does not give.
public struct BonjourServiceBrowser: ServiceBrowser {
    static let serviceType = "_audio-vue._tcp"
    static let domain = "local."
    /// The TXT key that names the host (audio-vue `control-api`, "The announcement is part of the
    /// contract").
    static let idKey = "id"

    public init() {}

    public func updates() -> AsyncStream<BrowseUpdate> {
        AsyncStream { continuation in
            let browsing = Task { await Self.browse(into: continuation) }
            continuation.onTermination = { _ in browsing.cancel() }
        }
    }

    public func resolve(_ instance: ServiceInstance) async throws(HostFailure) -> HostAddress {
        let resolution = Resolution()
        let timeout = Task {
            do {
                try await Task.sleep(for: .seconds(HostClient.requestTimeout))
            } catch {
                return  // Answered first.
            }
            resolution.finish(.failure(.unreachable))
        }
        defer { timeout.cancel() }
        let answer = await withTaskCancellationHandler {
            await withCheckedContinuation { resolution.start(instance.name, answering: $0) }
        } onCancel: {
            resolution.finish(.failure(.unreachable))
        }
        return try answer.get()
    }

    /// Runs one browse until it fails or is cancelled. The instances last found are given again when
    /// the browse turns ready, which is how a browse that was denied says it no longer is.
    private static func browse(into continuation: AsyncStream<BrowseUpdate>.Continuation) async {
        let last = Mutex<Set<ServiceInstance>>([])
        let browser = NetworkBrowser(
            for: .bonjour(serviceType, domain: domain, includeTxtRecord: true)
        )
        .onStateUpdate { _, state in
            switch state {
            case .waiting(let error) where isPolicyDenial(error): continuation.yield(.denied)
            case .ready: continuation.yield(.found(last.withLock { $0 }))
            default: break
            }
        }
        do {
            try await browser.run { endpoints in
                let instances = Set(endpoints.map(instance(of:)))
                last.withLock { $0 = instances }
                continuation.yield(.found(instances))
            }
        } catch {
            // A failed or cancelled browse ends the stream; `PanelDiscovery` waits for a restart.
        }
        continuation.finish()
    }

    private static func instance(of endpoint: Bonjour.Endpoint) -> ServiceInstance {
        guard case .string(let id) = endpoint.txtRecord.getEntry(for: idKey), !id.isEmpty else {
            return ServiceInstance(name: endpoint.name, hostID: nil)
        }
        return ServiceInstance(name: endpoint.name, hostID: id)
    }

    /// macOS refusing this app the local network (design D6).
    static func isPolicyDenial(_ error: NWError) -> Bool {
        guard case .dns(let code) = error else { return false }
        return code == DNSServiceErrorType(kDNSServiceErr_PolicyDenied)
    }
}

/// One `DNSServiceResolve`, answered once: by its first reply, a timeout or a cancel, whichever
/// comes first. Its reference is deallocated on the queue its replies arrive on, as dnssd asks.
private final class Resolution: Sendable {
    typealias Answer = Result<HostAddress, HostFailure>

    private struct State {
        var continuation: CheckedContinuation<Answer, Never>?
        var answer: Answer?
        /// The resolve's `DNSServiceRef` by its address, since a pointer is not `Sendable` and so
        /// cannot be handed to the lock; it is made a pointer again on the queue.
        var reference: UInt?
    }

    private static let queue = DispatchQueue(label: "com.hobbysprawl.AudioVueConsole.resolve")
    private let state = Mutex(State())

    /// Resolves the instance named `name`, answering `continuation`, or answers it at once when
    /// the resolution has already finished.
    func start(_ name: String, answering continuation: CheckedContinuation<Answer, Never>) {
        let early = state.withLock { state in
            if state.answer == nil { state.continuation = continuation }
            return state.answer
        }
        if let early { return continuation.resume(returning: early) }
        var reference: DNSServiceRef?
        let context = Unmanaged.passRetained(self).toOpaque()
        let error = DNSServiceResolve(
            &reference, 0, 0, name, BonjourServiceBrowser.serviceType,
            BonjourServiceBrowser.domain, Self.reply, context)
        guard error == kDNSServiceErr_NoError, let reference else {
            Unmanaged<Resolution>.fromOpaque(context).release()
            return finish(.failure(.unreachable))
        }
        DNSServiceSetDispatchQueue(reference, Self.queue)
        let address = UInt(bitPattern: reference)
        let finished = state.withLock { state in
            state.reference = address
            return state.answer != nil
        }
        // A timeout or cancel that came before the reference was kept could not deallocate it.
        if finished { Self.queue.async { self.deallocate() } }
    }

    /// Answers the resolve, once; any later answer is dropped.
    func finish(_ answer: Answer) {
        let continuation: CheckedContinuation<Answer, Never>? = state.withLock { state in
            guard state.answer == nil else { return nil }
            state.answer = answer
            let continuation = state.continuation
            state.continuation = nil
            return continuation
        }
        continuation?.resume(returning: answer)
        Self.queue.async { self.deallocate() }
    }

    /// Ends the resolve and lets go of the retain its context holds, once.
    private func deallocate() {
        let reference = state.withLock { state in
            let reference = state.reference
            state.reference = nil
            return reference
        }
        guard let reference = reference.flatMap(OpaquePointer.init(bitPattern:)) else { return }
        DNSServiceRefDeallocate(reference)
        Unmanaged.passUnretained(self).release()
    }

    private static let reply: DNSServiceResolveReply = {
        _, _, _, errorCode, _, target, port, _, _, context in
        guard let context else { return }
        let resolution = Unmanaged<Resolution>.fromOpaque(context).takeUnretainedValue()
        guard errorCode == kDNSServiceErr_NoError, let target else {
            return resolution.finish(.failure(.unreachable))
        }
        let address = HostAddress(
            resolvedHost: String(cString: target), port: Int(UInt16(bigEndian: port)))
        resolution.finish(address.map { .success($0) } ?? .failure(.unexpectedAnswer))
    }
}
