import CryptoKit
import Foundation

/// The clipboard text tools. All pure — each takes the clipboard's text and
/// returns what should replace it, or nil when the input isn't valid for that
/// tool (not Base64, not JSON), in which case the clipboard is left alone.
enum TextTransform: CaseIterable {
    case uppercase, lowercase, titleCase, trim, sortLines, removeDuplicateLines
    case urlEncode, urlDecode, base64Encode, base64Decode, prettyJSON, minifyJSON
    case sha256, md5, decodeJWT

    var title: String {
        switch self {
        case .uppercase: return "UPPERCASE"
        case .lowercase: return "lowercase"
        case .titleCase: return "Title Case"
        case .trim: return "Trim Whitespace"
        case .sortLines: return "Sort Lines"
        case .removeDuplicateLines: return "Remove Duplicate Lines"
        case .urlEncode: return "URL-Encode"
        case .urlDecode: return "URL-Decode"
        case .base64Encode: return "Base64-Encode"
        case .base64Decode: return "Base64-Decode"
        case .prettyJSON: return "Format JSON"
        case .minifyJSON: return "Minify JSON"
        case .sha256: return "SHA-256 Hash"
        case .md5: return "MD5 Hash"
        case .decodeJWT: return "Decode JWT"
        }
    }

    /// Where the menu draws a separator *before* this case.
    var startsGroup: Bool {
        self == .trim || self == .urlEncode || self == .prettyJSON || self == .sha256
    }

    func apply(to text: String) -> String? {
        switch self {
        case .uppercase: return text.uppercased()
        case .lowercase: return text.lowercased()
        case .titleCase: return text.capitalized
        case .trim:
            return text.split(separator: "\n", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        case .sortLines:
            return text.components(separatedBy: "\n")
                .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
                .joined(separator: "\n")
        case .removeDuplicateLines:
            var seen = Set<String>()
            return text.components(separatedBy: "\n")
                .filter { seen.insert($0).inserted }
                .joined(separator: "\n")
        case .urlEncode:
            // Everything but RFC 3986 unreserved characters — the form that is
            // safe to drop into a query value.
            var allowed = CharacterSet.alphanumerics
            allowed.insert(charactersIn: "-._~")
            return text.addingPercentEncoding(withAllowedCharacters: allowed)
        case .urlDecode:
            return text.removingPercentEncoding
        case .base64Encode:
            return Data(text.utf8).base64EncodedString()
        case .base64Decode:
            let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let data = Data(base64Encoded: cleaned, options: .ignoreUnknownCharacters),
                  !data.isEmpty || cleaned.isEmpty else { return nil }
            return String(data: data, encoding: .utf8)
        case .prettyJSON:
            return Self.reserialise(text, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        case .minifyJSON:
            return Self.reserialise(text, options: [.sortedKeys, .withoutEscapingSlashes])
        case .sha256:
            return SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
        case .md5:
            // Checksums only — MD5 is not safe for anything security-related,
            // which is why CryptoKit files it under `Insecure`.
            return Insecure.MD5.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
        case .decodeJWT:
            // Header and payload, pretty-printed. The signature is NOT
            // verified — this is for reading a token, not trusting it.
            let parts = text.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ".")
            guard parts.count == 3 else { return nil }
            let decoded = parts.prefix(2).compactMap { part -> String? in
                var base64 = part.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
                base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
                guard let data = Data(base64Encoded: base64), let json = String(data: data, encoding: .utf8) else { return nil }
                return Self.reserialise(json, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
            }
            return decoded.count == 2 ? decoded.joined(separator: "\n\n") : nil
        }
    }

    private static func reserialise(_ text: String, options: JSONSerialization.WritingOptions) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: Data(text.utf8), options: [.fragmentsAllowed]),
              let data = try? JSONSerialization.data(withJSONObject: object,
                                                     options: options.union(.fragmentsAllowed))
        else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

/// The clipboard history list: pinned entries first, then newest first; no
/// duplicates; capped. Pure, unit-tested.
struct ClipboardHistory: Codable, Equatable {
    /// What the free tier keeps, and what Pro keeps.
    static let freeCapacity = 15
    static let proCapacity = 200

    private(set) var entries: [String] = []
    private(set) var pinned: Set<String> = []

    /// `capacity` bounds the *unpinned* entries; pins are never evicted — the
    /// point of pinning something is that it stays.
    mutating func add(_ text: String, capacity: Int = freeCapacity) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        entries.removeAll { $0 == text }
        entries.insert(text, at: 0)
        trim(to: capacity)
    }

    mutating func trim(to capacity: Int) {
        var kept = 0
        entries = entries.filter { entry in
            if pinned.contains(entry) { return true }
            kept += 1
            return kept <= capacity
        }
    }

    mutating func togglePin(_ text: String) {
        guard entries.contains(text) else { return }
        if pinned.contains(text) { pinned.remove(text) } else { pinned.insert(text) }
    }

    mutating func remove(_ text: String) {
        entries.removeAll { $0 == text }
        pinned.remove(text)
    }

    mutating func clear() {
        entries.removeAll()
        pinned.removeAll()
    }

    func isPinned(_ text: String) -> Bool { pinned.contains(text) }

    /// Pinned first, each group newest first; filtered by a case- and
    /// accent-insensitive search when `query` is not blank.
    func ordered(matching query: String = "") -> [String] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = needle.isEmpty ? entries : entries.filter {
            $0.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
        return matches.filter(pinned.contains) + matches.filter { !pinned.contains($0) }
    }

    /// One line, at most `limit` characters, for a menu row.
    static func menuTitle(for text: String, limit: Int = 48) -> String {
        let line = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
        return line.count > limit ? String(line.prefix(limit - 1)) + "…" : line
    }
}
