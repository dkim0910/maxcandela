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
    <>
      <nav className="navbar">
        <Link className="brand" href="/">
          <span className="brand-icon" aria-hidden="true">☀️</span>
          MaxCandela
        </Link>
      </nav>
      <main className="main legal">
        <h1>{title}</h1>
        {updated && <p className="legal-updated">Last updated: {updated}</p>}
        {children}
      </main>
      <SiteFooter />
    </>
  );
}
