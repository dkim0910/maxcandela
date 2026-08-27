// Production domain. Absolute URLs (og/twitter images, canonical, sitemap)
// resolve against this.
//
// SITE_URL has no trailing slash so it concatenates cleanly (`${SITE_URL}/og.png`).
// Anywhere the *homepage itself* is named — canonical, sitemap <loc>, JSON-LD
// `url` — use SITE_ORIGIN instead: Next normalises the canonical to
// `https://maxcandela.com/`, and a slash-less form elsewhere reads as a second
// URL to a crawler that is comparing strings.
export const SITE_URL = 'https://maxcandela.com';
export const SITE_ORIGIN = `${SITE_URL}/`;
export const SITE_NAME = 'MaxCandela';

// No country segment on purpose: Apple 301s this to the visitor's own
// storefront (verified — a bare /app/id… redirects to /<cc>/app/…), so a
// non-US reader lands on their store with their own currency instead of USD.
// Hardcoding /us/ sent everyone to the US listing.
export const APP_STORE_URL = 'https://apps.apple.com/app/id6792267034?mt=12';
