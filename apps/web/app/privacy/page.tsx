import Link from 'next/link';
import type { Metadata } from 'next';
import LegalShell from '@/components/LegalShell';

export const metadata: Metadata = {
  title: 'Privacy Policy — MaxCandela',
};

export default function PrivacyPage() {
  return (
    <LegalShell title="Privacy Policy" updated="July 18, 2026">
      <p>
        MaxCandela is built to collect as little as possible. The short
        version: <strong>we collect no personal data at all.</strong>
      </p>

      <h2>The Mac app</h2>
      <ul>
        <li>Collects no personal information, usage data, or analytics.</li>
        <li>Never records, captures, or transmits your screen content — the
          brightness boost works without ever reading what is on your
          display.</li>
        <li>Makes no network connections except to Apple’s App Store services
          for purchases and license verification (handled by Apple’s StoreKit
          framework).</li>
        <li>Stores its settings (whether the boost is enabled, trial start
          date) only on your Mac.</li>
      </ul>

      <h2>Purchases</h2>
      <p>
        All payments are processed by Apple through your Apple Account. We
        never see your payment details, name, or email address. Apple’s
        handling of that data is covered by{' '}
        <a href="https://www.apple.com/legal/privacy/">Apple’s Privacy
        Policy</a>.
      </p>

      <h2>This website</h2>
      <ul>
        <li>Is a static site with no accounts, no cookies, no trackers, and no
          analytics.</li>
        <li>The in-browser brightness demo runs entirely on your device —
          nothing about your visit or display is sent anywhere.</li>
        <li>Our hosting provider may keep standard, short-lived server logs
          (such as IP addresses) to operate the service; we do not use them to
          identify anyone.</li>
      </ul>

      <h2>Children</h2>
      <p>
        MaxCandela does not knowingly collect data from anyone, including
        children, because it does not collect data.
      </p>

      <h2>Changes</h2>
      <p>
        If this policy ever changes, we will update this page and the “last
        updated” date above. Material changes will be noted in the app’s
        release notes.
      </p>

      <h2>Contact</h2>
      <p>
        Questions? See our <Link href="/support/">Support page</Link>.
      </p>
    </LegalShell>
  );
}
