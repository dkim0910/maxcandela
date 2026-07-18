import type { MetadataRoute } from 'next';
import { SITE_URL } from '@/lib/site';

// Allow all crawlers; point them at the sitemap.
export const dynamic = 'force-static';

export default function robots(): MetadataRoute.Robots {
  return {
    rules: { userAgent: '*', allow: '/' },
    sitemap: `${SITE_URL}/sitemap.xml`,
  };
}
