import Link from 'next/link';
import type { Metadata } from 'next';
import LegalShell from '@/components/LegalShell';

export const metadata: Metadata = {
  title: 'About — MaxCandela',
  description:
    'Why MaxCandela exists: your MacBook Pro’s XDR display is rated for ~1,000 nits but macOS caps everyday content near 600. We hand that reserve back to you.',
};

export default function AboutPage() {
  return (
    <LegalShell title="About MaxCandela">
      <p>
        <strong>MaxCandela exists to answer one simple frustration:</strong>{' '}
        your MacBook Pro’s screen is capable of far more brightness than
        macOS lets you use. The panel in a 14″ or 16″ MacBook Pro is rated
        for 1,000 nits of sustained brightness — but everyday content is
        capped at roughly 600. The rest is reserved for HDR video, and most
        of the time it just sits there, unused.
      </p>
      <p>
        We built MaxCandela to hand that reserve back to you. One click in
        the menu bar, and your whole screen — every app, every window —
        steps up into the brightness your hardware always had.
      </p>

      <h2>The name</h2>
      <p>
        A <em>candela</em> is the scientific unit of luminous intensity.
        MaxCandela does exactly what it says: takes your display to its
        maximum candelas.
      </p>

      <h2>The Mac app</h2>
      <p>
        A tiny menu-bar utility for macOS 15.6+. It engages the display’s
        Extended Dynamic Range (EDR) headroom — the same mechanism macOS uses
        for HDR movies — and lifts all your content into it with a
        color-calibrated transform, so everything gets brighter without
        washing out. It respects the system’s thermal and battery limits at
        all times, collects no personal data, and never sees what’s on your
        screen.
        Free for 5 days, then $9.99 once or $0.99/month.
      </p>

      <h2>This website</h2>
      <p>
        The site doubles as a live demo: the “Try the boost” button on the
        home page performs the same brightness trick inside your browser
        using an HDR video layer — no install required. It brightens the
        pages of this site only; the Mac app is what brightens everything
        else. If the button is disabled, your current display or browser has
        no HDR headroom to unlock.
      </p>

      <h2>Our principles</h2>
      <ul>
        <li><strong>Honest engineering.</strong> We never push the panel past
          what macOS itself allows — no hacks that fight the operating
          system’s safety limits.</li>
        <li><strong>Zero data.</strong> No analytics, no accounts, no screen
          access. There is nothing to leak because nothing is collected.</li>
        <li><strong>Instant reversibility.</strong> Toggling off — or simply
          quitting the app — returns your display to exactly its previous
          state, always.</li>
      </ul>

      <h2>Get in touch</h2>
      <p>
        Questions, problems, ideas? Head to the{' '}
        <Link href="/support/">Support page</Link> — we read everything.
      </p>
    </LegalShell>
  );
}
