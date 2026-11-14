import Foundation

enum PushPayloadError: LocalizedError, Equatable {
    case noFile
    case fileNotFound(path: String)
    case unreadable(path: String)
    case tooLarge(bytes: Int)
    case notJSON
    case notObject
    case missingAPS
    case missingBundleID
    case invalidBundleID

    var errorDescription: String? {
        switch self {
        case .noFile:
            return "Choose a JSON payload file."
        case .fileNotFound(let path):
            return "No payload file at \(path)."
        case .unreadable(let path):
            return "Could not read the payload file at \(path)."
        case .tooLarge(let bytes):
            return "The payload is \(bytes) bytes. simctl accepts \(PushPayload.maximumBytes) bytes or less."
        case .notJSON:
            return "The payload file is not valid JSON."
        case .notObject:
            return "The payload must be a JSON object at the top level."
        case .missingAPS:
            return "The payload needs an \"aps\" dictionary."
        case .missingBundleID:
            return "Enter a bundle ID, or add a \"\(PushPayload.targetBundleKey)\" key to the payload."
        case .invalidBundleID:
            return "Bundle IDs cannot contain spaces."
        }
    }
}

/// A checked payload file and the bundle ID to pass to `simctl push`.
struct PushNotification: Equatable, Sendable {
    let payloadURL: URL
    /// Nil when the payload names its app with "Simulator Target Bundle".
    let bundleID: String?
}

/// Checks a push payload file and bundle ID before they go to `simctl push`.
enum PushPayload {
    /// The top-level key simctl reads when no bundle ID is passed.
    static let targetBundleKey = "Simulator Target Bundle"
    /// simctl rejects payloads larger than this.
    static let maximumBytes = 4096

    /// Reads and checks the file at `path`. The file must be a JSON object of
    /// at most 4096 bytes with an "aps" dictionary. `bundleID` is trimmed and
    /// may be empty only if the payload has a "Simulator Target Bundle" string.
    /// A typed bundle ID wins over the payload's, as it does in simctl.
    static func notification(path: String, bundleID: String) throws -> PushNotification {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else { throw PushPayloadError.noFile }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: trimmedPath, isDirectory: &isDirectory), !isDirectory.boolValue else {
            throw PushPayloadError.fileNotFound(path: trimmedPath)
        }
        let url = URL(fileURLWithPath: trimmedPath)
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw PushPayloadError.unreadable(path: trimmedPath)
        }
        let targetBundle = try targetBundle(in: data)

        let trimmedBundleID = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedBundleID.isEmpty {
            guard targetBundle != nil else { throw PushPayloadError.missingBundleID }
            return PushNotification(payloadURL: url, bundleID: nil)
        }
        guard !trimmedBundleID.contains(where: \.isWhitespace) else { throw PushPayloadError.invalidBundleID }
        return PushNotification(payloadURL: url, bundleID: trimmedBundleID)
    }

    /// Checks the payload JSON and returns its "Simulator Target Bundle"
    /// value, or nil if the key is missing, empty or not a string.
    static func targetBundle(in data: Data) throws -> String? {
        guard data.count <= maximumBytes else { throw PushPayloadError.tooLarge(bytes: data.count) }
        let json: Any
        do {
            json = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw PushPayloadError.notJSON
        }
        guard let object = json as? [String: Any] else { throw PushPayloadError.notObject }
        guard object["aps"] is [String: Any] else { throw PushPayloadError.missingAPS }

        let target = (object[targetBundleKey] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return target?.isEmpty == false ? target : nil
    }
}
