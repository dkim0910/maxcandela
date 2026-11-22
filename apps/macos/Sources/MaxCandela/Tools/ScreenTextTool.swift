import AppKit
import Vision

/// Copy Text from Screen and Scan QR Code from Screen (both Pro): drag a box
/// over anything — a video frame, a PDF that won't select, an image, a
/// dialog, a code on a slide — and what it says lands on the clipboard.
/// Reading is Apple's on-device Vision framework; the captured image is
/// discarded as soon as it has been read and nothing leaves the Mac.
///
/// Two rows, one class (`Reading`), because the user's intent differs:
///  - **Copy Text** copies the text in the box. If the box holds no text but
///    does hold a QR code or barcode — a bare code reads as no text at all —
///    it copies the code's contents instead of beeping. Text wins when both
///    are present: the row promises text.
///  - **Scan QR Code** copies only what codes contain (several codes: one per
///    line, top to bottom), and beeps if there are none. Text is not even
///    read, so a code next to a caption gives the link, not the caption.
///
/// Needs the Screen Recording permission (System Settings ▸ Privacy &
/// Security ▸ Screen & System Audio Recording), requested on first use —
/// see `ScreenCapture.ensureAccess()`. Only the box the user draws is
/// captured. The Screenshot tool also looks at the screen; say so in
/// /privacy if either changes.
///
/// ⚠️ Not exercised at runtime during development (no Screen Recording grant
/// for the dev binary). The rectangle maths, text joining, code ordering and
/// the code reader itself (on a generated QR image) are unit-tested; the
/// capture and the overlay are not.
final class ScreenTextTool: MenuTool {
    enum Reading {
        case text, codes

        var title: String {
            switch self {
            case .text: return "Copy Text from Screen…"
            case .codes: return "Scan QR Code from Screen…"
            }
        }

        var symbol: String {
            switch self {
            case .text: return "text.viewfinder"
            case .codes: return "qrcode.viewfinder"
            }
        }
    }

    let menuItem: NSMenuItem
    var onStatusChange: (() -> Void)?
    var isPro: Bool { true }

    private let reading: Reading
    private let overlay = CaptureOverlay()

    init(reading: Reading = .text) {
        self.reading = reading
        menuItem = NSMenuItem(title: reading.title, action: nil, keyEquivalent: "")
        menuItem.target = self
        menuItem.action = #selector(begin)
        menuItem.symbol(reading.symbol)
    }

    func shutdown() { overlay.close() }

    /// Pure, unit-tested. Lines in reading order, blanks dropped.
    static func join(lines: [String]) -> String {
        lines.map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    /// Pure, unit-tested. Code contents in reading order — top to bottom,
    /// then left to right — each once. `box` is Vision's normalised bounding
    /// box (origin bottom-left, so a larger maxY is higher up). Codes Vision
    /// found but could not decode as text are skipped.
    static func orderedPayloads(_ codes: [(payload: String?, box: CGRect)]) -> [String] {
        // Rows: tops within about 2% of the height count as level. Bucketed
        // rather than compared with a tolerance, which would not be a
        // consistent ordering for sort().
        func row(_ box: CGRect) -> Int { Int((box.maxY * 50).rounded()) }
        let sorted = codes.sorted { a, b in
            row(a.box) != row(b.box) ? row(a.box) > row(b.box) : a.box.minX < b.box.minX
        }
        var seen = Set<String>()
        return sorted.compactMap { code in
            guard let payload = code.payload?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !payload.isEmpty, seen.insert(payload).inserted else { return nil }
            return payload
        }
    }

    /// Pure, unit-tested: what goes on the clipboard, or nil to beep. See the
    /// type comment for why each row prefers what it does.
    static func clipboardText(reading: Reading, text: String, codes: [String]) -> String? {
        let codeText = codes.isEmpty ? nil : codes.joined(separator: "\n")
        switch reading {
        case .text: return text.isEmpty ? codeText : text
        case .codes: return codeText
        }
    }

    @objc private func begin() {
        guard ScreenCapture.ensureAccess() else { return }
        overlay.selectRegion { [weak self] selection, screen in
            self?.capture(selection, on: screen)
        }
    }

    private func capture(_ selection: CGRect, on screen: NSScreen) {
        let reading = self.reading
        Task {
            do {
                let shot = try await ScreenCapture.region(selection, on: screen)
                let text = reading == .text ? try Self.recogniseText(in: shot.image) : ""
                // Copy Text only falls back to codes, so it only looks for
                // them when there was no text.
                let codes = text.isEmpty ? try Self.readCodes(in: shot.image) : []
                let result = Self.clipboardText(reading: reading, text: text, codes: codes)
                await MainActor.run {
                    guard let result else {
                        NSSound.beep()
                        return
                    }
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(result, forType: .string)
                    NSSound(named: "Pop")?.play()
                }
            } catch {
                NSLog("MaxCandela: screen reading failed: \(error.localizedDescription)")
                await MainActor.run { NSSound.beep() }
            }
        }
    }

    static func recogniseText(in image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        return join(lines: lines)
    }

    /// Every QR code and barcode Vision can find and decode, in reading order.
    static func readCodes(in image: CGImage) throws -> [String] {
        let request = VNDetectBarcodesRequest()
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        return orderedPayloads((request.results ?? []).map { ($0.payloadStringValue, $0.boundingBox) })
    }
}
