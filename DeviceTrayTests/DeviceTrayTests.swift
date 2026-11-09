import XCTest
@testable import DeviceTray

final class DeviceTrayTests: XCTestCase {
    func testAppTargetLoads() {
        XCTAssertNotNil(Bundle(for: DeviceTrayTests.self))
    }
}
