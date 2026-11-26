'use client';

import Link from 'next/link';
import NavBar from '@/components/NavBar';
import SiteFooter from '@/components/SiteFooter';
import ScrollLink from '@/components/ScrollLink';
import BeforeAfter from '@/components/BeforeAfter';
import { MenuShot, MockMenuBar } from '@/components/MenuMock';
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
// card. Kept to one line each: the page lists 27 tools, and full-sentence
// descriptions turned the list into a wall of grey text (2026-11-26). The
// counts in the copy are derived from these arrays: "14 free" is
// TOOLS.length (13) + Extra Dim (free since 2026-11-22), "27" is TOOLS +
// PRO_TOOLS (11) + the three display tools. Hide Menu Bar Icons is counted
// although macOS 27 hides it (see its line); Window Snapping is not — the
// App Store build hides it everywhere (WindowSnapTool.isAvailable).
const TOOLS = [
  { title: 'Keep Awake', text: 'Keeps the display on for half an hour, a few hours, or until you say so.' },
  { title: 'Timer', text: 'A countdown beside the menu-bar icon that chimes when it’s done.' },
  { title: 'Focus', text: 'Work in 25, 50 or 90-minute blocks with breaks in between.' },
  { title: 'Breaks', text: 'Reminds you to look 20 feet away for 20 seconds, then gets out of the way.' },
  { title: 'Clipboard tools', text: 'Change case, trim, sort lines, encode, format JSON. Optional short history.' },
  { title: 'Scratchpad', text: 'A small floating notes window that saves as you type.' },
  { title: 'Color picker', text: 'Any colour on screen, as a hex code on your clipboard.' },
  { title: 'Generate', text: 'A UUID, password, timestamp, filler text or QR code in one click.' },
  { title: 'World clock', text: 'The time in your cities, and whether it’s already tomorrow there.' },
  { title: 'Calendar', text: 'This month as a grid in the menu, with week numbers.' },
  { title: 'Sound', text: 'Switch speakers, headphones and mics, and mute the mic.' },
  { title: 'System at a glance', text: 'CPU, memory, disk, battery health, uptime and local IP.' },
  { title: 'Desktop', text: 'Hide your desktop icons, or paint the menu bar black so the notch blends in.' },
];

// The Pro tools — each one stands in for an app people buy on its own. The
// macOS permission each asks for on first use is listed once, under the
// list (and in the FAQ), not on every line; check those against the tool's
// type comment in apps/macos before changing either.
const PRO_TOOLS = [
  { title: 'Screenshot and markup', text: 'Capture, then add arrows and text, pixelate, redact, crop. Copy or save.' },
  { title: 'Copy text from screen', text: 'Drag over a video, image or PDF; its text lands on your clipboard. Read on your Mac.' },
  { title: 'Scan QR code from screen', text: 'Read a QR code or barcode off a slide, a web page or a call.' },
  { title: 'Clipboard manager', text: 'Your last 200 copies, searchable, on ⌃⌥⌘V. Pin what you reuse.' },
  { title: 'File Shelf', text: 'Park files mid-task, drag them out later. Convert images, merge PDFs.' },
  { title: 'App Volume', text: 'A volume slider for each app that’s playing sound, up to 200%.' },
  { title: 'Bluetooth', text: 'Connect or disconnect paired headphones, keyboards and mice in one click.' },
  { title: 'Dim background windows', text: 'Darken every window except the app you’re working in.' },
  { title: 'Hide menu bar icons', text: 'Tuck icons you rarely need behind a chevron. macOS 26 and earlier.' },
  { title: 'Shortcuts', text: 'Run any shortcut from Apple’s Shortcuts app from the menu.' },
  { title: 'Next meeting', text: 'What’s next on your calendar, with a Join button for video calls.' },
];

// The display tools. The boost and Warmth are MaxCandela Pro; Extra Dim is
// free (BrightnessController.idleScale takes no licence).
const FEATURES = [
  {
    title: 'XDR brightness boost',
    tier: 'Pro',
    text: 'Lifts the whole screen, every app and window, past the cap macOS puts on everyday content. MacBook Pro XDR displays.',
  },
  {
    title: 'Extra Dim',
    tier: 'Free',
    text: 'Takes the screen below the lowest step of the brightness keys, for a dark room. Any Mac.',
  },
  {
    title: 'Warmth',
    tier: 'Pro',
    text: 'A warmer white, all day or only at night, easing in over half an hour. Any Mac.',
  },
  {
    title: 'True colors',
    tier: null,
    text: 'The boost keeps your display’s ColorSync profile. Brighter, not washed out.',
  },
  {
    title: 'Looks after your Mac',
    tier: null,
    text: 'Stays inside the limits macOS sets for HDR, eases off as the panel warms, and cuts out if it gets too hot.',
  },
  {
    title: 'Works the way you do',
    tier: null,
    text: 'A keyboard shortcut, pause on battery, boost only in apps you choose, leave a second monitor alone.',
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
    a: 'Every tool except the brightness boost runs on any Mac with macOS 15.6 or later — MacBook Air, iMac and Mac mini included — with one exception: Hide Menu Bar Icons is offered on macOS 26 and earlier only, because macOS 27 has its own menu-bar overflow and the App Store sandbox blocks the technique there. The brightness boost needs a display with HDR headroom: a MacBook Pro 14″ or 16″ with the Liquid Retina XDR display, or a Pro Display XDR. Those panels can sustain ~1,000 nits while macOS holds everyday content near 600. MacBook Air, iMac and ordinary external monitors have no headroom to unlock. Two newer cases we have not been able to confirm: MacBook Pros with an M5 Pro or M5 Max chip, where a macOS bug is reported to stop display adjustments of this kind from taking effect, and the PROLED XDR display, which we have not tested. The app tells you straight away if your display has no headroom, the browser demo on this page is an honest test, and the boost is free to try for 14 days — check that the boost visibly works on your Mac before you buy.',
  },
  {
    q: 'What is free and what is Pro?',
    a: 'The 13 everyday tools — Keep Awake, Timer, Focus, Breaks, the clipboard text tools with a short history, Scratchpad, the color picker, Generate, World Clock, the Calendar month view, Sound, the system read-out and Desktop — are free with no time limit. So is Extra Dim. MaxCandela Pro adds the eleven Pro tools (Screenshot, Copy Text from Screen, Scan QR Code from Screen, the clipboard manager, File Shelf, App Volume, Bluetooth, Dim Background Windows, Hide Menu Bar Icons, Shortcuts and Next Meeting), events in the Calendar month view, the XDR brightness boost and Warmth. Pro is free for 14 days, then $0.99/month or $9.99 once.',
  },
  {
    q: 'Which tools ask for a system permission?',
    a: 'Six of the Pro tools, and only when you first use them. Screenshot, Copy Text from Screen and Scan QR Code from Screen need Screen Recording, to capture what you select and nothing else. Next Meeting needs Calendar access (the Calendar month view shows events only if you have already granted it, and never asks). Bluetooth needs Bluetooth access, to list and connect your paired devices. App Volume needs System Audio Recording: to change one app’s volume, macOS passes that app’s sound through MaxCandela, which plays it at the level you set — live, never recorded or sent. None of the free tools asks for anything, and MaxCandela never asks at launch.',
  },
  {
    q: 'Will it drain my battery?',
    a: 'Brightness costs power — the boost uses more battery, just like HDR video playback does. Toggle it off when you don’t need it, or switch on “Pause Boost on Battery” under Options and it will wait until you’re plugged in.',
  },
  {
    q: 'How does the free trial work?',
    a: 'Download free from the Mac App Store and get 14 days with all of Pro unlocked as well as the free tools. The clock starts when your Apple ID first downloads MaxCandela, so open it soon after installing to get the full 14 days. After that, keep Pro for $0.99/month or unlock it forever for $9.99; the everyday tools stay free either way. One purchase works on all Macs signed into your Apple ID.',
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
              27 Mac tools.
              <br />
              <span className="hl">One menu-bar icon.</span>
            </h1>
            <p className="subtitle">
              Keep Awake, Focus, Breaks, clipboard tools and a scratchpad are
              free. Pro adds screenshots with markup, a clipboard manager,
              per-app volume and an XDR brightness boost for MacBook Pro.
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
              <li>14 tools free, no time limit</li>
              <li>Any Mac with macOS 15.6 or later</li>
              <li>No account</li>
            </ul>
          </div>
          <MenuShot />
          </div>
        </section>

        {/* ---- Tools (free) ----
            Three short columns instead of one long definition list: the old
            13 rows of full sentences were most of the page's height. */}
        <section className="block" id="tools">
          <div className="section-head">
            <h2>Everyday Mac utilities, free</h2>
            <p className="section-sub">
              No account, no permission prompts, no time limit.
            </p>
          </div>
          <ul className="tool-list">
            {TOOLS.map((t) => (
              <li className="tool" key={t.title}>
                <h3>{t.title}</h3>
                <p>{t.text}</p>
              </li>
            ))}
          </ul>
        </section>

        {/* ---- Pro tools ---- */}
        <section className="block" id="pro">
          <div className="section-head">
            <h2>Pro adds the Mac apps you’d otherwise buy one at a time</h2>
            <p className="section-sub">
              Free for 14 days, then $9.99 once or $0.99 a month.
            </p>
          </div>
          <ul className="tool-list">
            {PRO_TOOLS.map((t) => (
              <li className="tool" key={t.title}>
                <h3>{t.title}</h3>
                <p>{t.text}</p>
              </li>
            ))}
          </ul>
          <p className="list-note">
            Screenshot, Copy Text and Scan QR Code ask for Screen Recording the
            first time you use them. App Volume asks for System Audio
            Recording (the sound is adjusted live, never recorded), Bluetooth
            for Bluetooth, Next Meeting for your calendar. Nothing asks at
            launch.
          </p>
        </section>

        {/* ---- Display: the boost shown, the display tools, the live demo ----
            One section now; it used to be three (a trio, a before/after with
            its own heading, and a boxed demo card). */}
        <section className="block" id="display">
          <div className="section-head">
            <h2>Make your MacBook Pro screen brighter than macOS allows</h2>
            <p className="section-sub">
              An XDR panel can sustain around 1,000 nits; macOS holds everyday
              content near 600. Drag the slider: the left is the normal cap,
              the right is the same desktop with the boost on.
            </p>
          </div>
          <BeforeAfter
            before={COMPARE_NORMAL}
            after={COMPARE_BOOSTED}
            width={COMPARE_WIDTH}
            height={COMPARE_HEIGHT}
            beforeLabel="Now"
            afterLabel="With MaxCandela"
            alt="MacBook Pro XDR display at the macOS brightness cap next to the same desktop unlocked to full brightness by MaxCandela"
          />

          <div className="demo" id="demo">
            <div className="demo-text">
              <h3>Try the boost on this page</h3>
              <p>
                On a MacBook Pro XDR display, this page can brighten itself in
                your browser. The app does the same for the whole screen.
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
                {enabled ? 'Boost on, press to restore' : 'Try the boost'}
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
          </div>

          <ul className="feature-list">
            {FEATURES.map((f) => (
              <li className="feature" key={f.title}>
                <h3>
                  {f.title}
                  {f.tier && <span className="tier">{f.tier}</span>}
                </h3>
                <p>{f.text}</p>
              </li>
            ))}
          </ul>
        </section>

        {/* ---- Pricing ----
            Two cards, not three: Monthly and Lifetime unlock the same thing,
            so they share one card and one list. */}
        <section className="block pricing" id="pricing">
          <div className="section-head">
            <h2>Pricing: 14 tools free, all 27 for $9.99 once</h2>
          </div>
          <div className="price-cards">
            <div className="price-card">
              <h3>Free</h3>
              <p className="price">$0</p>
              <ul>
                <li>The 13 everyday tools above</li>
                <li>Extra Dim</li>
                <li>No time limit, no account</li>
              </ul>
              <a className="cta cta-secondary" href={APP_STORE_URL}>
                Download free
              </a>
            </div>
            <div className="price-card price-card-pro">
              <h3>Pro</h3>
              <p className="price">
                $9.99<span className="price-per"> once</span>
              </p>
              <p className="price-alt">or $0.99 a month, cancel anytime</p>
              <ul>
                <li>Everything in Free</li>
                <li>The 11 Pro tools</li>
                <li>XDR brightness boost and Warmth</li>
                <li>Free for 14 days</li>
                <li>Every Mac on your Apple ID</li>
              </ul>
              <a className="cta cta-primary" href={APP_STORE_URL}>
                Start free trial
              </a>
            </div>
          </div>
          <p className="pricing-fineprint">
            Purchases via Apple. Requires macOS 15.6+; the brightness boost
            also needs an HDR/XDR display (MacBook Pro 14″/16″ with a Liquid
            Retina XDR display, or Pro Display XDR), so check it works on yours
            during the trial. Subscriptions renew monthly and can be cancelled
            anytime in App Store → Subscriptions; payment is charged to your
            Apple Account. See our{' '}
            <Link href="/terms/">Terms of Use</Link> and{' '}
            <Link href="/privacy/">Privacy Policy</Link>.
          </p>
        </section>

        {/* ---- FAQ ---- */}
        <section className="block faq" id="faq">
          <div className="section-head">
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
        'MaxCandela is a menu-bar toolbox for Mac. Free: Keep Awake, a timer, focus sessions, break reminders, clipboard tools, a scratchpad, a color picker, generators including QR codes, world clocks, a month calendar, a sound switcher, a system read-out, desktop icon and notch hiding, and Extra Dim. Pro: screenshots with markup, text and QR code capture from the screen, a clipboard manager, a file shelf, per-app volume, Bluetooth quick-connect, background window dimming, hidden menu-bar icons, Shortcuts, next meeting, and display tools including an XDR brightness boost for MacBook Pro.',
      // The app itself is free to download and the free tools are free to
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
