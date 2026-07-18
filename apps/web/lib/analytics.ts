// Google Analytics 4 configuration for the website.
// TODO: replace with the real Measurement ID (GA4 admin → Data Streams).
// Analytics stays completely disabled while the placeholder is in place.
export const GA_ID = 'G-XXXXXXXXXX';

export const gaConfigured = !GA_ID.includes('XXXX');

/** Fire a GA event if gtag is loaded; silently a no-op otherwise. */
export function trackEvent(name: string, params?: Record<string, unknown>) {
  if (!gaConfigured || typeof window === 'undefined') return;
  const gtag = (window as unknown as { gtag?: (...args: unknown[]) => void }).gtag;
  gtag?.('event', name, params);
}
