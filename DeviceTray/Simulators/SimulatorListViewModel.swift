import Foundation
import Observation

@MainActor
@Observable
final class SimulatorListViewModel {
    private(set) var groups: [RuntimeGroup] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    /// Simulators with a boot or shutdown still running.
    private(set) var busySimulatorIDs: Set<String> = []
    /// The last failed action. The list stays visible while this is set.
    private(set) var actionErrorMessage: String?

    @ObservationIgnored private let runner: any SimctlRunning
    @ObservationIgnored private let openSimulatorApp: @MainActor () -> Void

    init(
        runner: any SimctlRunning = SimctlRunner(),
        openSimulatorApp: @escaping @MainActor () -> Void = SimulatorApp.open
    ) {
        self.runner = runner
        self.openSimulatorApp = openSimulatorApp
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

    func dismissActionError() {
        actionErrorMessage = nil
    }

    /// Runs `command` unless `simulator` is already busy, sets
    /// `actionErrorMessage` on failure and reloads the list either way,
    /// because a failed command can still change a simulator's state.
    /// Returns true if the command succeeded.
    @discardableResult
    private func perform(_ command: SimctlCommand, on simulator: Simulator, verb: String) async -> Bool {
        guard !isBusy(simulator) else { return false }
        busySimulatorIDs.insert(simulator.id)
        actionErrorMessage = nil
        defer { busySimulatorIDs.remove(simulator.id) }

        var succeeded = true
        do {
            try await runner.perform(command)
        } catch {
            actionErrorMessage = "Could not \(verb) \(simulator.name). \(error.localizedDescription)"
            succeeded = false
        }
        await refresh()
        return succeeded
    }
}
