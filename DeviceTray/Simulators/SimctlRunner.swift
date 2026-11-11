import Foundation

/// A simctl command that changes a simulator and has no output we need.
enum SimctlCommand: Equatable, Sendable {
    case boot(udid: String)
    case shutdown(udid: String)
    case openURL(udid: String, url: URL)

    /// Arguments passed to `xcrun`.
    var arguments: [String] {
        switch self {
        case .boot(let udid):
            return ["simctl", "boot", udid]
        case .shutdown(let udid):
            return ["simctl", "shutdown", udid]
        case .openURL(let udid, let url):
            return ["simctl", "openurl", udid, url.absoluteString]
        }
    }
}

/// Runs `xcrun simctl`. Tests replace this with a fake.
protocol SimctlRunning: Sendable {
    /// Returns the raw JSON from `xcrun simctl list devices --json`.
    func listDevicesJSON() async throws -> Data

    /// Runs `command` and throws if simctl exits with a non-zero status.
    func perform(_ command: SimctlCommand) async throws
}

enum SimctlError: LocalizedError, Equatable {
    case couldNotLaunch(String)
    case failed(status: Int32, message: String)

    var errorDescription: String? {
        switch self {
        case .couldNotLaunch(let reason):
            return "Could not run xcrun: \(reason)"
        case .failed(let status, let message):
            let detail = message.isEmpty ? "" : ": \(message)"
            return "simctl failed with exit code \(status)\(detail)"
        }
    }
}

struct SimctlRunner: SimctlRunning {
    func listDevicesJSON() async throws -> Data {
        // Process blocks, so run it off the main actor.
        try await Task.detached { try Self.run(["simctl", "list", "devices", "--json"]) }.value
    }

    func perform(_ command: SimctlCommand) async throws {
        let arguments = command.arguments
        _ = try await Task.detached { try Self.run(arguments) }.value
    }

    private static func run(_ arguments: [String]) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = arguments

        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors

        do {
            try process.run()
        } catch {
            throw SimctlError.couldNotLaunch(error.localizedDescription)
        }

        // Read stderr on another thread so a full pipe cannot block the child.
        nonisolated(unsafe) var errorData = Data()
        let errorRead = DispatchGroup()
        errorRead.enter()
        DispatchQueue.global().async {
            errorData = errors.fileHandleForReading.readDataToEndOfFile()
            errorRead.leave()
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        errorRead.wait()

        guard process.terminationStatus == 0 else {
            let message = String(decoding: errorData, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw SimctlError.failed(status: process.terminationStatus, message: message)
        }
        return data
    }
}
