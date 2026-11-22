import Link from 'next/link';
import type { Metadata } from 'next';
import { pageMetadata } from '@/lib/metadata';
import LegalShell from '@/components/LegalShell';

export const metadata: Metadata = pageMetadata({
  path: '/privacy/',
  title: 'Privacy Policy — MaxCandela',
  description:
    'MaxCandela collects no personal data, and what its tools read on your Mac stays there. Read exactly what the app and website do and don’t collect.',
});

export default function PrivacyPage() {
  return (
    <LegalShell
      path="/privacy/"
      title="Privacy Policy"
      crumb="Privacy"
      updated="November 22, 2026"
    >
      <p>
        MaxCandela is built to collect as little as possible. <strong>The Mac
        app collects no personal data</strong>, and what its tools read on your
        Mac — the screen, your files, calendar, audio or Bluetooth devices —
        stays on your Mac. This
        <strong> website</strong> uses analytics and includes Google ad code
        (ads may appear), which can set cookies — details below.
      </p>

      <h2>The Mac app</h2>
      <ul>
        <li>Collects no personal information: no name, email, Apple ID, or
          anything typed or displayed on your screen.</li>
        <li>Never transmits your screen content. The brightness boost works
          without reading what is on your display at all. Three optional Pro
          tools do look at the screen, and only when you use them: they need
          the macOS Screen Recording permission, which is requested the first
          time and can be withdrawn in System Settings.
          <em> Copy Text from Screen</em> and <em>Scan QR Code from
          Screen</em> capture only the box you draw, read the text or code in
          it on your Mac with Apple’s on-device recognition, put the result on
          your clipboard and discard the image. <em>Screenshot</em> keeps its
          capture in memory while the markup window is open; it goes to your
          clipboard only if you copy it, to disk only if you save it to a
          file you choose, and is discarded when you close the window.</li>
        <li>Next Meeting reads your upcoming calendar events — after you grant
          Calendar access — to show them in the menu and find a video-call
          link to open. Events are read on your Mac each time the menu opens
          and are not stored or transmitted. With Pro, the Calendar month view
          reads events the same way when you open it, but only if that access
          has already been granted; it never asks for access itself.</li>
        <li>Bluetooth lists the devices paired with your Mac, connects and
          disconnects them when you click, and reads the battery level of
          devices that report one. It uses the macOS Bluetooth permission,
          requested when you click Allow Bluetooth Access… in its menu. Nothing about
          your devices is stored or sent anywhere.</li>
        <li>App Volume changes the volume of individual apps. For each app you
          move off 100%, macOS passes that app’s sound through MaxCandela,
          which plays it at the level you chose; this uses the macOS System
          Audio Recording permission, requested the first time. The sound is
          processed live on your Mac — never recorded, saved or sent — and
          apps you have not adjusted are not touched. MaxCandela never opens
          your microphone for this.</li>
        <li>File Shelf has access only to the files you drop on it, and keeps
          a reference to them so they are still on the shelf after a restart.
          It never changes, moves or deletes those files. Converted images and
          merged PDFs are written as new files to your Downloads folder;
          converted images leave out location and camera details unless you
          switch that off. Screenshot’s Save writes only to the file you pick
          in the save dialog.</li>
        <li>Dim Background Windows asks macOS for the position, size and owning
          app of the windows on screen — not their titles or contents — to
          know where to darken. This is read on your Mac while the tool is on
          and is not stored or sent.</li>
        <li>Shortcuts stores only the names of the shortcuts you add and asks
          the Shortcuts app to run them; MaxCandela does not see what a
          shortcut does.</li>
        <li>Sends a few anonymous usage events (app launched, boost turned
          on/off, trial-ended prompt shown, purchase completed) to Google
          Analytics so we can understand
          how the app is used. These events carry only a random per-install
          identifier that is not linked to you and can be reset by deleting
          the app’s preferences.</li>
        <li>Reports to RevenueCat, a subscription-analytics service, that the
          app was installed, whether its free trial is running or has ended,
          and — if you buy — the App Store’s signed record of that purchase
          (which product, when, and its transaction ID), so we can see how many
          free trials go on to buy. Its requests also carry basic technical
          details: the app and macOS versions, your Mac’s model, your
          preferred languages, and your App Store country. It uses the{' '}
          <em>same</em> random per-install identifier as above (no second
          identifier, still not linked to you). See{' '}
          <a href="https://www.revenuecat.com/privacy">RevenueCat’s Privacy
          Policy</a> for how RevenueCat processes this data.</li>
        <li>Otherwise makes no network connections except to Apple’s App Store
          services for purchases and license verification (handled by Apple’s
          StoreKit framework).</li>
        <li>Clipboard tools: the text tools read your clipboard only at the
          moment you choose one, and write the result back to it. Clipboard
          history is off until you turn it on; while on, it keeps the last 15
          pieces of text you copy (200 with Pro) <em>in memory only</em> —
          never sent anywhere, cleared when you quit — and skips anything a
          password manager marks as confidential. Only if you also switch on
          the Pro option <em>Remember After Quit</em> is the history saved, to
          a file inside the app’s own private storage on your Mac; switching
          that option or the history off deletes the file.</li>
        <li>The Sound tool changes which audio device your Mac uses and can
          mute the microphone. It never listens to or records audio.</li>
        <li>The color picker uses the macOS system eyedropper. The app
          receives only the single colour you pick, not an image of your
          screen.</li>
        <li>The system read-out (CPU, memory, disk, battery, local IP address)
          is computed on your Mac and shown in the menu. None of it is
          transmitted.</li>
        <li>The Scratchpad saves what you type in it to a file inside the
          app’s own private storage on your Mac, so it is still there after a
          restart. It is never sent anywhere.</li>
        <li>Breaks counts screen time from the system’s own lock, sleep and
          screen-saver events. It does not watch your keyboard or mouse.</li>
        <li>Hide Desktop Icons draws a copy of your wallpaper from its file,
          or a plain colour; it does not capture the screen.</li>
        <li>Stores its settings (whether the boost is enabled, trial start
          date, your options, recently picked colours) only on your Mac.</li>
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
        <li>Includes Google AdSense code, and ads may be served through it.
          Google and its partners may use
          cookies and similar technologies to serve and personalize ads based on
          your visits to this and other sites. You can review and control ad
          personalization at{' '}
          <a href="https://myadcenter.google.com/">Google My Ad Center</a>, and
          learn how Google uses this data in{' '}
          <a href="https://policies.google.com/technologies/partner-sites">
            Google’s partner-sites policy</a>.</li>
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
