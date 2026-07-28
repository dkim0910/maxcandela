import type { Metadata } from 'next';
import LegalShell from '@/components/LegalShell';

export const metadata: Metadata = {
  title: 'Support — MaxCandela',
  description:
    'Help with MaxCandela: which Macs are supported, why the boost may look different, managing your subscription, restoring purchases, and how to get in touch.',
};

const SUPPORT_EMAIL = 'hello+maxcandela@nelera.net';
// The "+" must be percent-encoded in a mailto: URL — several mail clients
// decode a bare "+" as a space and mangle the address.
const SUPPORT_MAILTO = `mailto:${SUPPORT_EMAIL.replace('+', '%2B')}?subject=MaxCandela%20support`;

export default function SupportPage() {
  return (
    <LegalShell title="Support">
      <p>
        Something not working, or just have a question? We read everything.
      </p>

      <h2>Contact</h2>
      <p>
        Email us at{' '}
        <a href={SUPPORT_MAILTO}>
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
        <li>Check the right-click menu: next to the toggle it shows how much
          headroom is left on each display — <em>0.00× left</em> means that
          screen is already as bright as the panel currently allows.</li>
        <li>On battery-saver, macOS temporarily lowers the available headroom;
          the boost follows it down automatically.</li>
        <li>If it was brighter earlier in the session, MaxCandela has probably
          eased it back for heat — see below.</li>
      </ul>

      <h3>The boost got dimmer on its own, or switched off</h3>
      <p>
        That is the heat protection doing its job, not a fault. A boosted
        display makes real heat, so MaxCandela tracks how hard and how long it
        has been driving your panel and gradually lowers the boost as that adds
        up, settling at a brightness your Mac can sustain. If the Mac gets
        genuinely hot it stops boosting altogether and hands the display back to
        macOS, then restores it once things cool down. The ☀️ menu says which is
        happening — <em>“eased for heat”</em> or{' '}
        <em>“Paused — Mac too hot”</em>. You can switch the boost off yourself at
        any time; that is never blocked.
      </p>

      <h3>I have a promo code — where do I enter it?</h3>
      <p>
        Redeem it at{' '}
        <a href="https://apps.apple.com/redeem">apps.apple.com/redeem</a>, or in
        the App Store app on your Mac → your name → <em>Redeem Gift Card or
        Code</em>, using the same Apple Account you use for the App Store. That
        route works for every kind of code, so start there.
      </p>
      <p>
        The ☀️ menu also has <em>Purchases ▸ Redeem Code…</em>, but Apple’s
        in-app sheet only accepts <strong>subscription offer codes</strong> — a
        one-off code for the Lifetime unlock has to go through the App Store
        instead, and the sheet will report it as invalid.
      </p>
      <p>
        A code takes effect <strong>immediately</strong> — it does not wait for
        the 5-day free trial to finish, and it replaces the trial rather than
        extending it. If the menu still shows a trial after redeeming, choose{' '}
        <em>Purchases ▸ Restore Purchases</em>.
      </p>

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
        the ☀️ icon → <em>Purchases ▸ Restore Purchases</em>.
      </p>

      <h3>Is it safe for my display?</h3>
      <p>
        Yes — MaxCandela only uses the brightness range macOS itself exposes
        for HDR content, and never asks for more than the limit the system
        reports. On top of that it runs its own heat protection, easing the
        boost down and eventually stopping it, because a sustained bright panel
        warms up in a way macOS does not step in for by itself. Quitting the app
        instantly returns everything to normal.
      </p>
    </LegalShell>
  );
}
