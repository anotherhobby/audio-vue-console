import Observation

/// A paired host's calibration runs, newest first, and each run's report (`calibration-history`).
/// A failed read keeps the runs read before it.
@MainActor @Observable
public final class CalibrationRuns {
    public enum State: Equatable, Sendable {
        case idle
        case loading
        case loaded
        /// The host refused the app's token, so the app is no longer paired.
        case unpaired
        case failed(HostFailure)
    }

    public private(set) var state = State.idle
    public private(set) var runs: [RunEntry] = []
    /// The panel's installed capture rate, the rate a calibration runs at: `install.input.rate`,
    /// else the settings schema's default for it (design D4). Nil until read.
    public private(set) var installedRate: Int?

    private let address: HostAddress
    private let client: HostClient
    private let pairing: Pairing
    private let store: any TokenStore
    private let onUnpaired: @MainActor () -> Void

    /// The runs of the host `pairing` is for, calling `onUnpaired` once its token is forgotten.
    init(
        address: HostAddress, client: HostClient, pairing: Pairing, store: any TokenStore,
        onUnpaired: @escaping @MainActor () -> Void
    ) {
        self.address = address
        self.client = client
        self.pairing = pairing
        self.store = store
        self.onUnpaired = onUnpaired
    }

    /// Reads the host's runs, and the installed capture rate.
    public func load() async {
        state = .loading
        do {
            runs = try await client.runs(at: address, token: pairing.token)
            let install = try await client.install(at: address, token: pairing.token)
            let schema = try await client.schema(at: address, token: pairing.token)
            installedRate = Self.rate(install: install, schema: schema)
            state = .loaded
        } catch {
            fail(error)
        }
    }

    /// `install.input.rate` where written, else the schema's declared default.
    nonisolated static func rate(install: [String: JSONValue], schema: JSONValue) -> Int? {
        install["input"]?["rate"]?.intValue
            ?? schema["$defs"]?["install.input"]?["properties"]?["rate"]?["default"]?.intValue
    }

    /// A run's HTML report, fetched when opened and never kept.
    public func report(_ run: RunEntry) async throws(HostFailure) -> String {
        do {
            return try await client.report(run.id, at: address, token: pairing.token)
        } catch {
            if error == .tokenRefused { fail(error) }
            throw error
        }
    }

    private func fail(_ failure: HostFailure) {
        guard failure == .tokenRefused else {
            state = .failed(failure)
            return
        }
        store.forget(host: pairing.hostID)
        state = .unpaired
        onUnpaired()
    }
}
