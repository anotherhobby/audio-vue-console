import Foundation
import Observation

/// One pairing with the host at an address: asking for a code, which the panel shows, and sending
/// back the digits the user reads off it for a token, which it keeps (`host-pairing`).
@MainActor @Observable
public final class HostPairing: Identifiable {
    public enum State: Equatable, Sendable {
        case idle
        case asking
        /// The panel shows a code, standing for the code's `ttl` and its `tries`.
        case showingCode(PairingCode)
        case confirming
        case paired
        case refused(PairingRefusal)
        /// A request went wrong in a way that is not a refusal: no host, or a strange answer.
        case failed(HostFailure)
        /// The host gave a token, but this Mac could not keep it, for the reason given.
        case notKept(String)
    }

    /// The code is six ASCII digits (audio-vue's `DIGITS`).
    public static let codeLength = 6

    public let address: HostAddress
    public private(set) var state = State.idle
    /// When the code last shown lapses, by its `ttl` from when it was asked for.
    public private(set) var codeLapsesAt: Date?
    /// When the host said asking again is allowed, after a `tooSoon` that named a wait.
    public private(set) var askAllowedAt: Date?
    /// Set when the code typed was not six digits, so nothing was sent.
    public private(set) var codeIsMalformed = false

    private let client: HostClient
    private let store: any TokenStore
    private let name: String
    private let onPaired: @MainActor (Pairing) -> Void

    /// A pairing that names this app `name` and calls `onPaired` once the token is kept.
    init(
        address: HostAddress, client: HostClient, store: any TokenStore, name: String,
        onPaired: @escaping @MainActor (Pairing) -> Void
    ) {
        self.address = address
        self.client = client
        self.store = store
        self.name = name
        self.onPaired = onPaired
    }

    /// Whether a request is under way, during which asking and confirming do nothing.
    public var isBusy: Bool {
        state == .asking || state == .confirming
    }

    /// Whether asking for a code makes sense at `now`: not while a request is under way, not while
    /// this app's own code still stands on the panel, since the host refuses a second code and a
    /// typo is fixed by sending the code again, and not before a wait the host named has passed.
    public func mayAsk(at now: Date) -> Bool {
        !isBusy && Self.mayAsk(at: now, codeLapsesAt: codeLapsesAt, askAllowedAt: askAllowedAt)
    }

    /// `mayAsk(at:)` from the two times alone, for a view showing a pairing's progress.
    public static func mayAsk(at now: Date, codeLapsesAt: Date?, askAllowedAt: Date?) -> Bool {
        let codeStands = codeLapsesAt.map { now < $0 } ?? false
        let waiting = askAllowedAt.map { now < $0 } ?? false
        return !codeStands && !waiting
    }

    /// Asks the host to show a code on its panel, when `mayAsk(at:)` allows it.
    public func ask() async {
        guard mayAsk(at: .now) else { return }
        codeIsMalformed = false
        state = .asking
        do {
            let code = try await client.askPairing(at: address, name: name)
            codeLapsesAt = .now + code.ttl
            askAllowedAt = nil
            state = .showingCode(code)
        } catch {
            fail(error)
        }
    }

    /// Sends the code the user typed. One that is not six digits is refused here, with nothing
    /// sent. Once the host gives a token, the host is read for its id, the app's earlier client on
    /// it revoked (design D2), and the pairing kept.
    public func confirm(_ code: String) async {
        guard !isBusy else { return }
        guard Self.isCode(code) else {
            codeIsMalformed = true
            return
        }
        codeIsMalformed = false
        state = .confirming
        let grant: PairingGrant
        let host: HostIdentity
        do {
            grant = try await client.confirmPairing(at: address, code: code)
            codeLapsesAt = nil  // The host took the code, so it no longer stands.
            host = try await client.host(at: address, token: grant.token)
        } catch {
            fail(error)
            return
        }
        await revokeEarlierClient(of: host.id, with: grant)
        keep(Pairing(hostID: host.id, token: grant.token, clientID: grant.clientID))
    }

    static func isCode(_ text: String) -> Bool {
        text.count == codeLength && text.allSatisfy { $0.isASCII && $0.isNumber }
    }

    private func fail(_ failure: HostFailure) {
        guard case .pairingRefused(let refusal) = failure else {
            state = .failed(failure)
            return
        }
        switch refusal.kind {
        case .tooSoon(let seconds?): askAllowedAt = .now + TimeInterval(seconds)
        case .noCode: codeLapsesAt = nil
        default: break
        }
        state = .refused(refusal)
    }

    /// Revokes the client this app was on the host before, so the host lists this Mac once. A
    /// failure leaves the old client listed for the user to revoke, and an unknown one is gone
    /// already, so neither stops the new pairing being kept.
    private func revokeEarlierClient(of hostID: String, with grant: PairingGrant) async {
        guard let earlier = store.pairing(forHost: hostID), earlier.clientID != grant.clientID
        else { return }
        do {
            try await client.revoke(earlier.clientID, at: address, token: grant.token)
        } catch {
            return
        }
    }

    private func keep(_ pairing: Pairing) {
        do {
            try store.save(pairing, at: address)
        } catch {
            state = .notKept(error.localizedDescription)
            return
        }
        state = .paired
        onPaired(pairing)
    }
}
