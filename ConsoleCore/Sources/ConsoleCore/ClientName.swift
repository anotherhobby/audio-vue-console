import Foundation

/// The name this app gives itself when it pairs: the Mac's computer name, so the host's list of
/// clients says which Mac each is (`host-pairing`, design D8).
public enum ClientName {
    /// The most a host takes, in characters as Python counts them, which are Unicode scalars.
    public static let maxLength = 64
    static let fallback = "audio-vue console"

    /// The computer name, as Sharing in System Settings gives it, cut to fit.
    public static var current: String {
        fitted(Host.current().localizedName ?? "")
    }

    /// `name` cut to its first `maxLength` scalars, or the app's name where it is empty, since the
    /// host refuses an empty name.
    static func fitted(_ name: String) -> String {
        guard !name.isEmpty else { return fallback }
        var scalars = String.UnicodeScalarView()
        scalars.append(contentsOf: name.unicodeScalars.prefix(maxLength))
        return String(scalars)
    }
}
