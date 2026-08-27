'use client';

import Link from 'next/link';
import NavBar from '@/components/NavBar';
import SiteFooter from '@/components/SiteFooter';
import ScrollLink from '@/components/ScrollLink';
import BeforeAfter from '@/components/BeforeAfter';
import { useBoost } from '@/components/BoostProvider';
import { APP_STORE_URL, SITE_NAME, SITE_ORIGIN, SITE_URL } from '@/lib/site';

// Responsive sources for the comparison slider. The originals are 3456×2234
// PNGs (~5 MB each, misnamed .jpg) — far more than the 1240px box can show, so
// they are re-encoded to WebP at 1× and 2× the container width by
// scripts/optimize-web-images.sh. 10.45 MB → 260 KB on a 2× display.
const COMPARE_WIDTH = 2480;
const COMPARE_HEIGHT = 1604;
const COMPARE_NORMAL = {
  src: '/compare-normal-2480.webp',
  srcSet: '/compare-normal-1240.webp 1240w, /compare-normal-2480.webp 2480w',
};
const COMPARE_BOOSTED = {
  src: '/compare-boosted-2480.webp',
  srcSet: '/compare-boosted-1240.webp 1240w, /compare-boosted-2480.webp 2480w',
};

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
    text: 'Never exceeds the limits macOS enforces for HDR. Because a bright screen makes heat, MaxCandela tracks how hard and how long it has been driving your display and eases the boost down as it warms — and cuts it entirely if it gets too hot, restoring it once things cool.',
  },
  {
    icon: '🔆',
    title: 'Nothing to configure',
    text: 'Follows your display’s live headroom automatically, and settles at a brightness your Mac can hold instead of running flat out. Set it, forget it.',
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
    a: 'Yes. MaxCandela uses the same HDR headroom macOS itself uses for HDR video, and never exceeds the limit the OS reports. On top of that it runs its own heat protection, because a sustained bright screen warms the panel in a way macOS doesn’t step in for on its own.',
  },
  {
    q: 'Does the screen get warm — and what does MaxCandela do about it?',
    a: 'It does: brightness is power, and power is heat, so a boosted display runs warmer than usual. MaxCandela keeps track of how hard and how long it has been driving your panel and steadily lowers the boost as that adds up, settling at a level your Mac can hold rather than running flat out indefinitely. If things go further — a genuinely hot machine — it cuts the boost completely and hands the display back to macOS, then brings it back once you’ve cooled down. The menu tells you which of those is happening, and you can switch the boost off yourself at any time.',
  },
  {
    q: 'When I turn the boost off, does my screen stay dimmed?',
    a: 'No. Turning MaxCandela off puts your display back exactly where it was — at your normal brightness, with nothing dimmed. MaxCandela never lowers your baseline; it only adds brightness on top while it’s on, then hands everything back untouched. If the screen looks a little dim for a second right after, that’s just your eyes adjusting from the brighter level — the display itself is unchanged. (The one exception is if macOS itself reports critical thermal pressure, when MaxCandela dims slightly below normal to help — and that restores itself too.)',
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
    a: 'Download free from the Mac App Store and get 5 days with everything unlocked. The clock starts when your Apple ID first downloads MaxCandela, so open it soon after installing to get the full five days. After that, keep it for $0.99/month or unlock it forever for $9.99. One purchase works on all Macs signed into your Apple ID.',
  },
  {
    q: 'I have a promo code — how do I use it?',
    a: 'Redeem it at apps.apple.com/redeem, or in the App Store app on your Mac → your name → “Redeem Gift Card or Code”, using the same Apple Account. That route works for every kind of code. The ☀️ menu also has “Purchases ▸ Redeem Code…”, but Apple’s in-app sheet only takes subscription offer codes — a one-off Lifetime code has to go through the App Store. A code unlocks MaxCandela straight away: it does not wait for your free trial to run out, and it replaces the trial rather than being added on to the end of it. If the menu still shows a trial afterwards, choose “Purchases ▸ Restore Purchases”.',
  },
  {
    q: 'Why doesn’t macOS just allow this?',
    a: 'macOS reserves the panel’s extra brightness for HDR content to protect battery and thermals by default. MaxCandela lets you choose when everyday content deserves the same headroom.',
  },
];

export default function Home() {
  // Site-wide boost state — the video overlay itself renders from the root
  // layout (BoostProvider), so it stays active on every page.
  const { enabled, supported, isMac, unlocker, toggle } = useBoost();

  // The demo is a macOS-only claim, so a phone gets its own state rather than
  // a working toggle: `(dynamic-range: high)` matches on iPhone 12+ and many
  // HDR Android phones, and brightening someone's phone would imply an app
  // that cannot help them. `note` is the long explanation — it sits under the
  // pill instead of inside it, so the pill stays a pill.
  const status =
    supported === null || isMac === null
      ? { cls: 'status-off', text: 'Checking your display…', note: null }
      : !isMac
        ? {
            cls: 'status-unsupported',
            text: 'Open this page on a MacBook Pro to try the demo',
            note: 'MaxCandela is a macOS app. The browser demo needs the same XDR display the app does, so it only runs on a Mac.',
          }
        : !supported
          ? {
              cls: 'status-unsupported',
              text: 'No HDR headroom on this display',
              note: 'MaxCandela needs a MacBook Pro 14″/16″ (2021 or later) or a Pro Display XDR. MacBook Air and standard monitors have no headroom to unlock.',
            }
          : enabled
            ? {
                cls: 'status-on',
                text: 'Boost active — this page is now brighter than macOS normally allows',
                note: null,
              }
            : { cls: 'status-off', text: 'Boost off — normal brightness', note: null };

  return (
    // Wrapper (normal flow) so Next's scroll restoration targets this, not the
    // fixed <NavBar> — avoids the "Skipping auto-scroll" console warning.
    <div>
      {/* Describes THIS page: the app itself and the FAQ actually rendered
          below. Site-wide Organization/WebSite identity lives in the layout.
          Inline JSON-LD renders straight into the prerendered HTML, so being
          inside a client component costs nothing. */}
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(homeSchema) }}
      />
      <NavBar />

      <main className="main">
        {/* ---- Hero ---- */}
        <section className="hero">
          <p className="eyebrow">For MacBook Pro XDR displays</p>
          {/* "MacBook Pro" belongs in the h1, not only in the eyebrow above it:
              the entity people search for has to carry heading weight. */}
          <h1>
            Your MacBook Pro screen can go{' '}
            <span className="hl">70% brighter</span>.
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
          <h2>How dark your MacBook Pro screen is now vs. how bright it gets</h2>
          <p className="demo-copy">
            Drag the slider — the left is your screen at its normal cap, the
            right is the same desktop with MaxCandela on.
          </p>
          <BeforeAfter
            before={COMPARE_NORMAL}
            after={COMPARE_BOOSTED}
            width={COMPARE_WIDTH}
            height={COMPARE_HEIGHT}
            beforeLabel="Now"
            afterLabel="With MaxCandela"
            alt="MacBook Pro XDR display at the macOS brightness cap next to the same desktop unlocked to full brightness by MaxCandela"
          />
          <p className="device-caption">
            Same Mac, same wallpaper — only the brightness changes. The app
            boosts every app and window, system-wide.
          </p>
        </section>

        {/* ---- Live demo ---- */}
        <section className="demo" id="demo">
          <span className="section-eyebrow">Try it free</span>
          <h2>Don’t take our word for it — try the brightness boost</h2>
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
              disabled={supported !== true || isMac !== true}
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
          {status.note && <p className="demo-fineprint">{status.note}</p>}
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
            <h2>Built for one job: making your whole Mac brighter</h2>
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
            <h2>Simple pricing — $9.99 once or $0.99/month</h2>
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
            <h2>MacBook Pro brightness questions, answered</h2>
          </div>
          {FAQS.map((f) => (
            <details key={f.q}>
              <summary>{f.q}</summary>
              <p>{f.a}</p>
            </details>
          ))}
          {/* The only in-body links to the deep pages. Footer-only links give a
              crawler almost nothing to weigh, and /support/ is the page most
              likely to answer a search that lands here. */}
          <p className="faq-more">
            Want the full explanation? Read{' '}
            <Link href="/how-it-works/">
              how to make your MacBook screen brighter than max
            </Link>{' '}
            — why macOS caps it, and why a bright wallpaper can’t fix it. Still
            stuck? Our <Link href="/support/">support guide</Link> covers
            display-by-display troubleshooting, subscriptions and promo codes.
          </p>
        </section>
      </main>

      <SiteFooter />
    </div>
  );
}

// Structured data for the home page. Deliberately no `aggregateRating`: the
// App Store listing has 0 ratings, and Google's review-snippet policy forbids
// aggregating another site's ratings anyway. That means no Software App rich
// result until real first-party reviews exist — the block is entity data for
// Google, Bing and AI answer engines, not a rich-result play.
const homeSchema = {
  '@context': 'https://schema.org',
  '@graph': [
    {
      '@type': 'SoftwareApplication',
      '@id': `${SITE_ORIGIN}#app`,
      name: SITE_NAME,
      applicationCategory: 'UtilitiesApplication',
      operatingSystem: 'macOS 15.6 or later',
      url: SITE_ORIGIN,
      image: `${SITE_URL}/og.png`,
      screenshot: `${SITE_URL}/compare-boosted-2480.webp`,
      // The machine-readable link between the site and the store listing —
      // the listing's sellerUrl already points back here.
      downloadUrl: APP_STORE_URL,
      installUrl: APP_STORE_URL,
      sameAs: [APP_STORE_URL],
      publisher: { '@id': `${SITE_ORIGIN}#organization` },
      description:
        'MaxCandela unlocks the full brightness of MacBook Pro XDR displays — pushing everyday content past the ~600 nit cap macOS enforces, with one click in the menu bar.',
      // `category: In-app purchase` matters: the App Store listing is Free, so
      // a bare $9.99 Offer contradicted the page it links to.
      offers: [
        {
          '@type': 'Offer',
          name: 'Lifetime',
          price: '9.99',
          priceCurrency: 'USD',
          category: 'In-app purchase',
          availability: 'https://schema.org/InStock',
          url: APP_STORE_URL,
        },
        {
          '@type': 'Offer',
          name: 'Monthly',
          price: '0.99',
          priceCurrency: 'USD',
          category: 'In-app purchase',
          availability: 'https://schema.org/InStock',
          url: APP_STORE_URL,
        },
      ],
    },
    {
      // Google retired FAQ rich results, so this earns no stars in Google.
      // Bing and the AI answer engines still consume FAQPage, and it costs
      // ~2 KB to describe questions the page genuinely answers.
      '@type': 'FAQPage',
      '@id': `${SITE_ORIGIN}#faq`,
      mainEntity: FAQS.map((f) => ({
        '@type': 'Question',
        name: f.q,
        acceptedAnswer: { '@type': 'Answer', text: f.a },
      })),
    },
  ],
};
