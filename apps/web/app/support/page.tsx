import type { Metadata } from 'next';
import { pageMetadata } from '@/lib/metadata';
import LegalShell from '@/components/LegalShell';

export const metadata: Metadata = pageMetadata({
  path: '/support/',
  title: 'MaxCandela Support — XDR brightness help for MacBook Pro',
  description:
    'Help with MaxCandela: which Macs are supported, why the boost may look different, managing your subscription, restoring purchases, and how to get in touch.',
});

const SUPPORT_EMAIL = 'hello+maxcandela@nelera.net';
// The "+" must be percent-encoded in a mailto: URL — several mail clients
// decode a bare "+" as a space and mangle the address.
const SUPPORT_MAILTO = `mailto:${SUPPORT_EMAIL.replace('+', '%2B')}?subject=MaxCandela%20support`;

export default function SupportPage() {
  return (
    <LegalShell
      path="/support/"
      title="Support — MacBook Pro brightness help"
      crumb="Support"
    >
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
        <li>With <em>Options ▸ Pause Boost on Battery</em> switched on, the
          boost waits until the Mac is plugged in; the menu says{' '}
          <em>“Paused on battery”</em> while it does.</li>
      </ul>

      <h3>I have an M5 Pro or M5 Max MacBook Pro and nothing changes</h3>
      <p>
        There is a macOS bug, reported by several developers on Apple’s
        developer forums and still open with Apple, that can make these two
        chips ignore the display adjustment every brightness app of this kind
        relies on. The boost shows as switched on, but the screen stays the
        same. We have not been able to test an affected Mac ourselves, and it
        does not affect every model — the standard M5 and earlier chips are
        reported to work. If this is what you are seeing, a macOS update from
        Apple is what will fix it; please don’t buy MaxCandela Pro until the
        boost visibly works on your Mac, and{' '}
        <a href={SUPPORT_MAILTO}>tell us</a> your macOS version so we can track
        it.
      </p>

      <h3>What are Extra Dim, Warmth and Options?</h3>
      <p>
        <em>Extra Dim</em> takes the screen below the lowest setting of the
        brightness keys, for a dark room; it applies whenever the boost is not
        driving that display. <em>Warmth</em> shifts the picture toward warmer
        white and works with or without the boost. Both return to normal the
        moment you quit MaxCandela. <em>Warmth Schedule ▸ Only at Night</em>{' '}
        keeps the warmth for the evening and eases it in and out over half an
        hour.
      </p>
      <p>
        Under <em>Options</em> you can pause the boost on battery, switch on a
        keyboard shortcut that toggles the boost from any app (⌃⌥⌘B unless you
        pick another with <em>Change Shortcut…</em>), have MaxCandela launch at
        login, and limit the boost to particular apps with{' '}
        <em>Boost Only In</em> — it then runs only while one of those apps is
        in front. All of these are off until you turn them on.
      </p>

      <h3>Can I boost one display and not another?</h3>
      <p>
        Yes. With more than one HDR-capable display connected, the ☀️ menu
        lists each one under the toggle; click a display to take it out of the
        boost or put it back.
      </p>

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
