import XCTest
@testable import DeviceTray

final class PushPayloadTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PushPayloadTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    private func write(_ text: String, name: String = "payload.json") throws -> String {
        let url = directory.appendingPathComponent(name)
        try Data(text.utf8).write(to: url)
        return url.path
    }

    private func error(path: String, bundleID: String = "com.example.app") -> PushPayloadError? {
        do {
            _ = try PushPayload.notification(path: path, bundleID: bundleID)
            return nil
        } catch {
            return error as? PushPayloadError
        }
    }

    func testAcceptsPayloadWithBundleID() throws {
        let path = try write(#"{"aps":{"alert":"Hello"}}"#)
        let notification = try PushPayload.notification(path: path, bundleID: " com.example.app\n")
        XCTAssertEqual(notification, PushNotification(payloadURL: URL(fileURLWithPath: path), bundleID: "com.example.app"))
    }

    func testTargetBundleKeyMakesBundleIDOptional() throws {
        let path = try write(#"{"Simulator Target Bundle":"com.example.app","aps":{"badge":3}}"#)
        let notification = try PushPayload.notification(path: path, bundleID: "  ")
        XCTAssertNil(notification.bundleID)
    }

    func testTypedBundleIDWinsOverTargetBundleKey() throws {
        let path = try write(#"{"Simulator Target Bundle":"com.example.app","aps":{"badge":3}}"#)
        let notification = try PushPayload.notification(path: path, bundleID: "com.example.other")
        XCTAssertEqual(notification.bundleID, "com.example.other")
    }

    func testRejectsMissingBundleID() throws {
        XCTAssertEqual(error(path: try write(#"{"aps":{"alert":"Hi"}}"#), bundleID: ""), .missingBundleID)
        XCTAssertEqual(
            error(path: try write(#"{"Simulator Target Bundle":"","aps":{}}"#), bundleID: ""), .missingBundleID)
        XCTAssertEqual(
            error(path: try write(#"{"Simulator Target Bundle":7,"aps":{}}"#), bundleID: ""), .missingBundleID)
    }

    func testRejectsBundleIDWithSpaces() throws {
        XCTAssertEqual(error(path: try write(#"{"aps":{}}"#), bundleID: "com.example app"), .invalidBundleID)
    }

    func testRejectsEmptyPath() {
        XCTAssertEqual(error(path: ""), .noFile)
        XCTAssertEqual(error(path: "  "), .noFile)
    }

    func testRejectsMissingFileAndDirectory() {
        let missing = directory.appendingPathComponent("missing.json").path
        XCTAssertEqual(error(path: missing), .fileNotFound(path: missing))
        XCTAssertEqual(error(path: directory.path), .fileNotFound(path: directory.path))
    }

    func testRejectsInvalidJSON() throws {
        XCTAssertEqual(error(path: try write(#"{"aps":"#)), .notJSON)
        XCTAssertEqual(error(path: try write("")), .notJSON)
    }

    func testRejectsNonObjectTopLevel() throws {
        XCTAssertEqual(error(path: try write(#"[{"aps":{}}]"#)), .notObject)
        XCTAssertEqual(error(path: try write(#""aps""#)), .notObject)
    }

    func testRejectsMissingOrNonDictionaryAPS() throws {
        XCTAssertEqual(error(path: try write(#"{"alert":"Hi"}"#)), .missingAPS)
        XCTAssertEqual(error(path: try write(#"{"aps":"Hi"}"#)), .missingAPS)
        XCTAssertEqual(error(path: try write(#"{"aps":[1]}"#)), .missingAPS)
    }

    func testRejectsPayloadOverSimctlLimit() throws {
        let filler = String(repeating: "a", count: PushPayload.maximumBytes)
        let path = try write(#"{"aps":{"alert":"\#(filler)"}}"#)
        let bytes = PushPayload.maximumBytes + #"{"aps":{"alert":""}}"#.utf8.count
        XCTAssertEqual(error(path: path), .tooLarge(bytes: bytes))
    }

    func testErrorMessagesNameTheFix() {
        XCTAssertEqual(
            PushPayloadError.missingBundleID.localizedDescription,
            "Enter a bundle ID, or add a \"Simulator Target Bundle\" key to the payload.")
        XCTAssertEqual(PushPayloadError.missingAPS.localizedDescription, "The payload needs an \"aps\" dictionary.")
    }
}
