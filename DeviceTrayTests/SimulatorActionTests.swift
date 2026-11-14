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

@MainActor
final class OpenLinkActionTests: XCTestCase {
    private let shutDownPhone = Simulator(
        name: "iPhone 15 Pro", udid: "B3E8F1A4-62C7-4D09-9A5B-0C1D2E3F4A51", state: "Shutdown", isAvailable: true)
    private let bootedPad = Simulator(
        name: "iPad Pro 11-inch", udid: "C94D2B67-1E3A-45F8-B7C0-8A9D6E5F4B32", state: "Booted", isAvailable: true)

    private func makeModel(_ runner: RecordingRunner) -> SimulatorListViewModel {
        SimulatorListViewModel(runner: runner, openSimulatorApp: {})
    }

    func testOpensValidLinkWithoutReloadingList() async throws {
        let runner = RecordingRunner(listData: Data())
        let model = makeModel(runner)

        let opened = await model.openLink(" myapp://orders/42 ", on: bootedPad)

        XCTAssertTrue(opened)
        let commands = await runner.commands
        let listCalls = await runner.listCalls
        XCTAssertEqual(commands, [.openURL(udid: bootedPad.udid, url: try XCTUnwrap(URL(string: "myapp://orders/42")))])
        XCTAssertEqual(listCalls, 0)
        XCTAssertNil(model.actionErrorMessage)
        XCTAssertFalse(model.isBusy(bootedPad))
    }

    func testInvalidLinkShowsErrorAndRunsNothing() async {
        let runner = RecordingRunner(listData: Data())
        let model = makeModel(runner)

        let opened = await model.openLink("example.com/orders", on: bootedPad)

        XCTAssertFalse(opened)
        let commands = await runner.commands
        XCTAssertTrue(commands.isEmpty)
        XCTAssertEqual(model.actionErrorMessage, SimulatorLinkError.missingScheme.localizedDescription)
    }

    func testShutDownSimulatorIsRejected() async {
        let runner = RecordingRunner(listData: Data())
        let model = makeModel(runner)

        let opened = await model.openLink("myapp://home", on: shutDownPhone)

        XCTAssertFalse(opened)
        let commands = await runner.commands
        XCTAssertTrue(commands.isEmpty)
        XCTAssertEqual(model.actionErrorMessage, "Could not open the link on iPhone 15 Pro. Boot it first.")
    }

    func testSimctlFailureShowsError() async {
        let failure = SimctlError.failed(status: 1, message: "The operation couldn't be completed.")
        let runner = RecordingRunner(listData: Data(), performError: failure)
        let model = makeModel(runner)

        let opened = await model.openLink("myapp://home", on: bootedPad)

        XCTAssertFalse(opened)
        let message = model.actionErrorMessage ?? ""
        XCTAssertTrue(message.hasPrefix("Could not open the link on iPad Pro 11-inch."))
        XCTAssertTrue(message.contains("exit code 1"))
    }
}

@MainActor
final class SendPushActionTests: XCTestCase {
    private let shutDownPhone = Simulator(
        name: "iPhone 15 Pro", udid: "B3E8F1A4-62C7-4D09-9A5B-0C1D2E3F4A51", state: "Shutdown", isAvailable: true)
    private let bootedPad = Simulator(
        name: "iPad Pro 11-inch", udid: "C94D2B67-1E3A-45F8-B7C0-8A9D6E5F4B32", state: "Booted", isAvailable: true)

    // XCTest makes a new instance for each test, so each test gets its own
    // defaults suite and folder.
    private let suiteName = "SendPushActionTests-\(UUID().uuidString)"
    private lazy var defaults = UserDefaults(suiteName: suiteName)!
    private lazy var directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(suiteName, isDirectory: true)

    override func setUp() async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        try FileManager.default.removeItem(at: directory)
    }

    private func makeModel(_ runner: RecordingRunner) -> SimulatorListViewModel {
        SimulatorListViewModel(runner: runner, openSimulatorApp: {}, defaults: defaults)
    }

    private func writePayload(_ text: String, name: String = "shipped.json") throws -> String {
        let url = directory.appendingPathComponent(name)
        try Data(text.utf8).write(to: url)
        return url.path
    }

    func testSendsPushWithBundleIDWithoutReloadingList() async throws {
        let path = try writePayload(#"{"aps":{"alert":"Your order shipped"}}"#)
        let runner = RecordingRunner(listData: Data())
        let model = makeModel(runner)
        model.pushPayloadPath = path
        model.pushBundleID = "com.example.shop"

        let sent = await model.sendPush(to: bootedPad)

        XCTAssertTrue(sent)
        let commands = await runner.commands
        let listCalls = await runner.listCalls
        XCTAssertEqual(
            commands,
            [.push(udid: bootedPad.udid, bundleID: "com.example.shop", payload: URL(fileURLWithPath: path))])
        XCTAssertEqual(listCalls, 0)
        XCTAssertNil(model.actionErrorMessage)
        XCTAssertEqual(model.actionSuccessMessage, "Sent shipped.json to iPad Pro 11-inch.")
        XCTAssertFalse(model.isBusy(bootedPad))
    }

    func testSendsPushWithoutBundleIDWhenPayloadNamesTarget() async throws {
        let path = try writePayload(#"{"Simulator Target Bundle":"com.example.shop","aps":{"badge":1}}"#)
        let runner = RecordingRunner(listData: Data())
        let model = makeModel(runner)
        model.pushPayloadPath = path

        let sent = await model.sendPush(to: bootedPad)

        XCTAssertTrue(sent)
        let commands = await runner.commands
        XCTAssertEqual(commands, [.push(udid: bootedPad.udid, bundleID: nil, payload: URL(fileURLWithPath: path))])
    }

    func testInvalidPayloadShowsErrorAndRunsNothing() async throws {
        let runner = RecordingRunner(listData: Data())
        let model = makeModel(runner)
        model.pushPayloadPath = try writePayload(#"{"alert":"No aps"}"#)
        model.pushBundleID = "com.example.shop"

        let sent = await model.sendPush(to: bootedPad)

        XCTAssertFalse(sent)
        let commands = await runner.commands
        XCTAssertTrue(commands.isEmpty)
        XCTAssertEqual(model.actionErrorMessage, PushPayloadError.missingAPS.localizedDescription)
        XCTAssertNil(model.actionSuccessMessage)
    }

    func testMissingBundleIDShowsError() async throws {
        let runner = RecordingRunner(listData: Data())
        let model = makeModel(runner)
        model.pushPayloadPath = try writePayload(#"{"aps":{"alert":"Hi"}}"#)

        let sent = await model.sendPush(to: bootedPad)

        XCTAssertFalse(sent)
        XCTAssertEqual(model.actionErrorMessage, PushPayloadError.missingBundleID.localizedDescription)
    }

    func testShutDownSimulatorIsRejected() async throws {
        let runner = RecordingRunner(listData: Data())
        let model = makeModel(runner)
        model.pushPayloadPath = try writePayload(#"{"aps":{"alert":"Hi"}}"#)
        model.pushBundleID = "com.example.shop"

        let sent = await model.sendPush(to: shutDownPhone)

        XCTAssertFalse(sent)
        let commands = await runner.commands
        XCTAssertTrue(commands.isEmpty)
        XCTAssertEqual(model.actionErrorMessage, "Could not send the notification to iPhone 15 Pro. Boot it first.")
    }

    func testSimctlFailureShowsErrorAndClearsEarlierSuccess() async throws {
        let model = makeModel(RecordingRunner(listData: Data()))
        model.pushPayloadPath = try writePayload(#"{"aps":{"alert":"Hi"}}"#)
        model.pushBundleID = "com.example.shop"
        await model.sendPush(to: bootedPad)
        XCTAssertNotNil(model.actionSuccessMessage)

        let failure = SimctlError.failed(status: 22, message: "Invalid device: Shutdown")
        let failing = SimulatorListViewModel(
            runner: RecordingRunner(listData: Data(), performError: failure), openSimulatorApp: {}, defaults: defaults)
        let sent = await failing.sendPush(to: bootedPad)

        XCTAssertFalse(sent)
        let message = try XCTUnwrap(failing.actionErrorMessage)
        XCTAssertTrue(message.hasPrefix("Could not send the notification to iPad Pro 11-inch."))
        XCTAssertTrue(message.contains("exit code 22"))
        XCTAssertNil(failing.actionSuccessMessage)
    }

    func testValidationErrorReplacesSuccessMessage() async throws {
        let model = makeModel(RecordingRunner(listData: Data()))
        model.pushPayloadPath = try writePayload(#"{"aps":{"alert":"Hi"}}"#)
        model.pushBundleID = "com.example.shop"
        await model.sendPush(to: bootedPad)
        XCTAssertNotNil(model.actionSuccessMessage)

        model.pushPayloadPath = ""
        await model.sendPush(to: bootedPad)

        XCTAssertNil(model.actionSuccessMessage)
        XCTAssertEqual(model.actionErrorMessage, PushPayloadError.noFile.localizedDescription)
    }

    func testDismissActionSuccessClearsIt() async throws {
        let model = makeModel(RecordingRunner(listData: Data()))
        model.pushPayloadPath = try writePayload(#"{"aps":{"alert":"Hi"}}"#)
        model.pushBundleID = "com.example.shop"
        await model.sendPush(to: bootedPad)

        model.dismissActionSuccess()
        XCTAssertNil(model.actionSuccessMessage)
    }

    func testRemembersPayloadPathAndBundleID() {
        let first = makeModel(RecordingRunner(listData: Data()))
        XCTAssertEqual(first.pushPayloadPath, "")
        XCTAssertEqual(first.pushBundleID, "")

        first.pushPayloadPath = "/Users/me/Payloads/shipped.json"
        first.pushBundleID = "com.example.shop"

        let second = makeModel(RecordingRunner(listData: Data()))
        XCTAssertEqual(second.pushPayloadPath, "/Users/me/Payloads/shipped.json")
        XCTAssertEqual(second.pushBundleID, "com.example.shop")
    }
}
