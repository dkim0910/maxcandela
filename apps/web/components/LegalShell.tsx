import Link from 'next/link';
import SiteFooter from './SiteFooter';

/**
 * Layout wrapper for secondary pages (privacy/terms/support/about): slim
 * header with a link home, readable column, shared footer. Uses next/link so
 * the boost video in the root layout survives navigation.
 */
export default function LegalShell({
  title,
  updated,
  children,
}: {
  title: string;
  updated?: string;
  children: React.ReactNode;
}) {
  return (
    // Normal-flow wrapper so Next's scroll restoration doesn't target the fixed
    // <nav> (avoids the "Skipping auto-scroll" console warning).
    <div>
      <nav className="navbar">
        <Link className="brand" href="/">
          <img className="brand-logo" src="/brand.png" alt="" width={28} height={28} />
          MaxCandela
        </Link>
      </nav>
      <main className="main legal">
        <h1>{title}</h1>
        {updated && <p className="legal-updated">Last updated: {updated}</p>}
        {children}
      </main>
      <SiteFooter />
    </div>
  );
}
