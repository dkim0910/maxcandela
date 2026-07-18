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
        version: <strong>we collect no personal data</strong> — only anonymous,
        aggregate usage statistics that cannot be tied to you.
      </p>

      <h2>The Mac app</h2>
      <ul>
        <li>Collects no personal information: no name, email, Apple ID, or
          anything typed or displayed on your screen.</li>
        <li>Never records, captures, or transmits your screen content — the
          brightness boost works without ever reading what is on your
          display.</li>
        <li>Sends a few anonymous usage events (app launched, boost turned
          on/off, purchase completed) to Google Analytics so we can understand
          how the app is used. These events carry only a random per-install
          identifier that is not linked to you and can be reset by deleting
          the app’s preferences.</li>
        <li>Otherwise makes no network connections except to Apple’s App Store
          services for purchases and license verification (handled by Apple’s
          StoreKit framework).</li>
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
        <li>Is a static site with no accounts.</li>
        <li>Uses Google Analytics to count visits and understand aggregate
          usage (pages viewed, the demo toggle being used). We configure it
          with IP anonymization and with advertising/personalization signals
          disabled. Google Analytics sets cookies (e.g. <code>_ga</code>) for
          this purpose; see{' '}
          <a href="https://policies.google.com/privacy">Google’s Privacy
          Policy</a> for how Google processes this data.</li>
        <li>The in-browser brightness demo runs entirely on your device —
          nothing about your display or its content is sent anywhere.</li>
        <li>Our hosting provider may keep standard, short-lived server logs
          (such as IP addresses) to operate the service; we do not use them to
          identify anyone.</li>
      </ul>

      <h2>Children</h2>
      <p>
        MaxCandela does not knowingly collect personal data from anyone,
        including children.
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
