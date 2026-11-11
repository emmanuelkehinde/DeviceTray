import XCTest
@testable import DeviceTray

/// Records every command, fails them with `performError` if set, and can
/// hold a command until the test calls `release()`.
private actor RecordingRunner: SimctlRunning {
    private let listData: Data
    private let performError: Error?
    private let holdsCommands: Bool
    private var held: CheckedContinuation<Void, Never>?

    private(set) var commands: [SimctlCommand] = []
    private(set) var listCalls = 0

    init(listData: Data, performError: Error? = nil, holdsCommands: Bool = false) {
        self.listData = listData
        self.performError = performError
        self.holdsCommands = holdsCommands
    }

    func listDevicesJSON() async throws -> Data {
        listCalls += 1
        return listData
    }

    func perform(_ command: SimctlCommand) async throws {
        commands.append(command)
        if holdsCommands {
            await withCheckedContinuation { held = $0 }
        }
        if let performError { throw performError }
    }

    var isHoldingCommand: Bool { held != nil }

    func release() {
        held?.resume()
        held = nil
    }
}

@MainActor
private final class OpenCounter {
    var count = 0
}

@MainActor
final class SimulatorActionTests: XCTestCase {
    private let shutDownPhone = Simulator(
        name: "iPhone 15 Pro", udid: "B3E8F1A4-62C7-4D09-9A5B-0C1D2E3F4A51", state: "Shutdown", isAvailable: true)
    private let bootedPad = Simulator(
        name: "iPad Pro 11-inch", udid: "C94D2B67-1E3A-45F8-B7C0-8A9D6E5F4B32", state: "Booted", isAvailable: true)

    private func fixtureData() throws -> Data {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "simctl-devices", withExtension: "json"))
        return try Data(contentsOf: url)
    }

    private func makeModel(_ runner: RecordingRunner, opens: OpenCounter = OpenCounter()) -> SimulatorListViewModel {
        SimulatorListViewModel(runner: runner, openSimulatorApp: { opens.count += 1 })
    }

    func testBootRunsBootCommandThenRefreshes() async throws {
        let runner = RecordingRunner(listData: try fixtureData())
        let opens = OpenCounter()
        let model = makeModel(runner, opens: opens)

        await model.boot(shutDownPhone)

        let commands = await runner.commands
        let listCalls = await runner.listCalls
        XCTAssertEqual(commands, [.boot(udid: shutDownPhone.udid)])
        XCTAssertEqual(listCalls, 1)
        XCTAssertEqual(model.groups.count, 4)
        XCTAssertNil(model.actionErrorMessage)
        XCTAssertFalse(model.isBusy(shutDownPhone))
        XCTAssertEqual(opens.count, 1)
    }

    func testShutDownRunsShutdownCommandThenRefreshes() async throws {
        let runner = RecordingRunner(listData: try fixtureData())
        let opens = OpenCounter()
        let model = makeModel(runner, opens: opens)

        await model.shutDown(bootedPad)

        let commands = await runner.commands
        let listCalls = await runner.listCalls
        XCTAssertEqual(commands, [.shutdown(udid: bootedPad.udid)])
        XCTAssertEqual(listCalls, 1)
        XCTAssertNil(model.actionErrorMessage)
        XCTAssertEqual(opens.count, 0)
    }

    func testFailedBootSetsErrorRefreshesAndDoesNotOpenSimulatorApp() async throws {
        let failure = SimctlError.failed(status: 149, message: "Unable to boot device in current state: Booted")
        let runner = RecordingRunner(listData: try fixtureData(), performError: failure)
        let opens = OpenCounter()
        let model = makeModel(runner, opens: opens)

        await model.boot(shutDownPhone)

        let message = try XCTUnwrap(model.actionErrorMessage)
        XCTAssertTrue(message.hasPrefix("Could not boot iPhone 15 Pro."))
        XCTAssertTrue(message.contains("exit code 149"))
        let listCalls = await runner.listCalls
        XCTAssertEqual(listCalls, 1)
        // The list stays visible; only the action failed.
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(model.groups.count, 4)
        XCTAssertFalse(model.isBusy(shutDownPhone))
        XCTAssertEqual(opens.count, 0)
    }

    func testFailedShutDownNamesTheAction() async throws {
        let runner = RecordingRunner(listData: try fixtureData(), performError: SimctlError.couldNotLaunch("no xcrun"))
        let model = makeModel(runner)

        await model.shutDown(bootedPad)

        XCTAssertEqual(model.actionErrorMessage, "Could not shut down iPad Pro 11-inch. Could not run xcrun: no xcrun")
    }

    func testDismissActionErrorClearsIt() async throws {
        let runner = RecordingRunner(listData: try fixtureData(), performError: SimctlError.couldNotLaunch("no xcrun"))
        let model = makeModel(runner)
        await model.boot(shutDownPhone)
        XCTAssertNotNil(model.actionErrorMessage)

        model.dismissActionError()
        XCTAssertNil(model.actionErrorMessage)
    }

    func testSimulatorIsBusyWhileCommandRunsAndRepeatsAreIgnored() async throws {
        let runner = RecordingRunner(listData: try fixtureData(), holdsCommands: true)
        let model = makeModel(runner)

        let boot = Task { await model.boot(shutDownPhone) }
        try await waitUntil { await runner.isHoldingCommand }

        XCTAssertTrue(model.isBusy(shutDownPhone))
        XCTAssertFalse(model.isBusy(bootedPad))
        await model.boot(shutDownPhone)

        await runner.release()
        await boot.value

        let commands = await runner.commands
        XCTAssertEqual(commands, [.boot(udid: shutDownPhone.udid)])
        XCTAssertFalse(model.isBusy(shutDownPhone))
    }

    private func waitUntil(_ condition: () async -> Bool) async throws {
        for _ in 0..<1000 {
            if await condition() { return }
            await Task.yield()
        }
        XCTFail("Condition was never met")
    }
}
