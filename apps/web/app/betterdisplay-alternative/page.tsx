import Link from 'next/link';
import type { Metadata } from 'next';
import { pageMetadata } from '@/lib/metadata';
import LegalShell from '@/components/LegalShell';
import { APP_STORE_URL } from '@/lib/site';

const PATH = '/betterdisplay-alternative/';
const TITLE = 'MaxCandela vs BetterDisplay for MacBook Pro XDR brightness';
const DESCRIPTION =
  'BetterDisplay is a full display toolkit; MaxCandela is a one-click XDR brightness boost with menu-bar tools. Price, trial, how each brightens the screen, and which to pick.';

export const metadata: Metadata = pageMetadata({
  path: PATH,
  title: TITLE,
  description: DESCRIPTION,
});

/*
 * Every claim about BetterDisplay below was read on 2026-11-22 from
 * betterdisplay.pro (home page, /guide/licensing/free-and-pro-features/,
 * /guide/tutorials/xdr-and-hdr-brightness-upscaling/) and the README at
 * github.com/waydabber/BetterDisplay. "Not on the Mac App Store" is from an
 * iTunes Search API query for "betterdisplay" (macSoftware, US) the same day.
 *
 * Re-check all of them before editing this page, and change CHECKED when you
 * do: a comparison page that misstates a competitor's price is worse than no
 * page. Claims about MaxCandela must match the app — the 14-day trial and free
 * Extra Dim ship in 2.1.0 (the page went live with the site on 2026-11-22,
 * ahead of that release).
 *
 * Deliberately left out: anything their pages do not say (e.g. whether their
 * methods work on M5 Pro / M5 Max), and rows that would read as "they lack X"
 * when all we know is that the pages we read did not mention X.
 */
const CHECKED = 'November 22, 2026';

const ROWS: { label: string; ours: string; theirs: string }[] = [
  {
    label: 'What it is',
    ours: 'A one-click XDR brightness boost, plus 26 small menu-bar tools',
    theirs:
      'A full display toolkit: HiDPI scaling, virtual screens, DDC control of external monitors, EDID overrides, picture-in-picture, XDR/HDR brightness and more',
  },
  {
    label: 'Price of the brightness boost',
    ours: '$9.99 once, or $0.99 a month',
    theirs: '$21.99 / €19.99 Pro licence, with at least two years of updates',
  },
  {
    label: 'Free trial',
    ours: '14 days of everything',
    theirs: '14 days of Pro',
  },
  {
    label: 'Where you buy it',
    ours: 'Mac App Store — buy and restore with your Apple Account',
    theirs: 'betterdisplay.pro (payments through Paddle) or Homebrew; not on the Mac App Store',
  },
  {
    label: 'macOS',
    ours: '15.6 or later',
    theirs: 'Version 5: 26.3 or later. Version 4: 13.2 or later',
  },
  {
    label: 'Displays the boost supports',
    ours: 'MacBook Pro 14″/16″ with Liquid Retina XDR, Pro Display XDR',
    theirs: 'Apple XDR displays, and third-party HDR displays in HDR mode; Intel Macs through its Metal method',
  },
];

export default function BetterDisplayAlternativePage() {
  return (
    <LegalShell path={PATH} title={TITLE} crumb="vs BetterDisplay" updated={CHECKED}>
      <p>
        Both apps light up the brightness a MacBook Pro’s XDR display keeps in
        reserve for HDR, so everyday content can go brighter than macOS
        normally allows. Beyond that they are different products, and the
        honest answer to “which one?” depends on what else you need.
      </p>
      <p>
        <strong>The short version:</strong> if you want a brighter screen and
        nothing to configure, MaxCandela does that for less than half the
        price. If you need to manage external monitors, HiDPI resolutions or
        an Intel Mac, BetterDisplay does far more, and its brightness feature
        comes with it.
      </p>

      <h2>At a glance</h2>
      <div className="table-scroll">
        <table>
          <thead>
            <tr>
              <th scope="col"></th>
              <th scope="col">MaxCandela</th>
              <th scope="col">BetterDisplay</th>
            </tr>
          </thead>
          <tbody>
            {ROWS.map((row) => (
              <tr key={row.label}>
                <th scope="row">{row.label}</th>
                <td>{row.ours}</td>
                <td>{row.theirs}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <p className="legal-updated">
        BetterDisplay details from its website and GitHub README, checked{' '}
        {CHECKED}. Prices and features change; check{' '}
        <a href="https://betterdisplay.pro/" rel="nofollow noopener">
          betterdisplay.pro
        </a>{' '}
        for the current terms.
      </p>

      <h2>How each one brightens the screen</h2>
      <p>
        <strong>MaxCandela</strong> uses one method, the same on every
        supported Mac: a tiny HDR patch in a corner of the screen keeps the
        display in its high-brightness mode, and a colour-calibrated lift moves
        your actual content up into that range. It is one click on the ☀️
        icon, a keyboard shortcut, or an action in the Shortcuts app. The{' '}
        <Link href="/how-it-works/">how-it-works page</Link> explains why both
        halves are needed.
      </p>
      <p>
        <strong>BetterDisplay</strong> offers several methods and picks
        between them by Mac and display: a <em>direct</em> mode that expands
        the panel’s hardware range on supported built-in XDR displays (not on
        PROLED MacBook Pros), a <em>color-table</em> mode on Apple silicon, a{' '}
        <em>Metal</em> mode for Intel Macs or as a fallback, and support for
        third-party HDR monitors. You switch upscaling on per display, and
        the brightness slider then goes past 100%; a calibration tool
        fine-tunes it. Its guide notes that the color-table mode can clip HDR
        content and that the Metal mode uses extra processing.
      </p>

      <h2>Heat and battery</h2>
      <p>
        A brighter screen uses more power and makes more heat. BetterDisplay’s
        guide says so and recommends using the lowest brightness that meets
        your needs.
      </p>
      <p>
        MaxCandela manages it for you. It tracks how hard and for how long it
        has been driving the display, eases the boost down as the panel
        warms, and switches it off if things get too hot, bringing it back
        once they cool. You can also have it pause on battery, run only in the
        apps you choose, and leave a second display alone.
      </p>

      <h2>Choose BetterDisplay if…</h2>
      <ul>
        <li>you need HiDPI scaling or custom resolutions on an external monitor;</li>
        <li>you want to control an external monitor’s own brightness, input or volume over DDC;</li>
        <li>you use virtual screens, picture-in-picture or EDID overrides;</li>
        <li>you are on an Intel Mac, or want a brightness boost on a third-party HDR monitor.</li>
      </ul>

      <h2>Choose MaxCandela if…</h2>
      <ul>
        <li>you want the brighter screen and nothing else to set up;</li>
        <li>you would rather pay $9.99 once (or $0.99 a month) than $21.99;</li>
        <li>you want to buy through the Mac App Store, with one purchase covering every Mac on your Apple Account;</li>
        <li>you want the boost to look after the display’s temperature itself;</li>
        <li>
          you would use the extras: Keep Awake, a focus timer, clipboard
          tools, Extra Dim and more are free, and Pro adds screenshots with
          markup, a clipboard manager, a file shelf and per-app volume.
        </li>
      </ul>

      <h2>One caveat for M5 Pro and M5 Max MacBook Pros</h2>
      <p>
        On MacBook Pros with an M5 Pro or M5 Max chip, a macOS bug reported to
        Apple stops MaxCandela’s colour lift from reaching the screen. We have
        not been able to confirm it ourselves, so the{' '}
        <Link href="/support/">support page</Link> asks you to check during the
        free trial before buying. BetterDisplay’s guide does not say whether
        its methods are affected.
      </p>

      <h2>Try both</h2>
      <p>
        Both have a 14-day free trial, so the best test is your own screen.
        You can also try MaxCandela’s boost in this browser first, on the{' '}
        <Link href="/#demo">home page demo</Link>, then{' '}
        <a href={APP_STORE_URL}>download it free from the Mac App Store</a>.
      </p>
      <p className="legal-updated">
        BetterDisplay is a product of Kodeon Software. MaxCandela is not
        affiliated with BetterDisplay or Kodeon Software.
      </p>
    </LegalShell>
  );
}
