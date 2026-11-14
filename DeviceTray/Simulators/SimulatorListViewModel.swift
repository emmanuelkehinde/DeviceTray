import Foundation
import Observation

@MainActor
@Observable
final class SimulatorListViewModel {
    private(set) var groups: [RuntimeGroup] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    /// Simulators with a boot, shutdown, link or push still running.
    private(set) var busySimulatorIDs: Set<String> = []
    /// The last failed action. The list stays visible while this is set.
    private(set) var actionErrorMessage: String?
    /// Confirms the last action that has no visible result, such as a push.
    /// Only one of this and `actionErrorMessage` is set at a time.
    private(set) var actionSuccessMessage: String?

    /// The last chosen push payload file, kept in UserDefaults.
    var pushPayloadPath: String {
        didSet { defaults.set(pushPayloadPath, forKey: DefaultsKey.pushPayloadPath) }
    }
    /// The last bundle ID entered for a push, kept in UserDefaults.
    var pushBundleID: String {
        didSet { defaults.set(pushBundleID, forKey: DefaultsKey.pushBundleID) }
    }

    @ObservationIgnored private let runner: any SimctlRunning
    @ObservationIgnored private let openSimulatorApp: @MainActor () -> Void
    @ObservationIgnored private let defaults: UserDefaults

    enum DefaultsKey {
        static let pushPayloadPath = "pushPayloadPath"
        static let pushBundleID = "pushBundleID"
    }

    init(
        runner: any SimctlRunning = SimctlRunner(),
        openSimulatorApp: @escaping @MainActor () -> Void = SimulatorApp.open,
        defaults: UserDefaults = .standard
    ) {
        self.runner = runner
        self.openSimulatorApp = openSimulatorApp
        self.defaults = defaults
        pushPayloadPath = defaults.string(forKey: DefaultsKey.pushPayloadPath) ?? ""
        pushBundleID = defaults.string(forKey: DefaultsKey.pushBundleID) ?? ""
    }

    /// Loads the simulator list. Does nothing if a load is already running.
    /// On failure the previous list is cleared and `errorMessage` is set.
    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let data = try await runner.listDevicesJSON()
            groups = try SimulatorListParser.groups(from: data)
        } catch {
            groups = []
            errorMessage = error.localizedDescription
        }
    }

    func isBusy(_ simulator: Simulator) -> Bool {
        busySimulatorIDs.contains(simulator.id)
    }

    /// Boots `simulator`, opens Simulator.app if the boot worked, then reloads the list.
    func boot(_ simulator: Simulator) async {
        if await perform(.boot(udid: simulator.udid), on: simulator, verb: "boot") {
            openSimulatorApp()
        }
    }

    /// Shuts down `simulator`, then reloads the list.
    func shutDown(_ simulator: Simulator) async {
        await perform(.shutdown(udid: simulator.udid), on: simulator, verb: "shut down")
    }

    /// Opens a deep link or universal link in a booted simulator.
    /// Returns true if simctl opened it.
    @discardableResult
    func openLink(_ text: String, on simulator: Simulator) async -> Bool {
        let verb = "open the link on"
        guard simulator.isBooted else {
            showActionError("Could not \(verb) \(simulator.name). Boot it first.")
            return false
        }
        let url: URL
        do {
            url = try SimulatorLink.url(from: text)
        } catch {
            showActionError(error.localizedDescription)
            return false
        }
        // Opening a link does not change the list, so skip the reload.
        return await perform(.openURL(udid: simulator.udid, url: url), on: simulator, verb: verb, refreshAfter: false)
    }

    /// Sends the payload at `pushPayloadPath` to a booted simulator with
    /// `simctl push`, using `pushBundleID` or the payload's
    /// "Simulator Target Bundle". Returns true if simctl sent it.
    @discardableResult
    func sendPush(to simulator: Simulator) async -> Bool {
        let verb = "send the notification to"
        guard simulator.isBooted else {
            showActionError("Could not \(verb) \(simulator.name). Boot it first.")
            return false
        }
        let notification: PushNotification
        do {
            notification = try PushPayload.notification(path: pushPayloadPath, bundleID: pushBundleID)
        } catch {
            showActionError(error.localizedDescription)
            return false
        }
        let command = SimctlCommand.push(
            udid: simulator.udid, bundleID: notification.bundleID, payload: notification.payloadURL)
        // A push does not change the list, so skip the reload.
        guard await perform(command, on: simulator, verb: verb, refreshAfter: false) else { return false }
        actionSuccessMessage = "Sent \(notification.payloadURL.lastPathComponent) to \(simulator.name)."
        return true
    }

    func dismissActionError() {
        actionErrorMessage = nil
    }

    func dismissActionSuccess() {
        actionSuccessMessage = nil
    }

    private func showActionError(_ message: String) {
        actionSuccessMessage = nil
        actionErrorMessage = message
    }

    /// Runs `command` unless `simulator` is already busy and sets
    /// `actionErrorMessage` on failure. With `refreshAfter`, reloads the list
    /// whether or not the command worked, because a failed command can still
    /// change a simulator's state. Returns true if the command succeeded.
    @discardableResult
    private func perform(
        _ command: SimctlCommand, on simulator: Simulator, verb: String, refreshAfter: Bool = true
    ) async -> Bool {
        guard !isBusy(simulator) else { return false }
        busySimulatorIDs.insert(simulator.id)
        actionErrorMessage = nil
        actionSuccessMessage = nil
        defer { busySimulatorIDs.remove(simulator.id) }

        var succeeded = true
        do {
            try await runner.perform(command)
        } catch {
            showActionError("Could not \(verb) \(simulator.name). \(error.localizedDescription)")
            succeeded = false
        }
        if refreshAfter {
            await refresh()
        }
        return succeeded
    }
}
