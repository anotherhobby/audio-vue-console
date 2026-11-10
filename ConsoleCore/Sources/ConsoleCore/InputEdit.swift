/// The `input` install block's next document, from the block as stored and the device, rate and
/// format the user chose (design D2; `mac-output` design D1).
public enum InputEdit {
    /// `block` with `device` set, or removed for the default device, since unset means default,
    /// `rate` set, and `format` set, or removed for the schema's default. Every other key is kept
    /// as the block holds it.
    public static func doc(
        block: [String: JSONValue], device: String?, rate: Int, format: String?
    ) -> [String: JSONValue] {
        var doc = block
        doc["device"] = device.map(JSONValue.string)
        doc["rate"] = .integer(rate)
        doc["fmt"] = format.map(JSONValue.string)
        return doc
    }
}
