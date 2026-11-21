/// The `input` install block's next document, from the block as stored and the input the user
/// chose (design D2; `mac-output` design D1; `input-channels`).
public enum InputEdit {
    /// `block` with the choice's device set, or removed for the default device, since unset means
    /// default; its rate set; its format set, or removed for the schema's default; and its pair
    /// set, or removed where it is `defaultPair`, the schema's. Every other key is kept as the
    /// block holds it.
    public static func doc(
        block: [String: JSONValue], choice: InputChoice, defaultPair: [Int]
    ) -> [String: JSONValue] {
        var doc = block
        doc["device"] = choice.device.map(JSONValue.string)
        doc["rate"] = .integer(choice.rate)
        doc["fmt"] = choice.format.map(JSONValue.string)
        doc["pair"] =
            choice.pair == defaultPair ? nil : .array(choice.pair.map(JSONValue.integer))
        return doc
    }
}
