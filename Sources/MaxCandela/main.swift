import AppKit

// Entry point. MaxCandela is a menu-bar-only app (no Dock icon), so we set the
// activation policy to `.accessory` and hand off to AppDelegate for everything
// else. See CLAUDE.md for the architecture overview.

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
