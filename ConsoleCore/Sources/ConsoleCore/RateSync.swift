/// How this Mac's output rate stands against the panel's capture rate (`mac-output`, "A rate
/// mismatch is shown"; design D5). It is the same whether or not Synchronize Rates is on.
public enum RateMatch: Equatable, Sendable {
    /// No output is chosen, or a rate on either side is not known.
    case noOutput
    case same
    case different(output: Int, capture: Int)
    /// The output cannot be set to the capture rate at all.
    case cannotPlay(capture: Int)

    public static func of(output: OutputCurrent?, device: OutputDevice?, capture: Int?) -> RateMatch
    {
        guard let output, let device, let capture else { return .noOutput }
        guard device.offers(capture) else { return .cannotPlay(capture: capture) }
        return output.rate == capture ? .same : .different(output: output.rate, capture: capture)
    }
}

/// The rules that keep a synchronized output at the capture rate, the capture rate leading
/// (`mac-output`; design D6). A change made elsewhere never reaches them, so it is never followed.
public enum RateSync {
    /// What choosing an output rate does.
    public enum Action: Equatable, Sendable {
        /// Set the output alone.
        case setOutput(Int)
        /// Write the capture rate first, then set the output once the host stores it.
        case writeCapture(Int)
    }

    /// The rate to set the output to once the host has stored `stored` as the capture rate, or nil
    /// where synchronization is off or there is nothing to set.
    public static func afterCapture(
        stored: Int, synchronized: Bool, output: OutputCurrent?, device: OutputDevice?
    ) -> Int? {
        guard synchronized else { return nil }
        return onSynchronize(capture: stored, output: output, device: device)
    }

    /// What choosing `rate` for the output does: the capture rate is written first while
    /// synchronized, unless it is already `rate`, when only the output needs setting.
    public static func onOutputChosen(_ rate: Int, synchronized: Bool, capture: Int?) -> Action {
        synchronized && rate != capture ? .writeCapture(rate) : .setOutput(rate)
    }

    /// The rate to set the output to as synchronization is turned on: the capture rate, where the
    /// output is not at it and offers it.
    public static func onSynchronize(capture: Int?, output: OutputCurrent?, device: OutputDevice?)
        -> Int?
    {
        guard
            case .different(_, let capture) = RateMatch.of(
                output: output, device: device, capture: capture)
        else { return nil }
        return capture
    }
}
