/**
 * The product shot. The home page hero *is* a MacBook screen: `MockMenuBar`
 * (drawn in HTML/CSS) runs across its top, and `MenuShot` — the app's real
 * menu — drops open from the ☀ status item, with the headline sitting on the
 * desktop beside it (see `.hero` in globals.css).
 *
 * The menu used to be drawn in HTML too, and it drifted from the app: no
 * icons, no Warmth Schedule, nothing below Pro Tools, sliders the app does not
 * draw. Replaced 2026-11-22 with a real capture so it cannot drift silently
 * again — it can only go stale, and then it is regenerated rather than
 * re-drawn:
 *
 *   scripts/make-app-screenshots.sh      (captures the real menus)
 *   scripts/optimize-web-images.sh       (crops main.png → menu-main-*.webp)
 *
 * Run both after any change to `MenuBarController.buildMenu()`.
 */

/** The system menu bar across the top of the screen. Decorative. */
export function MockMenuBar() {
  return (
    <div className="mock-bar" aria-hidden="true">
      <div className="mock-bar-group mock-bar-apps">
        <span>Finder</span>
        <span>File</span>
        <span>Edit</span>
        <span>View</span>
        <span>Go</span>
        <span>Window</span>
        <span>Help</span>
      </div>
      <div className="mock-bar-group">
        <span className="mock-bar-stat">CPU 12%</span>
        <span className="mock-bar-stat">RAM 61%</span>
        <span className="mock-status-on">
          <svg className="mock-sun" viewBox="0 0 16 16">
            <circle cx="8" cy="8" r="3.1" />
            <path d="M8 .8v2M8 13.2v2M.8 8h2M13.2 8h2M2.9 2.9l1.4 1.4M11.7 11.7l1.4 1.4M2.9 13.1l1.4-1.4M11.7 4.3l1.4-1.4" />
          </svg>
        </span>
        <span>9:41</span>
      </div>
    </div>
  );
}

/**
 * The app's main menu, open — a real capture (licensed, boost off, the
 * sandboxed build's tool list, "All Tools in One List" layout), shown at its
 * true size in points. width/height are the 1× file's pixels; update them —
 * and `.menu-shot`'s negative bottom margin in globals.css — if a re-capture
 * changes the menu's size.
 */
export function MenuShot() {
  return (
    <img
      className="menu-shot"
      src="/menu-main-1x.webp"
      srcSet="/menu-main-1x.webp 1x, /menu-main-2x.webp 2x"
      width={278}
      height={973}
      decoding="async"
      alt="The MaxCandela menu, open: a Display section with Turn Boost On, Extra Dim, Warmth and Warmth Schedule; Tools with Keep Awake, Timer, Focus, Breaks, Clipboard, Scratchpad, Color Picker, Generate, World Clock, Calendar, Sound, System and Desktop; Pro Tools with Hide Menu Bar Icons, Screenshot, Copy Text from Screen, Scan QR Code from Screen, Shortcuts, Next Meeting, Bluetooth, File Shelf, Dim Background Windows and App Volume; then MaxCandela Pro, Purchases, Options, Legal and Quit MaxCandela."
    />
  );
}
