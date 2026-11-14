import XCTest
@testable import DeviceTray

final class SimctlCommandTests: XCTestCase {
    private let udid = "B3E8F1A4-62C7-4D09-9A5B-0C1D2E3F4A51"

    func testBootArguments() {
        XCTAssertEqual(SimctlCommand.boot(udid: udid).arguments, ["simctl", "boot", udid])
    }

    func testShutdownArguments() {
        XCTAssertEqual(SimctlCommand.shutdown(udid: udid).arguments, ["simctl", "shutdown", udid])
    }

    func testOpenURLArguments() throws {
        let url = try XCTUnwrap(URL(string: "myapp://orders/42?tab=details"))
        XCTAssertEqual(
            SimctlCommand.openURL(udid: udid, url: url).arguments,
            ["simctl", "openurl", udid, "myapp://orders/42?tab=details"])
    }

    func testPushArgumentsWithBundleID() {
        let payload = URL(fileURLWithPath: "/Users/me/Payloads/order shipped.json")
        XCTAssertEqual(
            SimctlCommand.push(udid: udid, bundleID: "com.example.app", payload: payload).arguments,
            ["simctl", "push", udid, "com.example.app", "/Users/me/Payloads/order shipped.json"])
    }

    func testPushArgumentsWithoutBundleIDLeaveItOut() {
        let payload = URL(fileURLWithPath: "/tmp/push.json")
        XCTAssertEqual(
            SimctlCommand.push(udid: udid, bundleID: nil, payload: payload).arguments,
            ["simctl", "push", udid, "/tmp/push.json"])
    }
}
