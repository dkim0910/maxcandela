import Link from 'next/link';
import SiteFooter from './SiteFooter';
import { SITE_ORIGIN, SITE_URL } from '@/lib/site';

/**
 * Layout wrapper for secondary pages (how-it-works/privacy/terms/support/about):
 * slim header with a link home, breadcrumb trail, readable column, shared
 * footer. Uses next/link so the boost video in the root layout survives
 * navigation.
 *
 * `path` is required for the same reason `pageMetadata` requires it: a page
 * that forgets it would otherwise silently ship no breadcrumb markup at all,
 * which is exactly how the canonical bug went unnoticed for weeks. It must
 * carry the trailing slash — `trailingSlash: true` makes `/about/` the real
 * URL. Pass `""` for a page that has no canonical URL of its own (the 404):
 * it still gets the visible trail, but no BreadcrumbList, because structured
 * data that names a URL the page does not have is worse than none.
 */
export default function LegalShell({
  path,
  title,
  crumb,
  updated,
  children,
}: {
  path: string;
  title: string;
  /** Short label for the breadcrumb when the h1 is too long to sit in a trail. */
  crumb?: string;
  updated?: string;
  children: React.ReactNode;
}) {
  const label = crumb ?? title;

  // Rendered as a visible trail as well as markup. Google's breadcrumb
  // guidance is that the structured data should describe navigation the user
  // can actually see; markup-only breadcrumbs are accepted but are the weaker
  // form, and the trail doubles as a second in-body internal link home.
  const breadcrumbSchema = path
    ? {
        '@context': 'https://schema.org',
        '@type': 'BreadcrumbList',
        '@id': `${SITE_URL}${path}#breadcrumb`,
        itemListElement: [
          { '@type': 'ListItem', position: 1, name: 'Home', item: SITE_ORIGIN },
          // The last crumb is the current page, so it carries no `item` —
          // omitting it is the documented form for the trailing entry.
          { '@type': 'ListItem', position: 2, name: label },
        ],
      }
    : null;

  return (
    // Normal-flow wrapper so Next's scroll restoration doesn't target the fixed
    // <nav> (avoids the "Skipping auto-scroll" console warning).
    <div>
      {breadcrumbSchema && (
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(breadcrumbSchema) }}
        />
      )}
      {/* The nav used to be brand-only, which made every secondary page a
          dead end: one link out, and nothing pointing across to its siblings.
          Crawlers weigh in-body internal links, and a reader who lands on
          /terms/ from search needs a way to reach the rest of the site. */}
      <nav className="navbar">
        <Link className="brand" href="/">
          <img className="brand-logo" src="/brand.png" alt="" width={28} height={28} />
          MaxCandela
        </Link>
        <div className="nav-links">
          <Link href="/">Home</Link>
          <Link href="/how-it-works/">How it works</Link>
          <Link href="/about/">About</Link>
          <Link href="/support/">Support</Link>
        </div>
      </nav>
      <main className="main legal">
        <nav className="crumbs" aria-label="Breadcrumb">
          <ol>
            <li>
              <Link href="/">Home</Link>
            </li>
            <li aria-current="page">{label}</li>
          </ol>
        </nav>
        <h1>{title}</h1>
        {updated && <p className="legal-updated">Last updated: {updated}</p>}
        {children}
      </main>
      <SiteFooter />
    </div>
  );
}
