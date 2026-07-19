import type { Metadata } from 'next';
import Script from 'next/script';
import Analytics from '@/components/Analytics';
import BoostProvider from '@/components/BoostProvider';
import { SITE_URL } from '@/lib/site';
import './globals.css';

// Google AdSense publisher ID (public — ships in the client script).
const ADSENSE_CLIENT = 'ca-pub-7400069037778721';

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: 'MaxCandela — Unlock your MacBook Pro’s full brightness',
  description:
    'Your XDR display can go 70% brighter than macOS allows. One click in the menu bar unlocks it — full brightness, true colors, zero setup.',
  alternates: {
    canonical: SITE_URL,
  },
  openGraph: {
    title: 'MaxCandela — Unlock your MacBook Pro’s full brightness',
    description:
      'Your XDR display can go 70% brighter than macOS allows. One click unlocks it.',
    url: SITE_URL,
    siteName: 'MaxCandela',
    type: 'website',
    images: [{ url: '/og.png', width: 1200, height: 630, alt: 'MacBook Pro with its screen blazing at full brightness' }],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'MaxCandela — Unlock your MacBook Pro’s full brightness',
    description:
      'Your XDR display can go 70% brighter than macOS allows. One click unlocks it.',
    images: ['/og.png'],
  },
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
        {/* Structured data: tells Google this is a Mac app with these prices,
            so search can show a rich app result. No aggregateRating until we
            have real reviews (fabricating one violates Google's guidelines). */}
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(softwareSchema) }}
        />
        <Analytics />
        <Script
          async
          src={`https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=${ADSENSE_CLIENT}`}
          crossOrigin="anonymous"
          strategy="afterInteractive"
        />
        <BoostProvider>{children}</BoostProvider>
      </body>
    </html>
  );
}

const softwareSchema = {
  '@context': 'https://schema.org',
  '@type': 'SoftwareApplication',
  name: 'MaxCandela',
  applicationCategory: 'UtilitiesApplication',
  operatingSystem: 'macOS 13.0 or later',
  url: SITE_URL,
  image: `${SITE_URL}/og.png`,
  description:
    'MaxCandela unlocks the full brightness of MacBook Pro XDR displays — pushing everyday content past the ~600 nit cap macOS enforces, with one click in the menu bar.',
  offers: [
    { '@type': 'Offer', name: 'Lifetime', price: '9.99', priceCurrency: 'USD' },
    { '@type': 'Offer', name: 'Monthly', price: '0.99', priceCurrency: 'USD' },
  ],
};
