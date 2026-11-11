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
}
