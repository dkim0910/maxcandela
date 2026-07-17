import type { Metadata } from 'next';
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
    // <html> before React hydrates (e.g. data-hwp-extension), which would
    // otherwise trigger a spurious hydration-mismatch warning. This only
    // suppresses attribute mismatches on this one element.
    <html lang="en" suppressHydrationWarning>
      <body>{children}</body>
    </html>
  );
}
