/// How the app says cards are parked off the panel (`card-parking`, "The canvas says how many cards
/// are parked"), one wording for the canvas, the toolbar and the gallery.
public enum ParkingText {
    /// The gallery's note, such as "2 cards off the panel".
    public static func note(_ count: Int) -> String {
        "\(cards(count)) off the panel"
    }

    /// The canvas's line while cards are parked.
    public static func canvas(_ count: Int) -> String {
        let (verb, them) = count == 1 ? ("is", "it") : ("are", "them")
        return "\(cards(count)) \(verb) off the panel. Move \(them) onto the panel to save, apply "
            + "or duplicate this scene."
    }

    /// Why Save, Apply and Duplicate are disabled while a card is parked.
    public static let held = "Move the cards off the panel onto it first"

    private static func cards(_ count: Int) -> String {
        "\(count) \(count == 1 ? "card" : "cards")"
    }
}
