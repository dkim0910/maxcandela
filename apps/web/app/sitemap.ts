import type { MetadataRoute } from 'next';
import { SITE_URL } from '@/lib/site';

// Static sitemap for the marketing pages — helps search engines discover and
// index every route. Add new pages here when they're created.
export const dynamic = 'force-static';

export default function sitemap(): MetadataRoute.Sitemap {
  const routes = ['', '/about/', '/privacy/', '/terms/', '/support/'];
  const now = new Date();
  return routes.map((path) => ({
    url: `${SITE_URL}${path}`,
    lastModified: now,
    changeFrequency: 'monthly',
    priority: path === '' ? 1 : 0.6,
  }));
}
