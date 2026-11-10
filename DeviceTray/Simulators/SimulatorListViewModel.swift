import Foundation
import Observation

@MainActor
@Observable
final class SimulatorListViewModel {
    private(set) var groups: [RuntimeGroup] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    @ObservationIgnored private let runner: any SimctlRunning

    init(runner: any SimctlRunning = SimctlRunner()) {
        self.runner = runner
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
}
