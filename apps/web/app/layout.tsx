import type { Metadata } from 'next';
import BoostProvider from '@/components/BoostProvider';
import './globals.css';

export const metadata: Metadata = {
  title: 'MaxCandela — Unlock your MacBook Pro’s full brightness',
  description:
    'Push your XDR display past its SDR brightness cap, right from the browser.',
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
    <html lang="en" suppressHydrationWarning>
      <body suppressHydrationWarning>
        <BoostProvider>{children}</BoostProvider>
      </body>
    </html>
  );
}
