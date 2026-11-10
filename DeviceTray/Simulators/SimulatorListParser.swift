import Foundation

enum SimulatorListParser {
    /// Decodes simctl JSON into runtime groups. Unavailable simulators are
    /// dropped. Runtimes are newest first. Within a runtime, booted simulators
    /// come first, then the rest by name.
    static func groups(from data: Data) throws -> [RuntimeGroup] {
        let list = try JSONDecoder().decode(SimctlDeviceList.self, from: data)

        let groups = list.devices.compactMap { identifier, simulators -> (RuntimeName, RuntimeGroup)? in
            let visible = simulators.filter(\.isAvailable).sorted(by: bootedFirstThenName)
            guard !visible.isEmpty else { return nil }
            let runtime = RuntimeName(identifier: identifier)
            return (runtime, RuntimeGroup(identifier: identifier, name: runtime.displayName, simulators: visible))
        }

        return groups
            .sorted { $0.0.isNewer(than: $1.0) }
            .map(\.1)
    }

    private static func bootedFirstThenName(_ a: Simulator, _ b: Simulator) -> Bool {
        if a.isBooted != b.isBooted { return a.isBooted }
        let order = a.name.localizedStandardCompare(b.name)
        if order != .orderedSame { return order == .orderedAscending }
        return a.udid < b.udid
    }
}
