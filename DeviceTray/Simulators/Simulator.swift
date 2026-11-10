import Foundation

/// One simulator as reported by `xcrun simctl list devices --json`.
struct Simulator: Codable, Identifiable, Equatable, Sendable {
    let name: String
    let udid: String
    let state: String
    let isAvailable: Bool

    var id: String { udid }
    var isBooted: Bool { state == "Booted" }
}

/// The top-level JSON object: simulators keyed by runtime identifier.
struct SimctlDeviceList: Codable, Equatable, Sendable {
    let devices: [String: [Simulator]]
}

/// Simulators that share one runtime, such as iOS 17.5.
struct RuntimeGroup: Identifiable, Equatable, Sendable {
    let identifier: String
    let name: String
    let simulators: [Simulator]

    var id: String { identifier }
}
