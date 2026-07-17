'use client';

import { useEffect, useState } from 'react';
import NavBar from '@/components/NavBar';
import BrightnessUnlocker from '@/components/BrightnessUnlocker';

export default function Home() {
  const [enabled, setEnabled] = useState(false);
  // null = not yet detected (avoids SSR/CSR mismatch on first paint)
  const [supported, setSupported] = useState<boolean | null>(null);

  useEffect(() => {
    // EDR/HDR capability check. `dynamic-range: high` is true on XDR MacBook
    // Pro panels in Safari and Chrome. It's a capability hint, not a headroom
    // measurement — the actual boost still depends on current conditions.
    const mq = window.matchMedia('(dynamic-range: high)');
    setSupported(mq.matches);
    const onChange = (e: MediaQueryListEvent) => setSupported(e.matches);
    mq.addEventListener('change', onChange);
    return () => mq.removeEventListener('change', onChange);
  }, []);

  const status =
    supported === null
      ? { cls: 'status-off', text: 'Checking display…' }
      : !supported
        ? { cls: 'status-unsupported', text: 'No EDR headroom available on this display/browser' }
        : enabled
          ? { cls: 'status-on', text: 'Boost active — HDR headroom unlocked' }
          : { cls: 'status-off', text: 'Boost off — normal brightness' };

  return (
    <>
      <NavBar
        enabled={enabled}
        supported={supported === true}
        onToggle={() => setEnabled((v) => !v)}
      />
      <BrightnessUnlocker enabled={enabled} />

      <main className="main">
        <section className="hero">
          <h1>Unlock your MacBook Pro’s full brightness</h1>
          <p className="subtitle">
            Your XDR display can go far brighter than macOS lets ordinary
            content shine. Flip the toggle in the nav bar and light up the HDR
            headroom — no install, no permissions.
          </p>
          <div className={`status ${status.cls}`} role="status">
            <span className="status-dot" aria-hidden="true" />
            {status.text}
          </div>
        </section>

        <section className="cards">
          <div className="card">
            <h2>How it works</h2>
            <p>
              macOS caps standard (SDR) content at roughly 500–600 nits but
              reserves extra backlight headroom for HDR video. This page plays a
              tiny HDR clip, which tells the browser to raise the backlight —
              brightening everything on screen. Toggling off pauses the clip and
              restores normal brightness instantly.
            </p>
          </div>
          <div className="card">
            <h2>Compatibility</h2>
            <ul>
              <li>✅ MacBook Pro 14″/16″ (2021+) with Liquid Retina XDR</li>
              <li>✅ Pro Display XDR &amp; other EDR-capable displays</li>
              <li>✅ Safari and Chrome on macOS</li>
              <li>❌ Displays without HDR headroom (toggle stays disabled)</li>
            </ul>
          </div>
          <div className="card">
            <h2>Good to know</h2>
            <ul>
              <li>Higher brightness uses more battery and generates heat.</li>
              <li>
                macOS may ease the boost down under thermal load or on low
                battery — that’s the OS protecting the panel, not a bug.
              </li>
              <li>
                Closing this tab or toggling off returns everything to normal.
                Nothing is installed or persisted.
              </li>
              <li>
                Want a system-wide version? The native macOS menu-bar app in
                this project boosts every app, not just the browser.
              </li>
            </ul>
          </div>
        </section>
      </main>

      <footer className="footer">
        MaxCandela · not affiliated with Apple Inc. · MIT licensed
      </footer>
    </>
  );
}
