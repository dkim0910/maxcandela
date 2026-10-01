import { execFileSync } from 'node:child_process';

/**
 * Commit dates for a source file, read at build time.
 *
 * Two consumers need the *same* answer about when a page last changed:
 * `app/sitemap.ts` (<lastmod>) and the article schema on /how-it-works/
 * (`dateModified`). Google only honours a freshness date it can corroborate,
 * so two dates for one page that disagree are worse than one date — hence a
 * single helper rather than a constant in each file.
 *
 * Do NOT swap either of these for `new Date()`: build time makes every page
 * claim it changed on every deploy, which is falsifiable on the first check
 * and never self-corrects.
 */

/** Used only when git history is unavailable (a tarball export, or a shallow
 *  CI clone). deploy-web.yml sets fetch-depth: 0 precisely so this is not hit. */
const FALLBACK = '2026-08-27';

function gitDate(args: string[]): string | null {
  try {
    const iso = execFileSync('git', args, {
      cwd: process.cwd(),
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
    // `git log` on an unknown path exits 0 with empty output, so the emptiness
    // check matters as much as the catch.
    return iso || null;
  } catch {
    // Not a git checkout — caller falls back.
    return null;
  }
}

/** Date of the last commit touching `source`, relative to the repo root. */
export function lastModified(source: string): Date {
  return new Date(gitDate(['log', '-1', '--format=%cI', '--', source]) ?? FALLBACK);
}

/** Date of the commit that added `source` — the page's publication date. */
export function firstPublished(source: string): Date {
  // --diff-filter=A keeps only the commit that added the file; --follow would
  // walk renames but cannot be combined with multiple paths, and we pass one.
  const iso = gitDate([
    'log',
    '--diff-filter=A',
    '--format=%cI',
    '--follow',
    '--',
    source,
  ]);
  // A renamed-then-re-added file can yield several lines, oldest last.
  const first = iso?.split('\n').filter(Boolean).pop();
  return new Date(first ?? FALLBACK);
}
