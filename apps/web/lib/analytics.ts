// Google Analytics 4 configuration for the website.
// Measurement IDs are public (they ship in client-side JS), so this is safe to
// commit. Analytics is disabled automatically if this is ever a placeholder,
// and in `next dev` — local page views and clicks are not visitors.
export const GA_ID = 'G-2E5J2Q7FC8';

export const gaConfigured =
  !GA_ID.includes('XXXX') && process.env.NODE_ENV === 'production';

/** Fire a GA event if gtag is loaded; silently a no-op otherwise. */
export function trackEvent(name: string, params?: Record<string, unknown>) {
  if (!gaConfigured || typeof window === 'undefined') return;
  const gtag = (window as unknown as { gtag?: (...args: unknown[]) => void }).gtag;
  gtag?.('event', name, params);
}
