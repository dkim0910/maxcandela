import type { Metadata } from 'next';
import { SITE_NAME, SITE_URL } from './site';

/**
 * Build the metadata for a secondary page.
 *
 * Always use this instead of hand-writing a `metadata` object with just
 * `title` and `description`. Next merges page metadata over the root layout's
 * *shallowly*, so a page that omits `alternates` inherits the layout's
 * canonical — which points at the home page — and a page that omits
 * `openGraph` inherits the home page's og:title/og:description/og:url too.
 * All four secondary pages shipped that way and told Google they were
 * duplicates of `/`. Passing `path` here makes both self-referential.
 *
 * `path` must include the trailing slash: next.config.mjs sets
 * `trailingSlash: true`, so `/about/` is the real URL and `/about` is a
 * redirect to it.
 */
export function pageMetadata({
  path,
  title,
  description,
}: {
  path: string;
  title: string;
  description: string;
}): Metadata {
  return {
    title,
    description,
    alternates: { canonical: path },
    openGraph: {
      title,
      description,
      url: `${SITE_URL}${path}`,
      siteName: SITE_NAME,
      type: 'website',
      locale: 'en_US',
      // Repeated rather than inherited: an `openGraph` object in a page
      // replaces the layout's wholesale, so omitting this drops og:image.
      images: [
        {
          url: '/og.png',
          width: 1200,
          height: 630,
          alt: 'MacBook Pro with its screen blazing at full brightness',
        },
      ],
    },
    twitter: {
      card: 'summary_large_image',
      title,
      description,
      images: ['/og.png'],
    },
  };
}
