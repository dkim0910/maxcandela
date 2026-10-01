import type { MetadataRoute } from 'next';
import { lastModified } from '@/lib/git';
import { SITE_ORIGIN } from '@/lib/site';

// Static sitemap for the marketing pages — helps search engines discover and
// index every route. Add new pages to ROUTES when they're created.
export const dynamic = 'force-static';

/**
 * Every indexable route, paired with the source file whose last commit date IS
 * that page's last-modified date.
 *
 * `lastmod` used to be a hardcoded '2026-07-21' on all five routes while four
 * of them had been edited after that. Google only honours lastmod when it is
 * "consistently and verifiably accurate" — a date that contradicts the
 * Last-Modified header is trivially falsifiable, so the signal gets discarded
 * site-wide rather than merely ignored.
 *
 * Deriving it from git is the accurate option (see lib/git.ts, which also
 * feeds the `dateModified` in /how-it-works/'s article schema so the two can
 * never disagree). Do NOT "simplify" this to `new Date()`: build time makes
 * all six routes claim they changed on every deploy, which is the same
 * falsifiable pattern and never self-corrects. Stale is bad; falsely fresh is
 * worse.
 */
const ROUTES = [
  { path: '', source: 'app/page.tsx' },
  { path: 'how-it-works/', source: 'app/how-it-works/page.tsx' },
  { path: 'about/', source: 'app/about/page.tsx' },
  { path: 'privacy/', source: 'app/privacy/page.tsx' },
  { path: 'terms/', source: 'app/terms/page.tsx' },
  { path: 'support/', source: 'app/support/page.tsx' },
];

export default function sitemap(): MetadataRoute.Sitemap {
  // No changeFrequency/priority: Google states outright that it ignores both,
  // and the previous comment here claimed they were doing something.
  return ROUTES.map((route) => ({
    // SITE_ORIGIN carries the trailing slash, matching the canonical Next
    // emits. `${SITE_URL}` alone produced a slash-less homepage <loc> that
    // disagreed with its own canonical.
    url: `${SITE_ORIGIN}${route.path}`,
    lastModified: lastModified(route.source),
  }));
}
