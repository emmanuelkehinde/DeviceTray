import Foundation

enum SimulatorLinkError: LocalizedError, Equatable {
    case empty
    case containsWhitespace
    case invalid
    case missingScheme
    case missingHost

    var errorDescription: String? {
        switch self {
        case .empty:
            return "Enter a link to open."
        case .containsWhitespace:
            return "Links cannot contain spaces. Percent-encode them as %20."
        case .invalid:
            return "That is not a valid link."
        case .missingScheme:
            return "Add a scheme to the link, such as myapp:// or https://."
        case .missingHost:
            return "Web links need a host, such as https://example.com/path."
        }
    }
}

/// Checks text typed as a deep link or universal link before it goes to
/// `simctl openurl`.
enum SimulatorLink {
    /// Returns the URL for `text` after trimming surrounding whitespace.
    /// A scheme is required, and http and https links also need a host.
    static func url(from text: String) throws -> URL {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SimulatorLinkError.empty }
        guard !trimmed.contains(where: \.isWhitespace) else { throw SimulatorLinkError.containsWhitespace }
        guard let components = URLComponents(string: trimmed), let url = components.url else {
            throw SimulatorLinkError.invalid
        }
        guard let scheme = components.scheme?.lowercased(), !scheme.isEmpty else {
            throw SimulatorLinkError.missingScheme
        }
        if scheme == "http" || scheme == "https", components.host?.isEmpty ?? true {
            throw SimulatorLinkError.missingHost
        }
        return url
    }
}
