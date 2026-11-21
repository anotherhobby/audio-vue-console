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
    /// The host's capture devices, each with how it streams where the host can read that.
    public private(set) var devices: [CaptureDevice] = []
    /// The installed channel pair: the block's, else the schema's default.
    public private(set) var pair = InputChoice.firstPair
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
    private var defaultPair = InputChoice.firstPair
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
        device.map { name in devices.contains { $0.name == name } } ?? true
    }

    /// The host's listing of `name`, or nil for the default device or one not attached.
    public func listed(_ name: String?) -> CaptureDevice? {
        devices.first { $0.name == name }
    }

    /// The installed input, or nil until it is read.
    public var installed: InputChoice? {
        rate.map { InputChoice(device: device, rate: $0, format: format, pair: pair) }
    }

    /// The most channels the installed device streams in the installed format at the installed
    /// rate, or nil where the host does not say: a pair is offered over more than two.
    public var channels: Int? {
        rate.flatMap { listed(device)?.channels(format: format, rate: $0) }
    }

    /// `choice` as its device can stream it, among the formats and rates the schema declares
    /// (`InputChoice.fitted`), so no input the panel cannot open is written.
    public func fitted(_ choice: InputChoice) -> InputChoice {
        choice.fitted(to: listed(choice.device), formats: formats ?? [], rates: rates ?? [])
    }

    /// The schema's rates the installed device takes in the installed format, or all of them
    /// where the host does not say how it streams.
    private var offeredRates: [Int]? {
        rates.map { listed(device)?.rates(among: $0, format: format) ?? $0 }
    }

    /// The schema's formats the installed device streams, or all of them where the host does not
    /// say how it streams.
    private var offeredFormats: [String]? {
        formats.map { listed(device)?.formats(among: $0) ?? $0 }
    }

    /// Whether the host offers the installed rate on the installed device. Where the schema
    /// declares no rates, the installed rate is the only choice and counts as offered (design D1).
    public var isRateOffered: Bool {
        guard let rate, let offeredRates else { return true }
        return offeredRates.contains(rate)
    }

    /// The rates to choose from, lowest first: the schema's that the device takes, with the
    /// installed rate shown as it is where it is not among them.
    public var rateChoices: [Int] {
        let offered = offeredRates ?? []
        guard let rate, !offered.contains(rate) else { return offered }
        return (offered + [rate]).sorted()
    }

    /// Whether the host offers the installed format on the installed device. Where the schema
    /// declares no formats, the installed format is the only choice and counts as offered.
    public var isFormatOffered: Bool {
        guard let format, let offeredFormats else { return true }
        return offeredFormats.contains(format)
    }

    /// The formats to choose from: the schema's that the device streams, in its order, with the
    /// installed format shown as it is where it is not among them.
    public var formatChoices: [String] {
        let offered = offeredFormats ?? []
        guard let format, !offered.contains(format) else { return offered }
        return offered + [format]
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

    /// Writes `choice` into the block on the revision read, keeping its other keys. Returns
    /// whether the host holds it afterwards: stored, or found stored when an unanswered write
    /// reads the block again (`mac-output` design D1).
    @discardableResult
    public func write(_ choice: InputChoice) async -> Bool {
        let doc = InputEdit.doc(block: block.doc, choice: choice, defaultPair: defaultPair)
        isWriting = true
        defer { isWriting = false }
        do {
            let written = try await client.writeInstall(
                doc, block: "input", base: block.rev, at: address, token: pairing.token)
            block = InstallBlockState(doc: doc, rev: written.rev)
            device = choice.device
            rate = choice.rate
            format = choice.format ?? format
            pair = choice.pair
            note = .written(calibration: written.calibration)
        } catch {
            await refused(error)
            return error == .unreachable && holds(choice)
        }
        await readCalibrations()
        return true
    }

    /// Whether the block as last read holds `choice`, a nil format matching any.
    private func holds(_ choice: InputChoice) -> Bool {
        device == choice.device && rate == choice.rate && pair == choice.pair
            && (choice.format == nil || format == choice.format)
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
        case .invalid(let failures):
            // The host's own sentences, such as the pair a device cannot stream.
            note = .refused(failures.map(\.message).joined(separator: "; "))
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
        defaultPair = SchemaFacts.inputPairDefault(schema) ?? InputChoice.firstPair
        pair = input.doc["pair"]?.arrayValue.map { $0.compactMap(\.intValue) } ?? defaultPair
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
