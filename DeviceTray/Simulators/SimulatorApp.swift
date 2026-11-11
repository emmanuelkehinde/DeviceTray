import AppKit

/// Simulator.app, which shows the screens of booted simulators.
enum SimulatorApp {
    static let bundleIdentifier = "com.apple.iphonesimulator"

    /// Opens Simulator.app, or brings it to the front if it is running.
    /// Does nothing if Xcode's Simulator.app cannot be found.
    @MainActor
    static func open() {
        let workspace = NSWorkspace.shared
        guard let url = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return }
        workspace.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
    }
}
