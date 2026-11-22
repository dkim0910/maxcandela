import Foundation

/// The tools, grouped by what they are for — the menu layout that fits every
/// Mac screen.
///
/// With 27 tool rows the flat menu grew to ~1,000 pt, taller than the space
/// under the menu bar on a 14″ MacBook Pro (≈950 pt at the default setting)
/// or a 13″ MacBook Air, so macOS made it scroll and pushed Quit and Purchases
/// below the fold — the reachability App Review rejected 1.0.4 for. Five
/// group rows instead of 27 tool rows bring it to ~550 pt.
///
/// The user picks the layout (`MenuLayout`); the flat list is the default
/// (Daniel's call, 2026-11-22), Grouped is the opt-in that fits small screens.
enum MenuGroup: CaseIterable {
    case time, clipboard, screen, windows, devices

    var title: String {
        switch self {
        case .time: return "Time"
        case .clipboard: return "Clipboard & Files"
        case .screen: return "Screen"
        case .windows: return "Windows & Desktop"
        case .devices: return "Devices & System"
        }
    }

    var symbol: String {
        switch self {
        case .time: return "clock"
        case .clipboard: return "doc.on.clipboard"
        case .screen: return "camera.viewfinder"
        case .windows: return "macwindow.on.rectangle"
        case .devices: return "slider.horizontal.3"
        }
    }

    /// The group a tool belongs to, by its type name. Nil for a tool nobody
    /// has placed yet — it then stays at the top level rather than vanishing
    /// from the menu. Pure, unit-tested.
    static func group(forToolNamed name: String) -> MenuGroup? {
        switch name {
        case "KeepAwakeTool", "TimerTool", "FocusTool", "BreaksTool",
             "MonthCalendarTool", "WorldClockTool", "CalendarTool":
            return .time
        case "ClipboardTool", "ScratchpadTool", "GeneratorTool", "FileShelfTool":
            return .clipboard
        case "ScreenshotTool", "ScreenTextTool", "ColorPickerTool":
            return .screen
        case "DesktopTool", "WindowDimmerTool", "MenuBarHiderTool", "WindowSnapTool":
            return .windows
        case "AudioTool", "AppVolumeTool", "BluetoothTool", "SystemTool", "ShortcutsTool":
            return .devices
        default:
            return nil
        }
    }
}

/// How the tools section is laid out — the user's choice, Options ▸ Menu
/// Layout. The flat list is the default: every tool one click away. It is
/// ~1,000 pt, so on a 14″ MacBook Pro or 13″ MacBook Air macOS scrolls it and
/// Quit sits below the fold; Grouped (~506 pt) fits every screen.
enum MenuLayout: String, CaseIterable {
    case grouped, flat

    var title: String {
        switch self {
        case .grouped: return "Grouped by Category"
        case .flat: return "All Tools in One List"
        }
    }

    var toolTip: String {
        switch self {
        case .grouped: return "Tools sit in five short groups, so the menu fits on any Mac screen."
        case .flat: return "Every tool in one long list, one click away. On a 14-inch or smaller screen the menu scrolls."
        }
    }

    /// The layout to use: a DEBUG override wins, then the stored choice, and
    /// anything unrecognised falls back to the flat list. Pure, unit-tested.
    static func resolve(stored: String?, override: String?) -> MenuLayout {
        if let override, let layout = MenuLayout(rawValue: override) { return layout }
        if let stored, let layout = MenuLayout(rawValue: stored) { return layout }
        return .flat
    }
}
