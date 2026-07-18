import type { Metadata } from 'next';
import Analytics from '@/components/Analytics';
import BoostProvider from '@/components/BoostProvider';
import { SITE_URL } from '@/lib/site';
import './globals.css';

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
        <Analytics />
        <BoostProvider>{children}</BoostProvider>
      </body>
    </html>
  );
}
