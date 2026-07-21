'use client';

import Link from 'next/link';
import NavBar from '@/components/NavBar';
import SiteFooter from '@/components/SiteFooter';
import ScrollLink from '@/components/ScrollLink';
import BeforeAfter from '@/components/BeforeAfter';
import { useBoost } from '@/components/BoostProvider';
import { APP_STORE_URL } from '@/lib/site';

const FEATURES = [
  {
    icon: '🖥️',
    title: 'Your whole Mac, brighter',
    text: 'The menu-bar app boosts everything — desktop, every app, every window. Not just one browser tab.',
  },
  {
    icon: '⚡',
    title: 'One click',
    text: 'A single ☀️ toggle in your menu bar. Click to unlock full brightness, click again to go back. Double-click for status, purchases and quit — that’s the whole UI.',
  },
  {
    icon: '🎨',
    title: 'True colors',
    text: 'Color-calibrated boost that preserves your display’s ColorSync profile. Brighter — never washed out.',
  },
  {
    icon: '🌡️',
    title: 'Looks after your Mac',
    text: 'Never exceeds the limits macOS enforces for HDR. As your Mac warms up it eases the boost off, and if it gets genuinely hot it briefly dims the screen below normal to help it cool — then restores everything.',
  },
  {
    icon: '🔆',
    title: 'Nothing to configure',
    text: 'Follows your display’s live headroom automatically — including thermal dips and recovery. Set it, forget it.',
  },
  {
    icon: '🔒',
    title: 'Private by default',
    text: 'No screen recording, no account, no personal data. The app never sees your screen content — it only lifts it. Anonymous usage stats only, as described in our privacy policy.',
  },
];

const FAQS = [
  {
    q: 'Is this safe for my display?',
    a: 'Yes. MaxCandela uses the same HDR headroom macOS itself uses for HDR video, and never exceeds the limit the OS reports. If your Mac gets hot, MaxCandela follows the OS down automatically.',
  },
  {
    q: 'What happens if my Mac gets hot?',
    a: 'MaxCandela looks after it. As your Mac warms up it eases the boost off, and if it gets genuinely hot it lowers brightness a little to help it cool — the same way phones do — then brings everything back once the temperature drops. It all happens automatically, and you can turn the boost off any time.',
  },
  {
    q: 'When I turn the boost off, does my screen stay dimmed?',
    a: 'No. Turning MaxCandela off puts your display back exactly where it was — at your normal brightness, with nothing dimmed. MaxCandela never lowers your baseline; it only adds brightness on top while it’s on, then hands everything back untouched. If the screen looks a little dim for a second right after, that’s just your eyes adjusting from the brighter level — the display itself is unchanged. (The only time it dips below normal is the automatic thermal protection above, which restores itself too.)',
  },
  {
    q: 'Which Macs are supported?',
    a: 'You need a Mac with an HDR-capable display: a MacBook Pro 14″ or 16″ (2021 or later) with the Liquid Retina XDR display, or a Pro Display XDR — those go up to ~1,000 nits sustained instead of the usual ~600. MacBook Air, iMac, and ordinary external monitors have no HDR headroom to unlock, so MaxCandela can’t brighten them. The app tells you straight away if your display isn’t supported, and the browser demo above is an honest test — if it doesn’t brighten your screen, the app won’t either.',
  },
  {
    q: 'Will it drain my battery?',
    a: 'Brightness costs power — the boost uses more battery, just like HDR video playback does. Toggle it off when you don’t need it; one click.',
  },
  {
    q: 'How does the free trial work?',
    a: 'Download free from the Mac App Store and get 5 days with everything unlocked. After that, keep it for $0.99/month or unlock it forever for $9.99. One purchase works on all Macs signed into your Apple ID.',
  },
  {
    q: 'Why doesn’t macOS just allow this?',
    a: 'macOS reserves the panel’s extra brightness for HDR content to protect battery and thermals by default. MaxCandela lets you choose when everyday content deserves the same headroom.',
  },
];

export default function Home() {
  // Site-wide boost state — the video overlay itself renders from the root
  // layout (BoostProvider), so it stays active on every page.
  const { enabled, supported, unlocker, toggle } = useBoost();

  const status =
    supported === null
      ? { cls: 'status-off', text: 'Checking your display…' }
      : !supported
        ? {
            cls: 'status-unsupported',
            text: 'No HDR headroom on this display — MaxCandela needs a MacBook Pro 14″/16″ (2021 or later) or a Pro Display XDR. MacBook Air and standard monitors aren’t supported.',
          }
        : enabled
          ? { cls: 'status-on', text: 'Boost active — this page is now brighter than macOS normally allows' }
          : { cls: 'status-off', text: 'Boost off — normal brightness' };

  return (
    // Wrapper (normal flow) so Next's scroll restoration targets this, not the
    // fixed <NavBar> — avoids the "Skipping auto-scroll" console warning.
    <div>
      <NavBar />

      <main className="main">
        {/* ---- Hero ---- */}
        <section className="hero">
          <p className="eyebrow">For MacBook Pro XDR displays</p>
          <h1>
            Your screen can go <span className="hl">70% brighter</span>.
            <br />
            macOS just won’t let it.
          </h1>
          <p className="subtitle">
            Your XDR panel is rated for 1,000 nits — macOS caps everyday
            content at ~600. MaxCandela unlocks the difference with one click
            in your menu bar. Full brightness, true colors, zero setup.
          </p>
          <div className="cta-row">
            <a className="app-store-link" href={APP_STORE_URL} aria-label="Download on the Mac App Store">
              <img
                className="app-store-badge"
                src="/download-on-mac-app-store.svg"
                alt="Download on the Mac App Store"
                width={156}
                height={40}
              />
            </a>
            <ScrollLink targetId="demo" className="cta cta-secondary">
              Try it in your browser ↓
            </ScrollLink>
            <span className="cta-note">Free · 5-day full trial</span>
          </div>
          {/* Hardware requirement sits with the CTA, not buried in the FAQ —
              the boost does nothing without HDR headroom, so nobody should
              reach the App Store link without knowing that. */}
          <div className="trust-row">
            <span>Needs an XDR display — MacBook Pro 14″/16″ (2021+)</span>
            <span>macOS 15.6+</span>
            <span>Colors preserved</span>
            <span>No account needed</span>
          </div>
        </section>

        {/* ---- Product showcase: before/after ---- */}
        <section className="showcase">
          <span className="section-eyebrow">See the difference</span>
          <h2>How dark it is now vs. how bright it gets</h2>
          <p className="demo-copy">
            Drag the slider — the left is your screen at its normal cap, the
            right is the same desktop with MaxCandela on.
          </p>
          <BeforeAfter
            before="/compare-normal.jpg"
            after="/compare-boosted.jpg"
            beforeLabel="Now"
            afterLabel="With MaxCandela"
            alt="A Mac desktop shown at normal brightness versus brightened with MaxCandela"
          />
          <p className="device-caption">
            Same Mac, same wallpaper — only the brightness changes. The app
            boosts every app and window, system-wide.
          </p>
        </section>

        {/* ---- Live demo ---- */}
        <section className="demo" id="demo">
          <span className="section-eyebrow">Try it free</span>
          <h2>Don’t take our word for it — feel it</h2>
          <p className="demo-copy">
            This page can boost itself the same way, right in your browser.
            Press the button and imagine your whole Mac like this.
          </p>
          {/* Wrapper forces the button onto its own line so the status pill
              sits BELOW it, not beside it (both are inline-flex). */}
          <div className="demo-toggle-row">
            <button
              className={`toggle toggle-big ${enabled ? 'toggle-on' : ''}`}
              onClick={toggle}
              disabled={supported !== true}
              aria-pressed={enabled}
            >
              <span className="toggle-dot" aria-hidden="true" />
              {enabled ? 'Boost on — press to restore' : 'Try the boost'}
            </button>
          </div>
          <div className="demo-status-row">
            <div className={`status ${status.cls}`} role="status">
              <span className="status-dot" aria-hidden="true" />
              {status.text}
            </div>
          </div>
          {enabled && unlocker?.error && (
            <p className="diag">⚠️ {unlocker.error}</p>
          )}
          <p className="demo-fineprint">
            The web demo brightens this page only. The Mac app brightens
            everything, system-wide.
          </p>
        </section>

        {/* ---- Features ---- */}
        <section className="features" id="features">
          <div className="section-head">
            <span className="section-eyebrow">Why MaxCandela</span>
            <h2>Built for one job, done right</h2>
          </div>
          <div className="cards">
            {FEATURES.map((f) => (
              <div className="card" key={f.title}>
                <span className="card-icon" aria-hidden="true">{f.icon}</span>
                <h3>{f.title}</h3>
                <p>{f.text}</p>
              </div>
            ))}
          </div>
        </section>

        {/* ---- Pricing ---- */}
        <section className="pricing" id="pricing">
          <div className="section-head">
            <span className="section-eyebrow">Pricing</span>
            <h2>Simple pricing</h2>
            <p className="section-sub">
              Free for 5 days, everything unlocked. Then pick what suits you.
              Requires a MacBook Pro 14″/16″ (2021 or later) or Pro Display XDR
              — check with the demo above before you buy.
            </p>
          </div>
          <div className="price-cards">
            <div className="price-card">
              <h3>Monthly</h3>
              <p className="price">
                $0.99<span className="price-per">/month</span>
              </p>
              <ul>
                <li>✓ Full brightness unlock</li>
                <li>✓ All future updates</li>
                <li>✓ Cancel anytime in the App Store</li>
              </ul>
              <a className="cta cta-secondary" href={APP_STORE_URL}>
                Start free trial
              </a>
            </div>
            <div className="price-card price-card-best">
              <span className="badge">Best value</span>
              <h3>Lifetime</h3>
              <p className="price">
                $9.99<span className="price-per"> once</span>
              </p>
              <ul>
                <li>✓ Full brightness unlock, forever</li>
                <li>✓ All future updates</li>
                <li>✓ Pays for itself in 11 months</li>
              </ul>
              <a className="cta cta-primary" href={APP_STORE_URL}>
                Start free trial
              </a>
            </div>
          </div>
          <p className="pricing-fineprint">
            Purchases via Apple. One purchase covers every Mac on your Apple
            ID. Requires macOS 15.6+ and an HDR/XDR display (MacBook Pro
            14″/16″ 2021 or later, or Pro Display XDR). Subscriptions
            renew monthly and can be cancelled anytime in App Store →
            Subscriptions; payment is charged to your Apple Account. See our{' '}
            <Link href="/terms/">Terms of Use</Link> and{' '}
            <Link href="/privacy/">Privacy Policy</Link>.
          </p>
        </section>

        {/* ---- FAQ ---- */}
        <section className="faq" id="faq">
          <div className="section-head">
            <span className="section-eyebrow">FAQ</span>
            <h2>Questions, answered</h2>
          </div>
          {FAQS.map((f) => (
            <details key={f.q}>
              <summary>{f.q}</summary>
              <p>{f.a}</p>
            </details>
          ))}
        </section>
      </main>

      <SiteFooter />
    </div>
  );
}
