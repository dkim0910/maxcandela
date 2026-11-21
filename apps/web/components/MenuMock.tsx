/**
 * The product shot: a MacBook's menu bar and MaxCandela's menu, drawn in HTML
 * and CSS. The home page hero *is* the MacBook screen — `MockMenuBar` runs
 * across its top and `MockMenu` drops open from the ☀ status item, with the
 * headline sitting on the desktop beside it (see `.hero` in globals.css).
 *
 * A real screenshot would be better and should replace this once one exists.
 * Until then this is the honest alternative to stock imagery — it shows the
 * actual sections and rows of the app's menu, in the app's own order. Keep it
 * in step with `MenuBarController.buildMenu()` and `MenuBarController.tools`
 * in apps/macos: a row here that the app does not have is a false claim.
 *
 * Purely presentational, so it is one image to assistive tech (`role="img"`)
 * rather than forty unlabelled spans.
 */

const FREE = ['Keep Awake', 'Timer', 'Clipboard', 'Color Picker', 'Generate', 'World Clock', 'Sound', 'System'];
const PRO = ['Hide Menu Bar Icons', 'Window Snapping', 'Copy Text from Screen…', 'Shortcuts', 'Next Meeting'];

function Slider({ label, value, fill }: { label: string; value: string; fill: number }) {
  return (
    <div className="mock-slider">
      <div className="mock-slider-head">
        <span>{label}</span>
        <span className="mock-hint">{value}</span>
      </div>
      <div className="mock-track">
        <div className="mock-fill" style={{ width: `${fill}%` }} />
        <div className="mock-knob" style={{ left: `${fill}%` }} />
      </div>
    </div>
  );
}

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

/** The app's menu, open. One image to assistive tech. */
export function MockMenu() {
  return (
    <div
      className="mock-menu"
      role="img"
      aria-label="The MaxCandela menu, open from its menu-bar icon: a Display section with the brightness boost, Extra Dim and Warmth; a Tools section with eight free tools; and a Pro Tools section with five more."
    >
      <div className="mock-head">Display</div>
      <div className="mock-row mock-row-on">
        <span>Turn Boost Off</span>
        <span className="mock-hint">0.42× left</span>
      </div>
      <Slider label="Extra Dim" value="Off" fill={0} />
      <Slider label="Warmth" value="40%" fill={40} />
      <div className="mock-sep" />
      <div className="mock-head">Tools</div>
      {FREE.map((name) => (
        <div className="mock-row" key={name}>
          <span>{name}</span>
          <span className="mock-chev">›</span>
        </div>
      ))}
      <div className="mock-sep" />
      <div className="mock-head">Pro Tools</div>
      {PRO.map((name) => (
        <div className="mock-row" key={name}>
          <span>{name}</span>
          {!name.endsWith('…') && <span className="mock-chev">›</span>}
        </div>
      ))}
    </div>
  );
}
