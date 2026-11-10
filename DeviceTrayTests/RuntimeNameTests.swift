import XCTest
@testable import DeviceTray

final class RuntimeNameTests: XCTestCase {
    private func name(_ suffix: String) -> RuntimeName {
        RuntimeName(identifier: "com.apple.CoreSimulator.SimRuntime.\(suffix)")
    }

    func testReadableNames() {
        XCTAssertEqual(name("iOS-17-5").displayName, "iOS 17.5")
        XCTAssertEqual(name("watchOS-10-4").displayName, "watchOS 10.4")
        XCTAssertEqual(name("tvOS-17-0").displayName, "tvOS 17.0")
        XCTAssertEqual(name("iOS-18-0-1").displayName, "iOS 18.0.1")
    }

    func testXrOSIsShownAsVisionOS() {
        XCTAssertEqual(name("xrOS-1-2").displayName, "visionOS 1.2")
        XCTAssertEqual(name("visionOS-2-0").displayName, "visionOS 2.0")
    }

    func testUnrecognisedIdentifierIsKeptAsIs() {
        XCTAssertEqual(RuntimeName(identifier: "something-odd").displayName, "something-odd")
        XCTAssertEqual(name("iOS").displayName, "com.apple.CoreSimulator.SimRuntime.iOS")
    }

    func testNewerVersionSortsFirst() {
        XCTAssertTrue(name("iOS-17-5").isNewer(than: name("iOS-17-2")))
        XCTAssertTrue(name("iOS-17-5").isNewer(than: name("iOS-16-4")))
        XCTAssertTrue(name("iOS-18-0").isNewer(than: name("iOS-17-5")))
        // 17.10 is newer than 17.9, which a string comparison gets wrong.
        XCTAssertTrue(name("iOS-17-10").isNewer(than: name("iOS-17-9")))
        XCTAssertFalse(name("iOS-17-2").isNewer(than: name("iOS-17-5")))
    }
}
