'use client';

/**
 * Fixed top nav bar with the brightness toggle button. Presentation-only:
 * state and behavior live in the page.
 */
export default function NavBar({
  enabled,
  supported,
  onToggle,
}: {
  enabled: boolean;
  supported: boolean;
  onToggle: () => void;
}) {
  return (
    <nav className="navbar">
      <span className="brand">
        <span className="brand-icon" aria-hidden="true">☀️</span>
        MaxCandela
      </span>
      <button
        className={`toggle ${enabled ? 'toggle-on' : ''}`}
        onClick={onToggle}
        disabled={!supported}
        aria-pressed={enabled}
        title={
          supported
            ? enabled
              ? 'Restore normal brightness'
              : 'Unlock full brightness'
            : 'This display or browser has no EDR headroom'
        }
      >
        <span className="toggle-dot" aria-hidden="true" />
        {enabled ? 'Boost on' : 'Boost off'}
      </button>
    </nav>
  );
}
