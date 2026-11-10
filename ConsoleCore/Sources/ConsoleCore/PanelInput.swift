import Observation

/// The panel's capture device and rate, as the host's `input` install block holds them, with the
/// devices and rates a user may choose from, and their write back (`capture-input`, design D2).
@MainActor @Observable
public final class PanelInput {
    public enum State: Equatable, Sendable {
        case idle
        case loading
        case loaded
        /// The host refused the app's token, so the app is no longer paired.
        case unpaired
        case failed(HostFailure)
    }

    /// What the last write came to, for the section to word.
    public enum Note: Equatable, Sendable {
        /// The host stored the change, saying what it does to calibration where it changed the
        /// chain.
        case written(calibration: String?)
        /// The block changed elsewhere since it was read; the values shown are the host's now.
        case changedElsewhere
        /// The host refused the change, in its own words, as it does while a calibration has the
        /// panel.
        case refused(String)
        /// The host did not answer the write, so whether it was stored is not known; the values
        /// shown are the host's, read again.
        case unanswered
        /// The write did not reach the host, or it refused the values.
        case failed(HostFailure)
    }

    public private(set) var state = State.idle
    /// The installed capture device, or nil for the host's default device.
    public private(set) var device: String?
    /// The installed capture rate: the block's, else the schema's default. Nil until read.
    public private(set) var rate: Int?
    /// The host's capture devices, as ALSA names them.
    public private(set) var devices: [String] = []
    /// Why the host lists no device, where it lists none.
    public private(set) var devicesReason: String?
    /// The rates the host's schema declares for the input, lowest first, or nil where it declares
    /// none.
    public private(set) var rates: [Int]?
    /// The installed capture format, as ALSA names it: the block's, else the schema's default. Nil
    /// where neither gives one.
    public private(set) var format: String?
    /// The formats the host's schema declares for the input, in its order, or nil where it
    /// declares none.
    public private(set) var formats: [String]?
    /// Each rate's calibration for the installed device, a rate missing holding none; nil where
    /// the host's report could not be read, so no rate is marked.
    public private(set) var calibrations: [Int: CalibratedRate.Status]?
    public private(set) var note: Note?
    public private(set) var isWriting = false

    private var block = InstallBlockState(doc: [:], rev: 0)
    private let address: HostAddress
    private let client: HostClient
    private let pairing: Pairing
    private let store: any TokenStore
    private let onUnpaired: @MainActor () -> Void

    /// The input of the host `pairing` is for, calling `onUnpaired` once its token is forgotten.
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

    /// Whether the installed device is one the host lists; the default device always is.
    public var isDeviceAttached: Bool {
        device.map(devices.contains) ?? true
    }

    /// Whether the host offers the installed rate. Where the schema declares no rates, the
    /// installed rate is the only choice and counts as offered (design D1).
    public var isRateOffered: Bool {
        guard let rate, let rates else { return true }
        return rates.contains(rate)
    }

    /// The rates to choose from, lowest first: the schema's, with the installed rate shown as it
    /// is where the schema does not declare it.
    public var rateChoices: [Int] {
        let declared = rates ?? []
        guard let rate, !declared.contains(rate) else { return declared }
        return (declared + [rate]).sorted()
    }

    /// Whether the host offers the installed format. Where the schema declares no formats, the
    /// installed format is the only choice and counts as offered.
    public var isFormatOffered: Bool {
        guard let format, let formats else { return true }
        return formats.contains(format)
    }

    /// The formats to choose from: the schema's, in its order, with the installed format shown as
    /// it is where the schema does not declare it.
    public var formatChoices: [String] {
        let declared = formats ?? []
        guard let format, !declared.contains(format) else { return declared }
        return declared + [format]
    }

    /// Reads the `input` block with its revision, the schema's rates and the host's devices.
    public func load() async {
        state = .loading
        do {
            let blocks = try await client.installBlocks(at: address, token: pairing.token)
            let schema = try await client.schema(at: address, token: pairing.token)
            let listed = try await client.captureDevices(at: address, token: pairing.token)
            let input = blocks["input"] ?? InstallBlockState(doc: [:], rev: 0)
            show(input, schema: schema)
            devices = listed.devices
            devicesReason = listed.reason
            state = .loaded
        } catch {
            fail(error)
            return
        }
        await readCalibrations()
    }

    /// Writes `device`, `rate` and `format` into the block on the revision read, keeping its other
    /// keys. Returns whether the host holds them afterwards: stored, or found stored when an
    /// unanswered write reads the block again (`mac-output` design D1).
    @discardableResult
    public func write(device: String?, rate: Int, format: String?) async -> Bool {
        let doc = InputEdit.doc(block: block.doc, device: device, rate: rate, format: format)
        isWriting = true
        defer { isWriting = false }
        do {
            let written = try await client.writeInstall(
                doc, block: "input", base: block.rev, at: address, token: pairing.token)
            block = InstallBlockState(doc: doc, rev: written.rev)
            self.device = device
            self.rate = rate
            self.format = format ?? self.format
            note = .written(calibration: written.calibration)
        } catch {
            await refused(error)
            return error == .unreachable && holds(device: device, rate: rate, format: format)
        }
        await readCalibrations()
        return true
    }

    /// Whether the block as last read holds `device`, `rate` and `format`, a nil format matching
    /// any.
    private func holds(device: String?, rate: Int, format: String?) -> Bool {
        self.device == device && self.rate == rate && (format == nil || self.format == format)
    }

    /// Reads which rates hold a calibration for the installed device, leaving every rate unmarked
    /// where the host's report cannot be read.
    private func readCalibrations() async {
        do {
            let rates = try await client.calibratedRates(at: address, token: pairing.token)
            calibrations = Dictionary(uniqueKeysWithValues: rates.map { ($0.rate, $0.status) })
        } catch {
            calibrations = nil
        }
    }

    /// Ends the hold after a calibration run by sending the panel a cancel, which keeps the run's
    /// record and returns the panel to its scene and installed input (design D11).
    public func endHold() async {
        do {
            let answer = try await client.cancelCalibration(at: address, token: pairing.token)
            if case .done = answer.outcome {
                note = nil
            } else {
                note = .refused(CalibrationSession.words(answer.outcome))
            }
        } catch {
            guard error == .tokenRefused else {
                note = .failed(error)
                return
            }
            fail(error)
        }
    }

    private func refused(_ failure: HostFailure) async {
        switch failure {
        case .tokenRefused:
            fail(failure)
        case .stale:
            await load()
            note = .changedElsewhere
        case .conflict(let words):
            note = .refused(words)
        case .unreachable:
            await load()
            note = .unanswered
        default:
            note = .failed(failure)
        }
    }

    private func show(_ input: InstallBlockState, schema: JSONValue) {
        block = input
        device = input.doc["device"]?.stringValue
        rate = CalibrationRuns.rate(install: ["input": .object(input.doc)], schema: schema)
        rates = SchemaFacts.inputRates(schema)
        format = input.doc["fmt"]?.stringValue ?? SchemaFacts.inputFormatDefault(schema)
        formats = SchemaFacts.inputFormats(schema)
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
