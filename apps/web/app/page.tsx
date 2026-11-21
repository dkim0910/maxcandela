'use client';

import Link from 'next/link';
import NavBar from '@/components/NavBar';
import SiteFooter from '@/components/SiteFooter';
import ScrollLink from '@/components/ScrollLink';
import BeforeAfter from '@/components/BeforeAfter';
import { MockMenu, MockMenuBar } from '@/components/MenuMock';
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

// The free tools. Each line states what the app does today — check it
// against apps/macos/Sources/MaxCandela/Tools before adding or rewording a
// card. The counts in the copy are derived from these arrays: "eight" is
// TOOLS.length, "17" is TOOLS + PRO_TOOLS + the three display tools.
const TOOLS = [
  {
    title: 'Keep Awake',
    text: 'Stop your Mac’s display sleeping for half an hour, a few hours, or until you say so. Presentations, long downloads, reading.',
  },
  {
    title: 'Timer',
    text: 'A countdown that sits next to the menu-bar icon while it runs and chimes when it’s done.',
  },
  {
    title: 'Clipboard tools',
    text: 'Change the case of copied text, trim it, sort lines, URL- and Base64-encode or decode, format JSON. Optional history of the last 15 things you copied — kept in memory only.',
  },
  {
    title: 'Color picker',
    text: 'Pick any colour on screen with the system eyedropper and get its hex code on your clipboard.',
  },
  {
    title: 'Generate',
    text: 'A UUID, a strong password, a Unix timestamp, an ISO date or a paragraph of filler text — one click, straight to your clipboard.',
  },
  {
    title: 'World clock',
    text: 'The time in the cities you work with, and whether it’s already tomorrow there.',
  },
  {
    title: 'Sound',
    text: 'Switch between speakers, headphones and microphones, and mute the mic, without opening System Settings.',
  },
  {
    title: 'System at a glance',
    text: 'CPU, memory, free disk space, battery health and cycle count, uptime and your local IP address — live, and click any line to copy it.',
  },
];

// The Pro tools — each one stands in for an app people buy on its own.
// `kind` is that category; `needs` is the macOS permission the tool asks for
// on first use (see the tool's type comment in apps/macos), or null.
const PRO_TOOLS: { kind: string; needs: string | null; title: string; text: string }[] = [
  {
    kind: 'Menu bar organiser',
    needs: null,
    title: 'Hide menu bar icons',
    text: 'Tuck the icons you rarely need behind a chevron and bring them back with a click. Hold ⌘ and drag to choose which.',
  },
  {
    kind: 'Clipboard manager',
    needs: null,
    title: 'Clipboard manager',
    text: 'The last 200 things you copied in a searchable window on ⌃⌥⌘V. Pin what you reuse, and keep it between restarts if you choose to.',
  },
  {
    kind: 'Window manager',
    needs: 'Accessibility',
    title: 'Window snapping',
    text: 'Send the front window to a half, a quarter, the full screen or the centre — from the menu or with ⌃⌥ and the arrow keys.',
  },
  {
    kind: 'Screen text reader',
    needs: 'Screen Recording',
    title: 'Copy text from screen',
    text: 'Drag a box over a video, an image or a PDF that won’t select, and the text in it is on your clipboard. Recognised on your Mac, never uploaded.',
  },
  {
    kind: 'Automation',
    needs: null,
    title: 'Your Shortcuts, one click away',
    text: 'Add any shortcut from Apple’s Shortcuts app to the menu — dark mode, a Focus, your smart lights — and run it from the menu bar.',
  },
  {
    kind: 'Calendar',
    needs: 'Calendar',
    title: 'Next meeting',
    text: 'What’s coming up on your calendar, right in the menu, with a Join button for Zoom, Meet, Teams and Webex calls.',
  },
];

// The display tools — the part of the app behind MaxCandela Pro.
const FEATURES = [
  {
    title: 'XDR brightness boost',
    text: 'On a MacBook Pro XDR display, lifts your whole screen — desktop, every app, every window — past the brightness macOS normally caps everyday content at.',
  },
  {
    title: 'Extra Dim',
    text: 'Take the screen below the lowest step of the brightness keys, for a dark room late at night. Works on any Mac display.',
  },
  {
    title: 'Warmth',
    text: 'Shift the picture toward a warmer white, all day or only at night — it eases in and out over half an hour rather than snapping. Works on any Mac display.',
  },
  {
    title: 'True colors',
    text: 'The boost is colour-calibrated and preserves your display’s ColorSync profile. Brighter — never washed out.',
  },
  {
    title: 'Looks after your Mac',
    text: 'Never exceeds the limits macOS enforces for HDR. Because a bright screen makes heat, MaxCandela tracks how hard and how long it has been driving your display and eases the boost down as it warms — and cuts it entirely if it gets too hot, restoring it once things cool.',
  },
  {
    title: 'Works the way you do',
    text: 'Set a keyboard shortcut, pause the boost on battery, boost only in the apps you choose, and leave a second monitor alone.',
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
    a: 'Every tool except the brightness boost runs on any Mac with macOS 15.6 or later — MacBook Air, iMac and Mac mini included. The brightness boost needs a display with HDR headroom: a MacBook Pro 14″ or 16″ with the Liquid Retina XDR display, or a Pro Display XDR. Those panels can sustain ~1,000 nits while macOS holds everyday content near 600. MacBook Air, iMac and ordinary external monitors have no headroom to unlock. Two newer cases we have not been able to confirm: MacBook Pros with an M5 Pro or M5 Max chip, where a macOS bug is reported to stop display adjustments of this kind from taking effect, and the PROLED XDR display, which we have not tested. The app tells you straight away if your display has no headroom, the browser demo on this page is an honest test, and the display tools are free to try for 5 days — check that the boost visibly works on your Mac before you buy.',
  },
  {
    q: 'What is free and what is Pro?',
    a: 'The eight everyday tools — Keep Awake, Timer, the clipboard text tools with a short history, the color picker, Generate, World Clock, Sound and the system read-out — are free with no time limit. MaxCandela Pro adds the six Pro tools (Hide Menu Bar Icons, the clipboard manager, Window Snapping, Copy Text from Screen, Shortcuts and Next Meeting) and the three display tools (the XDR brightness boost, Extra Dim and Warmth). Pro is free for 5 days, then $0.99/month or $9.99 once.',
  },
  {
    q: 'Which tools ask for a system permission?',
    a: 'Three, and only when you first use them: Window Snapping needs Accessibility (it is the only way one app may move another app’s windows), Copy Text from Screen needs Screen Recording (to read the box you draw, and nothing else), and Next Meeting needs Calendar access. None of the free tools asks for anything, and MaxCandela never asks at launch.',
  },
  {
    q: 'Will it drain my battery?',
    a: 'Brightness costs power — the boost uses more battery, just like HDR video playback does. Toggle it off when you don’t need it, or switch on “Pause Boost on Battery” under Options and it will wait until you’re plugged in.',
  },
  {
    q: 'How does the free trial work?',
    a: 'Download free from the Mac App Store and get 5 days with all of Pro unlocked as well as the free tools. The clock starts when your Apple ID first downloads MaxCandela, so open it soon after installing to get the full five days. After that, keep Pro for $0.99/month or unlock it forever for $9.99; the everyday tools stay free either way. One purchase works on all Macs signed into your Apple ID.',
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
        {/* ---- Hero: the whole section is a MacBook screen. The system menu
            bar runs across the top, the headline sits on the desktop, and
            the app's menu drops open from its ☀ icon at the right. ---- */}
        <section className="hero">
          <div className="mock-notch" aria-hidden="true" />
          <MockMenuBar />
          <div className="hero-desktop">
          <div className="hero-copy">
            <p className="kicker">Menu-bar toolbox for Mac</p>
            {/* Toolbox-first since the 2026-11 pivot. "Mac" and "menu bar"
                carry the heading weight now; the MacBook Pro brightness query
                is served by the display section's h2 and /how-it-works/. */}
            <h1>
              17 Mac tools.
              <br />
              <span className="hl">One menu-bar icon.</span>
            </h1>
            <p className="subtitle">
              Keep Awake, a timer, clipboard tools, a color picker and more —
              free. Pro replaces a shelf of paid utilities: window snapping, a
              clipboard manager, hidden menu-bar icons, text capture, and an
              XDR brightness boost for MacBook Pro.
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
              <ScrollLink targetId="tools" className="cta cta-secondary">
                See the tools
              </ScrollLink>
            </div>
            <ul className="hero-meta">
              <li>Eight tools free, no time limit</li>
              <li>Any Mac with macOS 15.6 or later</li>
              <li>No account</li>
            </ul>
          </div>
          <MockMenu />
          </div>
        </section>

        {/* ---- Tools (free) ---- */}
        <section className="block" id="tools">
          <div className="section-head">
            <span className="section-label">Free</span>
            <h2>The everyday Mac utilities, without eight separate apps</h2>
            <p className="section-sub">
              One icon in the menu bar instead of a row of them. None of these
              needs an account, a permission prompt or a window.
            </p>
          </div>
          <dl className="spec">
            {TOOLS.map((t) => (
              <div className="spec-row" key={t.title}>
                <dt>{t.title}</dt>
                <dd>{t.text}</dd>
              </div>
            ))}
          </dl>
        </section>

        {/* ---- Pro tools ---- */}
        <section className="block" id="pro">
          <div className="section-head">
            <span className="section-label">MaxCandela Pro</span>
            <h2>Six tools people usually buy one app at a time</h2>
            <p className="section-sub">
              A window manager, a clipboard manager, a menu-bar organiser and
              a screen text reader are each their own purchase elsewhere. Here
              they are one unlock, free to try for 5 days.
            </p>
          </div>
          <div className="panels">
            {PRO_TOOLS.map((t) => (
              <article className="panel" key={t.title}>
                <span className="panel-kind">{t.kind}</span>
                <h3>{t.title}</h3>
                <p>{t.text}</p>
                {t.needs && (
                  <span className="panel-note">
                    Asks for {t.needs} access the first time you use it
                  </span>
                )}
              </article>
            ))}
          </div>
        </section>

        {/* ---- Display tools (Pro) ---- */}
        <section className="block" id="display">
          <div className="section-head">
            <span className="section-label">MaxCandela Pro · Display</span>
            <h2>Brighter, dimmer, warmer — control macOS doesn’t give you</h2>
            <p className="section-sub">
              The brightness boost needs a MacBook Pro XDR display. Extra Dim
              and Warmth work on any Mac.
            </p>
          </div>
          <div className="trio">
            {FEATURES.slice(0, 3).map((f) => (
              <div className="trio-item" key={f.title}>
                <h3>{f.title}</h3>
                <p>{f.text}</p>
              </div>
            ))}
          </div>
        </section>

        {/* ---- The boost, shown: before/after ---- */}
        <section className="showcase">
          <h2>How dark your MacBook Pro screen is now vs. how bright it gets</h2>
          <p className="section-sub">
            A MacBook Pro XDR panel can sustain around 1,000 nits; macOS holds
            everyday content near 600. Drag the slider — the left is the
            screen at its normal cap, the right is the same desktop with the
            boost on.
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
          <dl className="spec spec-tight">
            {FEATURES.slice(3).map((f) => (
              <div className="spec-row" key={f.title}>
                <dt>{f.title}</dt>
                <dd>{f.text}</dd>
              </div>
            ))}
          </dl>
        </section>

        {/* ---- Live demo ---- */}
        <section className="demo" id="demo">
          <div className="demo-text">
            <span className="section-label">Try it here</span>
            <h2>Don’t take our word for it — try the brightness boost</h2>
            <p className="demo-copy">
              On a MacBook Pro XDR display, this page can boost itself the
              same way, right in your browser. Press the button and imagine
              your whole Mac like this.
            </p>
            <p className="demo-fineprint">
              The web demo brightens this page only. The Mac app brightens
              everything, system-wide.
            </p>
          </div>
          <div className="demo-control">
            <button
              className={`toggle toggle-big ${enabled ? 'toggle-on' : ''}`}
              onClick={toggle}
              disabled={supported !== true || isMac !== true}
              aria-pressed={enabled}
            >
              <span className="toggle-dot" aria-hidden="true" />
              {enabled ? 'Boost on — press to restore' : 'Try the boost'}
            </button>
            <div className={`status ${status.cls}`} role="status">
              <span className="status-dot" aria-hidden="true" />
              {status.text}
            </div>
            {status.note && <p className="demo-fineprint">{status.note}</p>}
            {enabled && unlocker?.error && (
              <p className="diag">{unlocker.error}</p>
            )}
          </div>
        </section>

        {/* ---- Pricing ---- */}
        <section className="block pricing" id="pricing">
          <div className="section-head">
            <span className="section-label">Pricing</span>
            <h2>Eight tools free — all 17 for $9.99 once</h2>
            <p className="section-sub">
              The everyday tools cost nothing. Pro is free for 5 days, then
              pick what suits you. The brightness boost needs a MacBook Pro XDR
              display — check that it works on yours during the trial before
              you buy.
            </p>
          </div>
          <div className="price-cards">
            <div className="price-card">
              <h3>Free</h3>
              <p className="price">
                $0<span className="price-per"> forever</span>
              </p>
              <ul>
                <li>Keep Awake and Timer</li>
                <li>Clipboard tools and Generate</li>
                <li>Color picker and World Clock</li>
                <li>Sound and System read-out</li>
              </ul>
              <a className="cta cta-secondary" href={APP_STORE_URL}>
                Download free
              </a>
            </div>
            <div className="price-card">
              <h3>Pro Monthly</h3>
              <p className="price">
                $0.99<span className="price-per"> / month</span>
              </p>
              <ul>
                <li>Everything in Free</li>
                <li>Window snapping, clipboard manager</li>
                <li>Hide menu bar icons, text capture</li>
                <li>Shortcuts and Next Meeting</li>
                <li>XDR brightness boost, Extra Dim, Warmth</li>
                <li>Cancel anytime in the App Store</li>
              </ul>
              <a className="cta cta-secondary" href={APP_STORE_URL}>
                Start free trial
              </a>
            </div>
            <div className="price-card price-card-best">
              <h3>
                Pro Lifetime <span className="badge">Best value</span>
              </h3>
              <p className="price">
                $9.99<span className="price-per"> once</span>
              </p>
              <ul>
                <li>Everything in Free</li>
                <li>Window snapping, clipboard manager</li>
                <li>Hide menu bar icons, text capture</li>
                <li>Shortcuts and Next Meeting</li>
                <li>XDR brightness boost, Extra Dim, Warmth</li>
                <li>Pays for itself in 11 months</li>
              </ul>
              <a className="cta cta-primary" href={APP_STORE_URL}>
                Start free trial
              </a>
            </div>
          </div>
          <p className="pricing-fineprint">
            Purchases via Apple. One purchase covers every Mac on your Apple
            ID. Requires macOS 15.6+; the brightness boost also needs an
            HDR/XDR display (MacBook Pro 14″/16″ with a Liquid Retina XDR
            display, or Pro Display XDR). Subscriptions renew monthly and can
            be cancelled anytime in App Store → Subscriptions; payment is
            charged to your Apple Account. See our{' '}
            <Link href="/terms/">Terms of Use</Link> and{' '}
            <Link href="/privacy/">Privacy Policy</Link>.
          </p>
        </section>

        {/* ---- FAQ ---- */}
        <section className="block faq" id="faq">
          <div className="section-head">
            <span className="section-label">FAQ</span>
            <h2>Questions about the tools, the brightness boost and pricing</h2>
          </div>
          <div className="faq-list">
            {FAQS.map((f) => (
              <details key={f.q}>
                <summary>{f.q}</summary>
                <p>{f.a}</p>
              </details>
            ))}
          </div>
          {/* The only in-body links to the deep pages. Footer-only links give a
              crawler almost nothing to weigh, and /support/ is the page most
              likely to answer a search that lands here. */}
          <p className="faq-more">
            Want the full explanation of the boost? Read{' '}
            <Link href="/how-it-works/">
              how to make your MacBook screen brighter than max
            </Link>{' '}
            — why macOS caps it, and why a bright wallpaper can’t fix it. Still
            stuck? Our <Link href="/support/">support guide</Link> covers
            troubleshooting, subscriptions and promo codes.
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
        'MaxCandela is a menu-bar toolbox for Mac. Free: Keep Awake, a timer, clipboard tools, a color picker, generators, world clocks, a sound switcher and a system read-out. Pro: window snapping, a clipboard manager, hidden menu-bar icons, text capture from the screen, Shortcuts, next meeting, and display tools including an XDR brightness boost for MacBook Pro.',
      // The app itself is free to download and the eight tools are free to
      // keep; the two Offers below are the optional Pro unlock.
      isAccessibleForFree: true,
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
      // Google fully retired the FAQ rich result on 2026-05-07, so this earns
      // nothing in Google's SERP. Kept — not removed — because it accurately
      // describes questions the page really answers, for whatever non-Google
      // consumers read it, at ~2 KB. Do not add FAQPage to another page
      // expecting a SERP gain, and do not claim an AI-citation benefit: no
      // AI provider has confirmed one. For a genuine user-submitted Q&A page
      // the live type is QAPage, not this.
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
