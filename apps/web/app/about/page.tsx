import Link from 'next/link';
import type { Metadata } from 'next';
import { pageMetadata } from '@/lib/metadata';
import LegalShell from '@/components/LegalShell';

export const metadata: Metadata = pageMetadata({
  path: '/about/',
  title: 'About MaxCandela — a menu-bar toolbox for Mac',
  description:
    'MaxCandela started as a way to unlock a MacBook Pro’s full XDR brightness and grew into a menu-bar toolbox: 17 small Mac tools under one icon.',
});

export default function AboutPage() {
  return (
    <LegalShell
      path="/about/"
      title="About MaxCandela"
      crumb="About"
    >
      <p>
        <strong>MaxCandela is a toolbox that lives in your Mac’s menu
        bar</strong> — 17 small tools under one icon, eight of them free. It
        began with one simple frustration:{' '}
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
        washing out. It respects the system’s thermal and battery limits at all
        times and eases the boost back as your Mac heats up, collects no
        personal data, and never sees what’s on your screen.
        Free for 5 days, then $9.99 once or $0.99/month.
      </p>
      <p>
        It has since grown into a small toolbox under the same ☀️ icon. Two
        more display controls sit beside the boost — Extra Dim and Warmth —
        along with free everyday tools (Keep Awake, a timer, clipboard text
        tools, a color picker, generators, world clocks, a sound switcher and
        a system read-out) and a set of Pro tools: window snapping, a
        clipboard manager, hidden menu-bar icons, text capture from the
        screen, your Shortcuts and your next meeting. The brightness boost is
        still what only an XDR display can do; the rest works on any Mac.
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
        <li><strong>Minimal data.</strong> No accounts, no personal data, no
          screen access — the app never sees what you&rsquo;re looking at. The
          only thing collected is a handful of anonymous usage stats, exactly
          as our privacy policy spells out.</li>
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
