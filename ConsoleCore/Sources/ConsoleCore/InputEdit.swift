/// The `input` install block's next document, from the block as stored and the device and rate the
/// user chose (design D2).
public enum InputEdit {
    /// `block` with `device` set, or removed for the default device, since unset means default,
    /// and `rate` set. Every other key is kept as the block holds it.
    public static func doc(block: [String: JSONValue], device: String?, rate: Int)
        -> [String: JSONValue]
    {
        var doc = block
        doc["device"] = device.map(JSONValue.string)
        doc["rate"] = .integer(rate)
        return doc
    }
}
