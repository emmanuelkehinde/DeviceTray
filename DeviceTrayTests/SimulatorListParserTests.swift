import XCTest
@testable import DeviceTray

final class SimulatorListParserTests: XCTestCase {
    private func fixtureData() throws -> Data {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "simctl-devices", withExtension: "json"))
        return try Data(contentsOf: url)
    }

    func testDecodesSimulatorFields() throws {
        let list = try JSONDecoder().decode(SimctlDeviceList.self, from: fixtureData())
        let ios16 = try XCTUnwrap(list.devices["com.apple.CoreSimulator.SimRuntime.iOS-16-4"])
        XCTAssertEqual(ios16, [
            Simulator(name: "iPhone 14", udid: "7A1C0D52-3B9E-4F6A-8D21-5E4B7C9A1F30", state: "Shutdown", isAvailable: true)
        ])
    }

    func testRuntimesAreNewestFirstAndEmptyOnesHidden() throws {
        let groups = try SimulatorListParser.groups(from: fixtureData())
        // iOS 17.2 only has an unavailable simulator, so it is hidden.
        XCTAssertEqual(groups.map(\.name), ["iOS 17.5", "iOS 16.4", "watchOS 10.4", "visionOS 1.2"])
    }

    func testUnavailableSimulatorsAreHidden() throws {
        let groups = try SimulatorListParser.groups(from: fixtureData())
        let names = groups.flatMap(\.simulators).map(\.name)
        XCTAssertFalse(names.contains("iPhone SE (3rd generation)"))
        XCTAssertFalse(names.contains("iPhone 15 Plus"))
    }

    func testBootedFirstThenByName() throws {
        let groups = try SimulatorListParser.groups(from: fixtureData())
        let ios175 = try XCTUnwrap(groups.first { $0.name == "iOS 17.5" })
        XCTAssertEqual(ios175.simulators.map(\.name), ["iPad Pro 11-inch", "iPhone 15", "iPhone 15 Pro"])
        XCTAssertEqual(ios175.simulators.map(\.isBooted), [true, true, false])
    }

    func testInvalidJSONThrows() {
        XCTAssertThrowsError(try SimulatorListParser.groups(from: Data("not json".utf8)))
    }

    func testEmptyDeviceListGivesNoGroups() throws {
        let groups = try SimulatorListParser.groups(from: Data(#"{"devices":{}}"#.utf8))
        XCTAssertTrue(groups.isEmpty)
    }
}
