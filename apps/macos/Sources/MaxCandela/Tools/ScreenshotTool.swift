import AppKit
import Carbon.HIToolbox

/// Screenshot (Pro): capture a box you drag out, one window, or the whole
/// screen under the pointer, then mark it up — arrows, boxes, text,
/// highlighter, pixelate, redact, crop, with undo — and copy or save it.
/// See `ScreenshotEditor` for the markup window.
///
/// The capture goes through `ScreenCapture` (ScreenCaptureKit, the same path
/// as Copy Text from Screen) and so needs the same Screen Recording
/// permission, asked for on first use. Denied, every capture row explains
/// where the switch is instead of silently doing nothing. Captures live in
/// memory until their editor window closes; nothing is written to disk
/// unless the user picks a file in the save panel.
///
/// ⌃⌥⌘4 (opt-in, like every global shortcut here — and one step away from
/// the system's ⇧⌘4) starts a region capture from any app.
///
/// ⚠️ Not exercised at runtime during development: the dev binary has no
/// Screen Recording grant. The coordinate maths, the editor's model and the
/// renderer are unit-tested; the overlay, the capture calls and the editor
/// window are not.
final class ScreenshotTool: MenuTool {
    let menuItem = NSMenuItem(title: "Screenshot", action: nil, keyEquivalent: "")
    var onStatusChange: (() -> Void)?
    var isPro: Bool { true }

    private let regionItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let shortcutItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let overlay = CaptureOverlay()
    private var editors: [ScreenshotEditor] = []
    private let hotKey = GlobalHotKey()

    static let regionShortcut = Shortcut(keyCode: UInt32(kVK_ANSI_4),
                                         carbonModifiers: UInt32(controlKey | optionKey | cmdKey),
                                         display: "⌃⌥⌘4")
    private static let shortcutKey = "com.maxcandela.screenshot.shortcut"

    private var shortcutEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.shortcutKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.shortcutKey) }
    }

    init() {
        let submenu = NSMenu()
        regionItem.target = self
        regionItem.action = #selector(captureRegion)
        submenu.addItem(regionItem.symbol("rectangle.dashed"))
        let windowItem = NSMenuItem(title: "Capture Window…", action: #selector(captureWindow), keyEquivalent: "")
        windowItem.target = self
        submenu.addItem(windowItem.symbol("macwindow"))
        let screenItem = NSMenuItem(title: "Capture Screen", action: #selector(captureScreen), keyEquivalent: "")
        screenItem.target = self
        screenItem.toolTip = "The whole display the pointer is on"
        submenu.addItem(screenItem.symbol("display"))
        submenu.addItem(.separator())
        shortcutItem.title = "Use \(Self.regionShortcut.display) for Capture Region"
        shortcutItem.target = self
        shortcutItem.action = #selector(toggleShortcut)
        submenu.addItem(shortcutItem.symbol("keyboard"))
        menuItem.submenu = submenu
        menuItem.symbol("camera.viewfinder")

        hotKey.onPress = { [weak self] in
            ProGate.shared.run { self?.captureRegion() }
        }
        ProGate.shared.observe { [weak self] allowed in
            if allowed {
                self?.registerIfWanted()
            } else {
                // Stand down like the other Pro tools. Open editors stay:
                // they hold the user's work and nothing of the system's.
                self?.hotKey.unregister()
                self?.overlay.close()
            }
        }
        if ProGate.shared.isAllowed { registerIfWanted() }
        updateMenu()
    }

    func menuWillOpen() { updateMenu() }

    func shutdown() {
        hotKey.unregister()
        overlay.close()
        editors.forEach { $0.close() }
        editors.removeAll()
    }

    private func updateMenu() {
        let chord = hotKey.isRegistered ? "   \(Self.regionShortcut.display)" : ""
        regionItem.title = "Capture Region…\(chord)"
        shortcutItem.state = shortcutEnabled ? .on : .off
    }

    @objc private func toggleShortcut() {
        shortcutEnabled.toggle()
        if shortcutEnabled { registerIfWanted() } else { hotKey.unregister() }
        updateMenu()
    }

    private func registerIfWanted() {
        guard shortcutEnabled, !hotKey.isRegistered else { return }
        // Refused if another app owns the chord; the menu rows still work.
        hotKey.register(Self.regionShortcut)
    }

    // MARK: - Capturing

    @objc private func captureRegion() {
        guard !overlay.isActive, ScreenCapture.ensureAccess() else { return }
        overlay.selectRegion { [weak self] selection, screen in
            self?.capture { try await ScreenCapture.region(selection, on: screen) }
        }
    }

    @objc private func captureWindow() {
        guard !overlay.isActive, ScreenCapture.ensureAccess() else { return }
        let candidates = ScreenCapture.onScreenWindows()
        guard !candidates.isEmpty else {
            NSSound.beep()
            return
        }
        overlay.selectWindow(from: candidates) { [weak self] picked in
            self?.capture { try await ScreenCapture.window(picked.id) }
        }
    }

    @objc private func captureScreen() {
        guard ScreenCapture.ensureAccess(), let screen = ScreenCapture.screenUnderPointer() else { return }
        capture { try await ScreenCapture.display(screen) }
    }

    private func capture(_ take: @escaping () async throws -> ScreenImage) {
        Task {
            do {
                let shot = try await take()
                await MainActor.run { self.openEditor(for: shot) }
            } catch {
                NSLog("MaxCandela: screenshot failed: \(error.localizedDescription)")
                await MainActor.run { NSSound.beep() }
            }
        }
    }

    private func openEditor(for shot: ScreenImage) {
        let editor = ScreenshotEditor(shot: shot)
        editor.onClose = { [weak self] closed in
            self?.editors.removeAll { $0 === closed }
        }
        editors.append(editor)
        editor.show()
    }
}
