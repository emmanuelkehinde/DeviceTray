import Foundation

/// Turns a runtime identifier like `com.apple.CoreSimulator.SimRuntime.iOS-17-5`
/// into a readable name ("iOS 17.5") and a version used for sorting.
struct RuntimeName: Equatable, Sendable {
    let displayName: String
    let version: [Int]

    private static let prefix = "com.apple.CoreSimulator.SimRuntime."

    init(identifier: String) {
        let tail = identifier.hasPrefix(Self.prefix)
            ? String(identifier.dropFirst(Self.prefix.count))
            : identifier
        let parts = tail.split(separator: "-").map(String.init)
        let numbers = parts.dropFirst().compactMap { Int($0) }

        guard parts.count >= 2, numbers.count == parts.count - 1 else {
            displayName = identifier
            version = []
            return
        }

        // Simulator runtimes call visionOS "xrOS" in their identifiers.
        let platform = parts[0] == "xrOS" ? "visionOS" : parts[0]
        displayName = "\(platform) \(numbers.map(String.init).joined(separator: "."))"
        version = numbers
    }

    /// True if this runtime should be listed before `other` (newer version first).
    func isNewer(than other: RuntimeName) -> Bool {
        if version != other.version {
            return other.version.lexicographicallyPrecedes(version)
        }
        return displayName < other.displayName
    }
}
