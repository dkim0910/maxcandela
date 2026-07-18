import type { Metadata } from 'next';
import LegalShell from '@/components/LegalShell';

export const metadata: Metadata = {
  title: 'Support — MaxCandela',
};

// TODO: replace with a dedicated support address before launch if preferred.
const SUPPORT_EMAIL = 'hello+maxcandela@nelera.net';

export default function SupportPage() {
  return (
    <LegalShell title="Support">
      <p>
        Something not working, or just have a question? We read everything.
      </p>

      <h2>Contact</h2>
      <p>
        Email us at{' '}
        <a href={`mailto:${SUPPORT_EMAIL}?subject=MaxCandela%20support`}>
          {SUPPORT_EMAIL}
        </a>
        . Include your macOS version and Mac model if you’re reporting a
        problem — it helps a lot.
      </p>

      <h2>Common questions</h2>

      <h3>The toggle doesn’t make my screen brighter</h3>
      <ul>
        <li>MaxCandela needs a display with EDR headroom — MacBook Pro
          14″/16″ (2021+), Pro Display XDR, or another HDR-capable display.
          On other panels there is no headroom to unlock.</li>
        <li>Check the right-click menu: it shows the live headroom your
          display is reporting right now.</li>
        <li>On battery-saver or when the Mac is hot, macOS temporarily lowers
          the available headroom; the boost follows automatically.</li>
      </ul>

      <h3>How do I cancel my subscription?</h3>
      <p>
        Subscriptions are managed by Apple: App Store app → your name →
        Subscriptions → MaxCandela → Cancel. Cancelling keeps the boost until
        the end of the paid period.
      </p>

      <h3>How do I get a refund?</h3>
      <p>
        Apple handles all refunds:{' '}
        <a href="https://reportaproblem.apple.com">
          reportaproblem.apple.com
        </a>
        .
      </p>

      <h3>I bought Lifetime on another Mac — how do I unlock this one?</h3>
      <p>
        Make sure you’re signed into the same Apple Account, then right-click
        the ☀️ icon → <em>Restore Purchases</em>.
      </p>

      <h3>Is it safe for my display?</h3>
      <p>
        Yes — MaxCandela only uses the brightness range macOS itself exposes
        for HDR content and never bypasses the system’s thermal protection.
        Quitting the app instantly returns everything to normal.
      </p>
    </LegalShell>
  );
}
