import XCTest
@testable import DeviceTray

final class SimulatorLinkTests: XCTestCase {
    private func error(for text: String) -> SimulatorLinkError? {
        do {
            _ = try SimulatorLink.url(from: text)
            return nil
        } catch {
            return error as? SimulatorLinkError
        }
    }

    func testAcceptsDeepLinks() throws {
        XCTAssertEqual(try SimulatorLink.url(from: "myapp://orders/42").absoluteString, "myapp://orders/42")
        XCTAssertEqual(try SimulatorLink.url(from: "myapp:settings").absoluteString, "myapp:settings")
    }

    func testAcceptsUniversalLinks() throws {
        let url = try SimulatorLink.url(from: "https://example.com/orders/42?ref=push#top")
        XCTAssertEqual(url.absoluteString, "https://example.com/orders/42?ref=push#top")
    }

    func testTrimsSurroundingWhitespace() throws {
        XCTAssertEqual(try SimulatorLink.url(from: "  myapp://home\n").absoluteString, "myapp://home")
    }

    func testRejectsEmptyText() {
        XCTAssertEqual(error(for: ""), .empty)
        XCTAssertEqual(error(for: "   "), .empty)
    }

    func testRejectsMissingScheme() {
        XCTAssertEqual(error(for: "example.com/orders"), .missingScheme)
        XCTAssertEqual(error(for: "/orders/42"), .missingScheme)
        XCTAssertEqual(error(for: "://orders"), .missingScheme)
    }

    func testRejectsMalformedLinks() {
        XCTAssertEqual(error(for: "myapp://host:port"), .invalid)
    }

    func testRejectsWhitespaceInside() {
        XCTAssertEqual(error(for: "myapp://search?q=red shoes"), .containsWhitespace)
    }

    func testRejectsWebLinksWithoutHost() {
        XCTAssertEqual(error(for: "https:///orders"), .missingHost)
        XCTAssertEqual(error(for: "http:orders"), .missingHost)
    }
}
