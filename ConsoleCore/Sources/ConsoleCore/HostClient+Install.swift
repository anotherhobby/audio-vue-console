import Foundation
import HostAPI
import OpenAPIRuntime

/// An install block as the host stores it: its document and the revision a write is made on.
/// A block never written is revision 0 with an empty document, on its defaults.
public struct InstallBlockState: Sendable, Equatable {
    public let doc: [String: JSONValue]
    public let rev: Int

    public init(doc: [String: JSONValue], rev: Int) {
        self.doc = doc
        self.rev = rev
    }
}

/// What the host said of an install write: the revision stored, when it applies, the chain
/// settings it changed, and what a chain change does to calibration, in the host's words.
public struct InstallWritten: Sendable, Equatable {
    /// When the panel takes a write (audio-vue `settings-store`, "An install write says when it
    /// applies").
    public enum Applies: String, Sendable, Equatable {
        /// At the panel's next start: a `display` write, or any block with no chain change.
        case onStart = "on_start"
        case onRestart = "on_restart"
        /// At the next reload: the `viewing` block.
        case onReload = "on_reload"
        /// The panel was restarted to take a chain change before the host answered.
        case restarted
    }

    public let rev: Int
    /// When it applies, or nil for a value this build does not know.
    public let applies: Applies?
    public let chainChanged: [String]
    public let calibration: String?

    public init(rev: Int, applies: Applies?, chainChanged: [String], calibration: String?) {
        self.rev = rev
        self.applies = applies
        self.chainChanged = chainChanged
        self.calibration = calibration
    }
}

/// The host's install settings and capture devices, read and written with a token (audio-vue
/// `settings-store`, `control-api`).
extension HostClient {
    /// `GET /v1/install`: each install block with its revision, by the block's name.
    public func installBlocks(at address: HostAddress, token: HostToken) async throws(HostFailure)
        -> [String: InstallBlockState]
    {
        let output = try await call(at: address, token: token) {
            try await $0.readInstallV1InstallGet()
        }
        guard case .ok(let ok) = output else { throw .unexpectedAnswer }
        var blocks: [String: InstallBlockState] = [:]
        for block in try Self.body({ try ok.body.json }).blocks {
            let doc = try Self.json(block.doc).objectValue ?? [:]
            blocks[block.block] = InstallBlockState(doc: doc, rev: block.rev)
        }
        return blocks
    }

    /// `PUT /v1/install/{block}`: stores `doc` as the block's next revision, made from `base`. A
    /// chain change restarts a running panel before the host answers, so the call waits for that.
    public func writeInstall(
        _ doc: [String: JSONValue], block: String, base: Int, at address: HostAddress,
        token: HostToken
    ) async throws(HostFailure) -> InstallWritten {
        let body: Components.Schemas.Edit = try Self.request([
            "doc": .object(doc), "base_rev": .integer(base),
        ])
        // A chain change answers only once the panel has restarted.
        let output = try await call(at: address, token: token, restartsPanel: true) {
            try await $0.writeInstallV1InstallBlockPut(path: .init(block: block), body: .json(body))
        }
        switch output {
        case .ok(let ok):
            let written = try Self.body { try ok.body.json }
            return InstallWritten(
                rev: written.rev, applies: .init(rawValue: written.applies.rawValue),
                chainChanged: written.chainChanged ?? [],
                calibration: written.calibration)
        case .conflict(let conflict):
            // A stale write carries the current revision; the refusal during a calibration
            // carries only the host's words. A stale body reads as a refusal too, so it goes first.
            let body = try Self.body { try conflict.body.json }
            if let stale = body.value1 { throw .stale(currentRev: stale.currentRev) }
            guard let refusal = body.value2 else { throw .unexpectedAnswer }
            throw .conflict(refusal.detail)
        case .unprocessableContent(let invalid):
            throw Self.invalid(try Self.body { try invalid.body.json })
        case .notFound: throw .notFound
        case .unauthorized, .undocumented: throw .unexpectedAnswer
        }
    }

    /// `GET /v1/host/devices`: the host's capture devices, each with how it streams where the
    /// host can read that, and why the list is empty where it is.
    public func captureDevices(at address: HostAddress, token: HostToken)
        async throws(HostFailure) -> (devices: [CaptureDevice], reason: String?)
    {
        let output = try await call(at: address, token: token) {
            try await $0.devicesV1HostDevicesGet()
        }
        guard case .ok(let ok) = output else { throw .unexpectedAnswer }
        let body = try Self.body { try ok.body.json }
        let devices = body.devices.map { device in
            CaptureDevice(
                name: device.name,
                streams: device.streams?.map {
                    CaptureDevice.Stream(format: $0.format, channels: $0.channels, rates: $0.rates)
                })
        }
        return (devices, body.reason)
    }
}
