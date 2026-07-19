import Link from 'next/link';
import type { Metadata } from 'next';
import LegalShell from '@/components/LegalShell';

export const metadata: Metadata = {
  title: 'Terms of Use — MaxCandela',
  description:
    'The terms for using MaxCandela: licensing, the free trial, pricing and subscriptions, fair-use expectations, and warranty.',
};

export default function TermsPage() {
  return (
    <LegalShell title="Terms of Use" updated="July 18, 2026">
      <p>
        These terms apply to the MaxCandela macOS application and this
        website. By downloading or using MaxCandela, you agree to them.
      </p>

      <h2>What MaxCandela does</h2>
      <p>
        MaxCandela increases your display’s effective brightness by using the
        Extended Dynamic Range (EDR) headroom that macOS exposes to
        applications. It never exceeds the limits macOS itself enforces, and
        macOS remains in control of thermal and power protection at all times.
      </p>

      <h2>License</h2>
      <p>
        MaxCandela is licensed, not sold, to you for personal use on Macs you
        own or control, as permitted by the App Store Terms of Service. Apple’s
        standard{' '}
        <a href="https://www.apple.com/legal/internet-services/itunes/dev/stdeula/">
          Licensed Application End User License Agreement
        </a>{' '}
        applies.
      </p>

      <h2>Trial, pricing, and subscriptions</h2>
      <ul>
        <li>The app is free to download and fully functional for a 5-day
          trial.</li>
        <li>After the trial, continued use of the brightness boost requires
          either a one-time lifetime purchase (<strong>$9.99</strong>) or a
          monthly subscription (<strong>$0.99/month</strong>).</li>
        <li>Payment is charged to your Apple Account at confirmation of
          purchase.</li>
        <li>Subscriptions renew automatically each month unless cancelled at
          least 24 hours before the end of the current period. You can manage
          or cancel your subscription anytime in App Store → Account →
          Subscriptions.</li>
        <li>Refunds are handled by Apple under the App Store’s refund
          policy at <a href="https://reportaproblem.apple.com">
          reportaproblem.apple.com</a>.</li>
        <li>Prices may vary by region and are shown in your local currency at
          purchase time.</li>
      </ul>

      <h2>Fair use and expectations</h2>
      <ul>
        <li>Increased brightness increases battery consumption and heat —
          this is physics, not a defect.</li>
        <li>macOS may reduce the available boost under thermal load, on low
          battery, or on displays without EDR headroom. The achievable boost
          depends on your hardware.</li>
        <li>MaxCandela requires a Mac with an EDR-capable display for any
          visible effect (see the compatibility list on the home page).</li>
      </ul>

      <h2>Disclaimer of warranty</h2>
      <p>
        MaxCandela is provided “as is”, without warranty of any kind. To the
        maximum extent permitted by law, we disclaim all warranties, express
        or implied, and are not liable for any damages arising from the use
        or inability to use the software. Nothing in these terms limits
        rights you have under applicable consumer-protection law.
      </p>

      <h2>Changes to these terms</h2>
      <p>
        We may update these terms; the current version always lives at this
        URL with the date above. Continued use after changes means acceptance.
      </p>

      <h2>Contact</h2>
      <p>
        Questions about these terms? See our{' '}
        <Link href="/support/">Support page</Link>.
      </p>
    </LegalShell>
  );
}
