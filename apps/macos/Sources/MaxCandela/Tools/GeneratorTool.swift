import AppKit
import Security

/// Generate: small values people otherwise open a website for — a UUID, a
/// strong password, the current timestamp, filler text, a QR code. Each goes
/// straight to the clipboard. Nothing is stored and nothing touches the
/// network.
enum Generator: CaseIterable {
    case uuid, password, unixTime, isoDate, loremIpsum

    var title: String {
        switch self {
        case .uuid: return "UUID"
        case .password: return "Strong Password"
        case .unixTime: return "Unix Timestamp"
        case .isoDate: return "ISO 8601 Date"
        case .loremIpsum: return "Lorem Ipsum Paragraph"
        }
    }

    var symbol: String {
        switch self {
        case .uuid: return "number"
        case .password: return "key"
        case .unixTime: return "clock.arrow.circlepath"
        case .isoDate: return "calendar"
        case .loremIpsum: return "text.alignleft"
        }
    }

    func make(now: Date = Date()) -> String {
        switch self {
        case .uuid: return UUID().uuidString
        case .password: return Self.password()
        case .unixTime: return String(Int(now.timeIntervalSince1970))
        case .isoDate: return ISO8601DateFormatter().string(from: now)
        case .loremIpsum: return Self.lorem
        }
    }

    /// Letters and digits minus the look-alikes (0/O, 1/l/I), plus a few
    /// symbols every site accepts.
    static let passwordAlphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789-_!@#%")

    /// From the system's cryptographic generator (`SecRandomCopyBytes`), with
    /// rejection sampling so no character is likelier than another — a plain
    /// `byte % count` would favour the start of the alphabet.
    static func password(length: Int = 20) -> String {
        let alphabet = passwordAlphabet
        let limit = 256 - (256 % alphabet.count)
        var result: [Character] = []
        while result.count < length {
            var bytes = [UInt8](repeating: 0, count: length * 2)
            guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
                // No secure randomness: refuse rather than hand out a weak one.
                return ""
            }
            for byte in bytes where Int(byte) < limit && result.count < length {
                result.append(alphabet[Int(byte) % alphabet.count])
            }
        }
        return String(result)
    }

    static let lorem = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
}

final class GeneratorTool: MenuTool {
    let menuItem = NSMenuItem(title: "Generate", action: nil, keyEquivalent: "")
    var onStatusChange: (() -> Void)?

    init() {
        let submenu = NSMenu()
        let header = NSMenuItem(title: "Copy to Clipboard", action: nil, keyEquivalent: "")
        header.isEnabled = false
        submenu.addItem(header)
        for (index, generator) in Generator.allCases.enumerated() {
            let item = NSMenuItem(title: generator.title, action: #selector(generate(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            submenu.addItem(item.symbol(generator.symbol))
        }
        submenu.addItem(.separator())
        let qrItem = NSMenuItem(title: "QR Code from Clipboard", action: #selector(makeQRCode), keyEquivalent: "")
        qrItem.target = self
        qrItem.toolTip = "Turns the text on the clipboard — a link, a note, anything — into a QR code picture to paste."
        submenu.addItem(qrItem.symbol("qrcode"))
        menuItem.submenu = submenu
        menuItem.symbol("wand.and.stars")
    }

    @objc private func generate(_ sender: NSMenuItem) {
        let value = Generator.allCases[sender.tag].make()
        guard !value.isEmpty else {
            NSSound.beep()
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    /// Replaces the clipboard's text with a picture of it as a QR code. Beeps
    /// and leaves the clipboard alone when there is no text, or too much for
    /// a QR code to hold (see `QRCode.image(for:)`).
    @objc private func makeQRCode() {
        guard let text = NSPasteboard.general.string(forType: .string),
              let image = QRCode.image(for: text),
              ImageExport.copy(image, pixelsPerPoint: 1) else {
            NSSound.beep()
            return
        }
    }
}
