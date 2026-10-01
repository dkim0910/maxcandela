import Link from 'next/link';
import type { Metadata } from 'next';
import LegalShell from '@/components/LegalShell';
import { SITE_NAME } from '@/lib/site';

// Without this file the 404 inherited the root layout's metadata: an
// `index, follow` robots tag beside the `noindex` Next injects for a 404, and
// a canonical pointing at the home page. Override those, so the page says one
// thing — don't index this — and claims to be no other URL.
//
// `description` and the social tags need overriding for the same reason and
// were missed the first time: Next merges page metadata over the layout's
// *shallowly*, so the 404 shipped the home page's meta description and, worse,
// its `og:title`/`og:url` — a broken link pasted into Slack or iMessage
// unfurled as the home page, hiding the fact that it was broken at all.
// Low SEO stakes (the page is noindex) but a real reporting one.
export const metadata: Metadata = {
  title: 'Page not found — MaxCandela',
  description:
    'That page doesn’t exist on maxcandela.com. Links to the home page, how MaxCandela works, and support.',
  robots: { index: false, follow: true },
  alternates: { canonical: null },
  openGraph: {
    title: 'Page not found — MaxCandela',
    description: 'That page doesn’t exist on maxcandela.com.',
    siteName: SITE_NAME,
    type: 'website',
    locale: 'en_US',
    // No `url` and no image on purpose: this page has no canonical URL of its
    // own, and an unfurl that looks like a real page defeats the point.
  },
  twitter: {
    card: 'summary',
    title: 'Page not found — MaxCandela',
    description: 'That page doesn’t exist on maxcandela.com.',
  },
};

export default function NotFound() {
  return (
    <LegalShell path="" title="Page not found" crumb="Page not found">
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
