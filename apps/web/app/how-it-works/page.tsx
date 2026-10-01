import Link from 'next/link';
import type { Metadata } from 'next';
import { pageMetadata } from '@/lib/metadata';
import LegalShell from '@/components/LegalShell';
import { firstPublished, lastModified } from '@/lib/git';
import { APP_STORE_URL, SITE_NAME, SITE_ORIGIN, SITE_URL } from '@/lib/site';

const PATH = '/how-it-works/';
const TITLE = 'How to make your MacBook screen brighter than max';
const DESCRIPTION =
  'Why macOS caps your MacBook Pro at ~600 nits when the panel is rated for 1,000, why a white wallpaper or bright overlay can’t fix it, and what actually works.';

// This page's own source file — the thing whose commit dates ARE the article's
// dates. Relative to apps/web, which is `cwd` at build time.
const SOURCE = 'app/how-it-works/page.tsx';

export const metadata: Metadata = pageMetadata({
  path: PATH,
  title: TITLE,
  description: DESCRIPTION,
});

/**
 * The only informational page on the site, so the only one where an article
 * node is honest: the other five are the app's own pages (SoftwareApplication
 * on `/`) or boilerplate. `TechArticle` rather than `Article` because the
 * content is a technical explanation — Google treats it as an Article subtype,
 * so it is eligible for the same treatment with a more accurate type.
 *
 * Dates come from git via the same helper the sitemap uses, so `dateModified`
 * and this route's `<lastmod>` are the same value by construction. Two
 * freshness dates that disagree is the pattern that gets the signal discarded.
 *
 * Deliberately no `HowTo`: despite the page's title, Google retired the HowTo
 * rich result in September 2023, and the markup now buys nothing.
 */
function articleSchema() {
  return {
    '@context': 'https://schema.org',
    '@type': 'TechArticle',
    '@id': `${SITE_URL}${PATH}#article`,
    headline: TITLE,
    description: DESCRIPTION,
    mainEntityOfPage: { '@type': 'WebPage', '@id': `${SITE_URL}${PATH}` },
    datePublished: firstPublished(SOURCE).toISOString(),
    dateModified: lastModified(SOURCE).toISOString(),
    image: `${SITE_URL}/og.png`,
    inLanguage: 'en-US',
    // The Organization node is defined once in the root layout; both of these
    // reference it by @id rather than restating it.
    author: { '@id': `${SITE_ORIGIN}#organization` },
    publisher: { '@id': `${SITE_ORIGIN}#organization` },
    // Restated rather than referenced by @id: the SoftwareApplication node
    // lives on the home page, and an @id this page never defines leaves a
    // dangling reference in the graph a validator reads here.
    about: { '@type': 'SoftwareApplication', name: SITE_NAME, url: SITE_ORIGIN },
    articleSection: 'Displays',
    keywords: [
      'MacBook Pro brightness',
      'XDR display',
      'EDR headroom',
      'nits',
      'macOS brightness cap',
    ],
  };
}

export default function HowItWorksPage() {
  return (
    <LegalShell path={PATH} title={TITLE} crumb="How it works">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(articleSchema()) }}
      />
      <p>
        If you have pushed the brightness slider on a 14″ or 16″ MacBook Pro
        all the way up and thought <em>“this panel can do more than
        this”</em> — you are right. It can. Here is exactly why macOS holds
        the rest back, why the obvious workarounds fail, and what actually
        works.
      </p>

      <h2>Your display has two brightness limits, not one</h2>
      <p>
        The Liquid Retina XDR display in a MacBook Pro 14″/16″ (2021 or later)
        is rated for around <strong>1,000 nits sustained</strong>. But when you
        drag the brightness slider to maximum, ordinary content — your desktop,
        Safari, Xcode, this page — stops at roughly <strong>600 nits</strong>.
      </p>
      <p>
        That is not your Mac being tired or throttled. It is a deliberate
        split. macOS enforces one cap on <strong>SDR</strong> (standard dynamic
        range) content, which is everything you normally look at, and keeps the
        remaining backlight in reserve for <strong>HDR</strong> content. Apple
        exposes that reserve to applications as <strong>EDR</strong> — Extended
        Dynamic Range — and it exists so an HDR movie can show a genuinely
        bright highlight without every white window on your screen burning at
        the same level all day. Brightness is power, and power is heat and
        battery drain.
      </p>

      <h2>See it for yourself, free, in about thirty seconds</h2>
      <p>
        You do not need any software to prove the headroom is there. Set your
        display brightness to maximum, then play an HDR video — an HDR clip on
        YouTube, or an HDR photo in Photos. Watch the bright parts of the
        video: they will visibly exceed the white of the window frame around
        them. That extra range is the reserve, and it is sitting unused every
        moment you are not watching HDR.
      </p>

      <h2>Why a white wallpaper or a bright overlay does not work</h2>
      <p>
        This is the part almost every guide gets wrong, and it is worth
        understanding before you try anything.
      </p>
      <p>
        The intuitive hack is: put something HDR on screen to wake the extra
        backlight, and everything else gets brighter too. It does not work, and
        we tested this on real hardware before building anything.{' '}
        <strong>While HDR content is on screen, macOS raises the backlight and
        simultaneously compensates SDR pixels downward.</strong> The two
        changes cancel out. Your desktop, your apps and your text keep exactly
        the same apparent brightness — the backlight is working harder for no
        visible benefit at all.
      </p>
      <p>
        So a hidden HDR video, a white HDR wallpaper, or a bright window parked
        in the corner all achieve nothing except heat. The reserve is real, but
        you cannot reach it by leaving it switched on nearby.
      </p>

      <h2>What actually works: lift the pixels themselves</h2>
      <p>
        Because macOS compensates SDR content downward, the only way to get a
        brighter screen is to move <em>your actual content</em> up into the EDR
        range rather than just waking the backlight next to it. That takes two
        things working together:
      </p>
      <ul>
        <li>
          <strong>Keep the display in EDR mode.</strong> Something on screen
          has to be genuine EDR content, or the headroom is not engaged at all.
        </li>
        <li>
          <strong>Scale every SDR pixel up into that headroom.</strong> On
          macOS this is done through the display’s transfer tables — the same
          mechanism your color profile uses.
        </li>
      </ul>
      <p>
        The second step is where quality is won or lost. Those tables hold
        gamma-encoded values, so multiplying them directly overdrives luminance
        and clips color channels — which is exactly why a badly implemented
        boost leaves you with a bright but washed-out, contrast-crushed screen.
        Done properly, the scaling accounts for the encoding and preserves your
        display’s existing ColorSync calibration curves, so you get more
        brightness with your colors intact.
      </p>

      <h2>The catch nobody mentions: heat</h2>
      <p>
        A brighter panel is a warmer panel. That is physics, not a bug, and any
        tool that unlocks this brightness makes real heat — you will feel it
        above the keyboard.
      </p>
      <p>
        Worth knowing: macOS’s own thermal reporting will not save you here.
        The heat a bright backlight makes lands in the <em>panel</em>, and the
        system’s thermal state tracks pressure on the <em>chip</em>. On a
        MacBook Pro running a sustained full boost, that reading can stay at
        “nominal” the entire time. Any brightness tool that relies on it alone
        is, in practice, running with no protection at all. Whatever you use,
        make sure it tracks how hard and how long it has been driving the
        display and eases off on its own.
      </p>

      <h2>The one-click version</h2>
      <p>
        <Link href="/">MaxCandela</Link> does all of the above from your menu
        bar: it engages EDR, lifts every pixel with the color-preserving
        transform, follows the headroom macOS reports moment to moment, and
        runs its own panel-heat model that eases the boost down as your Mac
        warms and restores it as it cools. One click on, one click off — and
        turning it off puts your display back exactly where it was.
      </p>
      <p>
        You can{' '}
        <Link href="/#demo">try the same trick in your browser</Link> on this
        site before installing anything. It brightens this page only — the app
        is what brightens every app and window — but if the demo works on your
        display, the app will too.
      </p>
      <p>
        It is free for 5 days from the{' '}
        <a href={APP_STORE_URL}>Mac App Store</a>, then $9.99 once or $0.99 a
        month. It needs a MacBook Pro 14″/16″ (2021 or later) or a Pro Display
        XDR — a MacBook Air or an ordinary external monitor has no headroom to
        unlock. More detail on{' '}
        <Link href="/support/">the support page</Link>.
      </p>
    </LegalShell>
  );
}
