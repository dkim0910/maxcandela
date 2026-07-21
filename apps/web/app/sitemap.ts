import type { MetadataRoute } from 'next';
import { SITE_URL } from '@/lib/site';

// Static sitemap for the marketing pages — helps search engines discover and
// index every route. Add new pages here when they're created.
export const dynamic = 'force-static';

export default function sitemap(): MetadataRoute.Sitemap {
  // Explicitly defining the priority per route is the cleanest approach
  const routes = [
    { path: '', priority: 1, lastMod: '2026-07-21' },
    { path: '/about/', priority: 0.6, lastMod: '2026-07-21' },
    { path: '/privacy/', priority: 0.6, lastMod: '2026-07-21' },
    { path: '/terms/', priority: 0.6, lastMod: '2026-07-21' },
    { path: '/support/', priority: 0.6, lastMod: '2026-07-21' },
  ];

  return routes.map((route) => ({
    url: `${SITE_URL}${route.path}`,
    lastModified: new Date(route.lastMod),
    changeFrequency: 'monthly',
    priority: route.priority, // Clean and scalable
  }));
}
