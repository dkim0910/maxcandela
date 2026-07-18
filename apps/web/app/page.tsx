'use client';

import { useCallback, useEffect, useState } from 'react';
import NavBar from '@/components/NavBar';
import BrightnessUnlocker, {
  UnlockerState,
} from '@/components/BrightnessUnlocker';

const FEATURES = [
  {
    icon: '🖥️',
    title: 'Your whole Mac, brighter',
    text: 'The menu-bar app boosts everything — desktop, every app, every window. Not just one browser tab.',
  },
  {
    icon: '⚡',
    title: 'One click',
    text: 'A single ☀️ toggle in your menu bar. Click to unlock full brightness, click to go back. That’s the whole UI.',
  },
  {
    icon: '🎨',
    title: 'True colors',
    text: 'Color-calibrated boost that preserves your display’s ColorSync profile. Brighter — never washed out.',
  },
  {
    icon: '🌡️',
    title: 'Panel-safe by design',
    text: 'MaxCandela never exceeds the limits macOS itself enforces for HDR. Thermal protection stays fully in charge.',
  },
  {
    icon: '🔆',
    title: 'Nothing to configure',
    text: 'Follows your display’s live headroom automatically — including thermal dips and recovery. Set it, forget it.',
  },
  {
    icon: '🔒',
    title: 'Private by default',
    text: 'No screen recording, no analytics, no account. The app never sees your screen content — it only lifts it.',
  },
];

const FAQS = [
  {
    q: 'Is this safe for my display?',
    a: 'Yes. MaxCandela uses the same HDR headroom macOS itself uses for HDR video, and never exceeds the limit the OS reports. If your Mac gets hot, macOS lowers that limit and MaxCandela follows it down automatically.',
  },
  {
    q: 'Which Macs are supported?',
    a: 'Any Mac with an EDR-capable display. Best results on MacBook Pro 14″/16″ (2021 and later) with the Liquid Retina XDR display, and on the Pro Display XDR — up to ~1,000 nits sustained instead of the usual ~600.',
  },
  {
    q: 'Will it drain my battery?',
    a: 'Brightness costs power — the boost uses more battery, just like HDR video playback does. Toggle it off when you don’t need it; one click.',
  },
  {
    q: 'How does the free trial work?',
    a: 'Download free from the Mac App Store and get 7 days with everything unlocked. After that, keep it for $0.99/month or unlock it forever for $9.99. One purchase works on all Macs signed into your Apple ID.',
  },
  {
    q: 'Why doesn’t macOS just allow this?',
    a: 'macOS reserves the panel’s extra brightness for HDR content to protect battery and thermals by default. MaxCandela lets you choose when everyday content deserves the same headroom.',
  },
];

export default function Home() {
  const [enabled, setEnabled] = useState(false);
  // null = not yet detected (avoids SSR/CSR mismatch on first paint)
  const [supported, setSupported] = useState<boolean | null>(null);
  const [unlocker, setUnlocker] = useState<UnlockerState | null>(null);
  const onUnlockerState = useCallback((s: UnlockerState) => setUnlocker(s), []);

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
      ? { cls: 'status-off', text: 'Checking your display…' }
      : !supported
        ? { cls: 'status-unsupported', text: 'This display/browser has no HDR headroom — the demo needs an XDR Mac' }
        : enabled
          ? { cls: 'status-on', text: 'Boost active — this page is now brighter than macOS normally allows' }
          : { cls: 'status-off', text: 'Boost off — flip the switch in the nav bar ↗' };

  return (
    <>
      <NavBar
        enabled={enabled}
        supported={supported === true}
        onToggle={() => setEnabled((v) => !v)}
      />
      <BrightnessUnlocker enabled={enabled} onStateChange={onUnlockerState} />

      <main className="main">
        {/* ---- Hero ---- */}
        <section className="hero">
          <p className="eyebrow">For MacBook Pro XDR displays</p>
          <h1>
            Your screen can go <span className="hl">70% brighter</span>.
            <br />
            macOS just won’t let it.
          </h1>
          <p className="subtitle">
            Your XDR panel is rated for 1,000 nits — macOS caps everyday
            content at ~600. MaxCandela unlocks the difference with one click
            in your menu bar. Full brightness, true colors, zero setup.
          </p>
          <div className="cta-row">
            <a className="cta cta-primary" href="#pricing">
               Download on the Mac App Store
            </a>
            <span className="cta-note">Free · 7-day full trial</span>
          </div>
        </section>

        {/* ---- Live demo ---- */}
        <section className="demo" id="demo">
          <h2>Don’t take our word for it — feel it</h2>
          <p className="demo-copy">
            This page can boost itself the same way, right in your browser.
            Use the toggle in the nav bar, then come back and imagine your
            whole Mac like this.
          </p>
          <div className={`status ${status.cls}`} role="status">
            <span className="status-dot" aria-hidden="true" />
            {status.text}
          </div>
          {enabled && unlocker?.error && (
            <p className="diag">⚠️ {unlocker.error}</p>
          )}
          <p className="demo-fineprint">
            The web demo brightens this page only. The Mac app brightens
            everything, system-wide.
          </p>
        </section>

        {/* ---- Features ---- */}
        <section className="features" id="features">
          <h2>Built for one job, done right</h2>
          <div className="cards">
            {FEATURES.map((f) => (
              <div className="card" key={f.title}>
                <span className="card-icon" aria-hidden="true">{f.icon}</span>
                <h3>{f.title}</h3>
                <p>{f.text}</p>
              </div>
            ))}
          </div>
        </section>

        {/* ---- Pricing ---- */}
        <section className="pricing" id="pricing">
          <h2>Simple pricing</h2>
          <p className="pricing-sub">
            Free for 7 days, everything unlocked. Then pick what suits you.
          </p>
          <div className="price-cards">
            <div className="price-card">
              <h3>Monthly</h3>
              <p className="price">
                $0.99<span className="price-per">/month</span>
              </p>
              <ul>
                <li>✓ Full brightness unlock</li>
                <li>✓ All future updates</li>
                <li>✓ Cancel anytime in the App Store</li>
              </ul>
              <a className="cta cta-secondary" href="#">
                Start free trial
              </a>
            </div>
            <div className="price-card price-card-best">
              <span className="badge">Best value</span>
              <h3>Lifetime</h3>
              <p className="price">
                $9.99<span className="price-per"> once</span>
              </p>
              <ul>
                <li>✓ Full brightness unlock, forever</li>
                <li>✓ All future updates</li>
                <li>✓ Pays for itself in 11 months</li>
              </ul>
              <a className="cta cta-primary" href="#">
                Start free trial
              </a>
            </div>
          </div>
          <p className="pricing-fineprint">
            Purchases via Apple. One purchase covers every Mac on your Apple
            ID. Requires macOS 13+ and an EDR-capable display.
          </p>
        </section>

        {/* ---- FAQ ---- */}
        <section className="faq" id="faq">
          <h2>Questions, answered</h2>
          {FAQS.map((f) => (
            <details key={f.q}>
              <summary>{f.q}</summary>
              <p>{f.a}</p>
            </details>
          ))}
        </section>
      </main>

      <footer className="footer">
        MaxCandela · not affiliated with Apple Inc. · “MacBook Pro” and
        “Liquid Retina XDR” are trademarks of Apple Inc.
      </footer>
    </>
  );
}
