import XCTest
@testable import DeviceTray

private struct FakeRunner: SimctlRunning {
    let result: Result<Data, Error>

    func listDevicesJSON() async throws -> Data {
        try result.get()
    }
}

/// Returns each result in turn, so a test can change the output between refreshes.
private actor SequenceRunner: SimctlRunning {
    private var results: [Result<Data, Error>]

    init(_ results: [Result<Data, Error>]) {
        self.results = results
    }

    func listDevicesJSON() async throws -> Data {
        try results.removeFirst().get()
    }
}

@MainActor
final class SimulatorListViewModelTests: XCTestCase {
    private func fixtureData() throws -> Data {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "simctl-devices", withExtension: "json"))
        return try Data(contentsOf: url)
    }

    func testStartsIdle() {
        let model = SimulatorListViewModel(runner: FakeRunner(result: .success(Data())))
        XCTAssertTrue(model.groups.isEmpty)
        XCTAssertFalse(model.isLoading)
        XCTAssertNil(model.errorMessage)
    }

    func testRefreshLoadsGroups() async throws {
        let model = SimulatorListViewModel(runner: FakeRunner(result: .success(try fixtureData())))
        await model.refresh()
        XCTAssertEqual(model.groups.map(\.name), ["iOS 17.5", "iOS 16.4", "watchOS 10.4", "visionOS 1.2"])
        XCTAssertFalse(model.isLoading)
        XCTAssertNil(model.errorMessage)
    }

    func testRunnerFailureSetsErrorMessage() async {
        let failure = SimctlError.failed(status: 72, message: "xcrun: error: unable to find utility \"simctl\"")
        let model = SimulatorListViewModel(runner: FakeRunner(result: .failure(failure)))
        await model.refresh()
        XCTAssertTrue(model.groups.isEmpty)
        XCTAssertFalse(model.isLoading)
        XCTAssertEqual(model.errorMessage, failure.localizedDescription)
        XCTAssertTrue(model.errorMessage?.contains("exit code 72") == true)
    }

    func testBadJSONSetsErrorMessage() async {
        let model = SimulatorListViewModel(runner: FakeRunner(result: .success(Data("nope".utf8))))
        await model.refresh()
        XCTAssertTrue(model.groups.isEmpty)
        XCTAssertNotNil(model.errorMessage)
    }

    func testRefreshAfterFailureRecovers() async throws {
        let runner = SequenceRunner([
            .failure(SimctlError.couldNotLaunch("no xcrun")),
            .success(try fixtureData()),
        ])
        let model = SimulatorListViewModel(runner: runner)

        await model.refresh()
        XCTAssertNotNil(model.errorMessage)

        await model.refresh()
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(model.groups.count, 4)
    }

    func testRefreshReplacesOldList() async throws {
        let runner = SequenceRunner([
            .success(try fixtureData()),
            .success(Data(#"{"devices":{}}"#.utf8)),
        ])
        let model = SimulatorListViewModel(runner: runner)
        await model.refresh()
        XCTAssertFalse(model.groups.isEmpty)
        await model.refresh()
        XCTAssertTrue(model.groups.isEmpty)
        XCTAssertNil(model.errorMessage)
    }
}
