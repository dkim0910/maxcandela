'use client';

import Script from 'next/script';
import { GA_ID, gaConfigured } from '@/lib/analytics';

/**
 * Google Analytics 4 loader. Renders nothing unless `gaConfigured` (a real
 * Measurement ID in lib/analytics.ts, and a production build), so `next dev`
 * stays clean.
 * IP anonymization is on and ad personalization signals are off — keep this
 * in sync with the /privacy page.
 */
export default function Analytics() {
  if (!gaConfigured) return null;
  return (
    <>
      {/* lazyOnload, not afterInteractive. `afterInteractive` makes Next emit
          <link rel="preload" as="script"> for gtag.js into every page's
          <head>, and Chrome gives a preloaded script high priority — so a
          third-party tag competed for bandwidth with the LCP element (the
          comparison image) on the one page that has to load fast. lazyOnload
          emits no preload and defers the fetch to after `window.onload`.
          The cost is real but small: a visitor who leaves before load
          completes is not counted. Worth it on a page whose whole pitch is a
          large image. */}
      <Script
        src={`https://www.googletagmanager.com/gtag/js?id=${GA_ID}`}
        strategy="lazyOnload"
      />
      <Script id="ga-init" strategy="lazyOnload">
        {`
          window.dataLayer = window.dataLayer || [];
          function gtag(){dataLayer.push(arguments);}
          gtag('js', new Date());
          gtag('config', '${GA_ID}', {
            anonymize_ip: true,
            allow_google_signals: false,
            allow_ad_personalization_signals: false
          });
        `}
      </Script>
    </>
  );
}
