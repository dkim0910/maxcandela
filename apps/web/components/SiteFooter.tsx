import Link from 'next/link';

/**
 * Shared footer with the legal/support links every page needs. App Store
 * Connect requires public Privacy Policy and Support URLs; subscriptions
 * additionally require Terms of Use.
 *
 * Internal links use next/link (client-side navigation) so the root layout —
 * and with it the playing boost video — persists across page changes.
 */
export default function SiteFooter() {
  return (
    <footer className="footer">
      <nav className="footer-links">
        <Link href="/">Home</Link>
        <Link href="/about/">About</Link>
        <Link href="/privacy/">Privacy Policy</Link>
        <Link href="/terms/">Terms of Use</Link>
        <Link href="/support/">Support</Link>
      </nav>
      <p>
        MaxCandela · not affiliated with Apple Inc. · “MacBook Pro” and
        “Liquid Retina XDR” are trademarks of Apple Inc.
      </p>
    </footer>
  );
}
