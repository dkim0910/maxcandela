import type { Metadata, Viewport } from 'next';
import Analytics from '@/components/Analytics';
import BoostProvider from '@/components/BoostProvider';
import { APP_STORE_URL, SITE_NAME, SITE_ORIGIN, SITE_URL } from '@/lib/site';
import './globals.css';

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: 'MaxCandela — Unlock your MacBook Pro’s full XDR brightness',
  description:
    'Your MacBook Pro XDR display can go 70% brighter than macOS allows. One click in the menu bar unlocks it — true colors, heat-aware, $9.99 once.',
  applicationName: SITE_NAME,
  // Self-referential canonical for the HOMEPAGE only. Every child route MUST
  // override this with its own path — metadata is inherited, so a child that
  // omits `alternates` silently tells Google it is a duplicate of the home
  // page. That was live for weeks and is why the secondary pages never
  // indexed; see the per-page `alternates` in app/*/page.tsx.
  alternates: {
    canonical: '/',
  },
  // Opt in to full-size image and text previews. Without max-image-preview
  // Google may fall back to a thumbnail-or-nothing preview (and does so by
  // default for EU traffic), which suppresses og.png on a product whose whole
  // pitch is visual. Bing honours the generic `robots` tag.
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      'max-image-preview': 'large',
      'max-snippet': -1,
      'max-video-preview': -1,
    },
  },
  openGraph: {
    title: 'MaxCandela — Unlock your MacBook Pro’s full XDR brightness',
    description:
      'Your XDR display can go 70% brighter than macOS allows. One click in the menu bar unlocks it — true colors, automatic heat protection, $9.99 once.',
    url: SITE_ORIGIN,
    siteName: SITE_NAME,
    type: 'website',
    locale: 'en_US',
    images: [{ url: '/og.png', width: 1200, height: 630, alt: 'MacBook Pro with its screen blazing at full brightness' }],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'MaxCandela — Unlock your MacBook Pro’s full XDR brightness',
    description:
      'Your XDR display can go 70% brighter than macOS allows. One click in the menu bar unlocks it — true colors, automatic heat protection, $9.99 once.',
    images: ['/og.png'],
  },
};

// themeColor lives on `viewport`, not `metadata`, since Next 14 — setting it in
// `metadata` is silently ignored and logs a warning at build.
export const viewport: Viewport = {
  themeColor: '#0a0c0f',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    // suppressHydrationWarning: browser extensions inject attributes into
    // <html> and <body> before React hydrates (data-hwp-extension, Grammarly's
    // data-gr-ext-installed, …), which would otherwise trigger spurious
    // hydration-mismatch warnings. This only suppresses attribute mismatches
    // on these two elements — real hydration bugs elsewhere still surface.
    <html lang="en" data-scroll-behavior="smooth" suppressHydrationWarning>
      <body suppressHydrationWarning>
        {/* Site-wide identity only. The SoftwareApplication node describes the
            *home page*, so it lives in app/page.tsx — emitting it from here put
            it on /privacy/ and /terms/ too, where each legal page claimed to be
            the app's own page. Structured data must describe the page it is on. */}
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(siteSchema) }}
        />
        <Analytics />
        <BoostProvider>{children}</BoostProvider>
      </body>
    </html>
  );
}

// Organization + WebSite: the entity-resolution pair both Google and Bing use
// to connect maxcandela.com, the brand name, and the App Store listing. Linked
// by @id rather than nested so each node stays addressable.
const siteSchema = {
  '@context': 'https://schema.org',
  '@graph': [
    {
      '@type': 'Organization',
      '@id': `${SITE_ORIGIN}#organization`,
      name: SITE_NAME,
      url: SITE_ORIGIN,
      logo: `${SITE_URL}/brand.png`,
      sameAs: [APP_STORE_URL],
    },
    {
      '@type': 'WebSite',
      '@id': `${SITE_ORIGIN}#website`,
      name: SITE_NAME,
      url: SITE_ORIGIN,
      inLanguage: 'en-US',
      publisher: { '@id': `${SITE_ORIGIN}#organization` },
    },
  ],
};
