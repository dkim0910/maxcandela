import { execFileSync } from 'node:child_process';
import type { MetadataRoute } from 'next';
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
 * Deriving it from git is the accurate option. Do NOT "simplify" this to
 * `new Date()`: build time makes all five routes claim they changed on every
 * deploy, which is the same falsifiable pattern and never self-corrects.
 * Stale is bad; falsely fresh is worse.
 */
const ROUTES = [
  { path: '', source: 'app/page.tsx' },
  { path: 'how-it-works/', source: 'app/how-it-works/page.tsx' },
  { path: 'about/', source: 'app/about/page.tsx' },
  { path: 'privacy/', source: 'app/privacy/page.tsx' },
  { path: 'terms/', source: 'app/terms/page.tsx' },
  { path: 'support/', source: 'app/support/page.tsx' },
];

// Used only when git history is unavailable (a tarball export, or a shallow CI
// clone). deploy-web.yml sets fetch-depth: 0 precisely so this is not hit.
const FALLBACK_LAST_MODIFIED = '2026-08-27';

function lastModified(source: string): Date {
  try {
    const iso = execFileSync('git', ['log', '-1', '--format=%cI', '--', source], {
      cwd: process.cwd(),
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
    if (iso) return new Date(iso);
  } catch {
    // Not a git checkout — fall through.
  }
  return new Date(FALLBACK_LAST_MODIFIED);
}

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
