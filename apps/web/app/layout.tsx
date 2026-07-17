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
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
