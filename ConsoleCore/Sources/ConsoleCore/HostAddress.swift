import Foundation

/// A host agent's address as the user gives it: `host[:port]`, where the host is a hostname or an
/// IPv4 address. Its URLs are built from these validated parts, never from the text itself.
public struct HostAddress: Sendable, Hashable, CustomStringConvertible {
    /// The host agent's default port, audio-vue's `DEFAULT_PORT`.
    public static let defaultPort = 19200

    public let host: String
    public let port: Int
    private let base: URL

    private static let ports = 1...65535
    private static let maxHostnameLength = 253
    private static let labelLengths = 1...63
    private static let octetCount = 4
    private static let octets = 0...255

    /// Reads `text` as an address, or returns nil when it cannot be one. Surrounding whitespace is
    /// trimmed; a scheme, a path or an IPv6 address is not an address here.
    public init?(parsing text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Split at the first colon only: a second one leaves the port unreadable, which refuses it.
        let parts = trimmed.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard let host = parts.first, Self.isHost(host) else { return nil }
        var port = Self.defaultPort
        if let portText = parts.dropFirst().first {
            guard portText.allSatisfy(\.isASCIIDigit), let number = Int(portText),
                Self.ports.contains(number)
            else { return nil }
            port = number
        }
        var components = URLComponents()
        components.scheme = "http"
        components.host = String(host)
        components.port = port
        guard let base = components.url else { return nil }
        self.host = String(host)
        self.port = port
        self.base = base
    }

    /// The URL of an API path on this host, such as `v1/version`.
    public func url(path: String) -> URL {
        base.appending(path: path)
    }

    /// The address as it would be typed, leaving out the default port.
    public var description: String {
        port == Self.defaultPort ? host : "\(host):\(port)"
    }

    private static func isHost(_ host: Substring) -> Bool {
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        if labels.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isASCIIDigit) }) {
            return labels.count == octetCount
                && labels.allSatisfy { Int($0).map(octets.contains) ?? false }
        }
        return host.count <= maxHostnameLength && labels.allSatisfy(isLabel)
    }

    /// An RFC 1123 label: letters, digits and hyphens, not starting or ending with a hyphen.
    private static func isLabel(_ label: Substring) -> Bool {
        labelLengths.contains(label.count)
            && label.allSatisfy { $0.isASCIIDigit || $0.isASCIILetter || $0 == "-" }
            && label.first != "-" && label.last != "-"
    }
}

extension Character {
    fileprivate var isASCIIDigit: Bool { isASCII && isNumber }
    fileprivate var isASCIILetter: Bool { isASCII && isLetter }
}
