import Link from 'next/link';
import type { Metadata } from 'next';
import LegalShell from '@/components/LegalShell';

// Without this file the 404 inherited the root layout's metadata: an
// `index, follow` robots tag beside the `noindex` Next injects for a 404, and
// a canonical pointing at the home page. Override both, so the page says one
// thing — don't index this — and claims to be no other URL.
export const metadata: Metadata = {
  title: 'Page not found — MaxCandela',
  robots: { index: false, follow: true },
  alternates: { canonical: null },
};

export default function NotFound() {
  return (
    <LegalShell title="Page not found">
      <p>
        There’s nothing at this address. It may have moved, or the link may
        have a typo.
      </p>
      <p>
        Head back to the <Link href="/">home page</Link>, read{' '}
        <Link href="/how-it-works/">how MaxCandela works</Link>, or visit{' '}
        <Link href="/support/">Support</Link> if you were looking for help.
      </p>
    </LegalShell>
  );
}
