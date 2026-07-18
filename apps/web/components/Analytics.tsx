'use client';

import Script from 'next/script';
import { GA_ID, gaConfigured } from '@/lib/analytics';

/**
 * Google Analytics 4 loader. Renders nothing until a real Measurement ID is
 * set in lib/analytics.ts, so development and preview builds stay clean.
 * IP anonymization is on and ad personalization signals are off — keep this
 * in sync with the /privacy page.
 */
export default function Analytics() {
  if (!gaConfigured) return null;
  return (
    <>
      <Script
        src={`https://www.googletagmanager.com/gtag/js?id=${GA_ID}`}
        strategy="afterInteractive"
      />
      <Script id="ga-init" strategy="afterInteractive">
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
