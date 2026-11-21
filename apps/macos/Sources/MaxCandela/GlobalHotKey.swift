import AppKit
import Carbon.HIToolbox

/// A key plus modifiers, in the form Carbon's hot-key API wants, with the
/// text the menu shows for it.
struct Shortcut: Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32
    var display: String

    static let standard = Shortcut(keyCode: UInt32(kVK_ANSI_B),
                                   carbonModifiers: UInt32(controlKey | optionKey | cmdKey),
                                   display: "⌃⌥⌘B")

    /// A global shortcut must carry ⌘, ⌃ or ⌥ — a bare letter (or Shift +
    /// letter) would swallow ordinary typing in every app.
    static func isUsable(_ flags: NSEvent.ModifierFlags) -> Bool {
        !flags.intersection([.command, .control, .option]).isEmpty
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result = 0
        if flags.contains(.control) { result |= controlKey }
        if flags.contains(.option) { result |= optionKey }
        if flags.contains(.shift) { result |= shiftKey }
        if flags.contains(.command) { result |= cmdKey }
        return UInt32(result)
    }

    /// Modifier glyphs in the order macOS menus print them.
    static func symbols(for flags: NSEvent.ModifierFlags) -> String {
        var text = ""
        if flags.contains(.control) { text += "⌃" }
        if flags.contains(.option) { text += "⌥" }
        if flags.contains(.shift) { text += "⇧" }
        if flags.contains(.command) { text += "⌘" }
        return text
    }

    /// Keys whose `characters` are unprintable or ambiguous.
    private static let namedKeys: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫",
        kVK_Escape: "⎋", kVK_LeftArrow: "←", kVK_RightArrow: "→",
        kVK_DownArrow: "↓", kVK_UpArrow: "↑",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5",
        kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10",
        kVK_F11: "F11", kVK_F12: "F12",
    ]

    static func keyName(keyCode: Int, characters: String?) -> String? {
        if let named = namedKeys[keyCode] { return named }
        guard let characters, !characters.isEmpty else { return nil }
        return characters.uppercased()
    }

    /// The shortcut a key-down describes, or nil if it can't be one.
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard Self.isUsable(flags),
              let name = Self.keyName(keyCode: Int(event.keyCode),
                                      characters: event.charactersIgnoringModifiers)
        else { return nil }
        self.init(keyCode: UInt32(event.keyCode),
                  carbonModifiers: Self.carbonModifiers(from: flags),
                  display: Self.symbols(for: flags) + name)
    }

    init(keyCode: UInt32, carbonModifiers: UInt32, display: String) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
        self.display = display
    }
}

/// One system-wide keyboard shortcut that toggles the boost from any app.
/// Carbon's `RegisterEventHotKey` is the public API for this and needs no
/// Accessibility or Input Monitoring permission (an NSEvent global monitor
/// would need the former, and could not swallow the key).
///
/// Opt-in: a global shortcut that is on by default can shadow the same chord
/// in whatever app the user happens to be in.
final class GlobalHotKey {
    /// Called on the main thread when the shortcut is pressed.
    var onPress: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?

    /// 'MXCD' — identifies our hot keys among the app's Carbon events.
    private static let signature: OSType = 0x4D58_4344

    /// Several shortcuts coexist (the boost, the clipboard panel, window
    /// snapping), and Carbon delivers *every* hot-key press to *every*
    /// handler on the application target. So there is one handler for the
    /// app, and it routes by the id each instance registers under.
    private static var handlerRef: EventHandlerRef?
    private static var registry: [UInt32: () -> GlobalHotKey?] = [:]
    private static var nextID: UInt32 = 1
    private let id: UInt32

    init() {
        id = Self.nextID
        Self.nextID += 1
        Self.registry[id] = { [weak self] in self }
    }

    private static func installHandlerIfNeeded() -> Bool {
        guard handlerRef == nil else { return true }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var pressed = EventHotKeyID()
            let read = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                         EventParamType(typeEventHotKeyID), nil,
                                         MemoryLayout<EventHotKeyID>.size, nil, &pressed)
            guard read == noErr, pressed.signature == GlobalHotKey.signature,
                  let hotKey = GlobalHotKey.registry[pressed.id]?() else {
                return OSStatus(eventNotHandledErr)
            }
            DispatchQueue.main.async { hotKey.onPress?() }
            return noErr
        }, 1, &spec, nil, &handlerRef)
        if status != noErr {
            NSLog("MaxCandela: could not install hot key handler (%d)", status)
        }
        return status == noErr
    }

    var isRegistered: Bool { hotKeyRef != nil }

    /// Returns false if the system refused — typically because another app
    /// already owns the chord. Replaces any shortcut registered before.
    @discardableResult
    func register(_ shortcut: Shortcut) -> Bool {
        unregister()

        guard Self.installHandlerIfNeeded() else { return false }

        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.carbonModifiers,
                                         hotKeyID, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else {
            NSLog("MaxCandela: could not register %@ (%d)", shortcut.display, status)
            return false
        }
        hotKeyRef = ref
        return true
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    deinit {
        unregister()
        Self.registry[id] = nil
    }
}
