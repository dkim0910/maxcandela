'use client';

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useState,
} from 'react';
import BrightnessUnlocker, { UnlockerState } from './BrightnessUnlocker';
import { trackEvent } from '@/lib/analytics';

interface BoostContextValue {
  enabled: boolean;
  /// null = capability not yet detected (first client paint)
  supported: boolean | null;
  /// null until detected. The demo is offered on macOS only — see isMacPlatform.
  isMac: boolean | null;
  unlocker: UnlockerState | null;
  toggle: () => void;
}

const BoostContext = createContext<BoostContextValue>({
  enabled: false,
  supported: null,
  isMac: null,
  unlocker: null,
  toggle: () => {},
});

export const useBoost = () => useContext(BoostContext);

const STORAGE_KEY = 'maxcandela.boost';

/**
 * Is this a Mac?
 *
 * `(dynamic-range: high)` alone is not enough to decide whether to offer the
 * demo: it matches on iPhone 12+ and on plenty of HDR Android phones, so the
 * boost toggle used to light up on a phone — for a macOS-only product whose
 * FAQ calls the demo "an honest test" of whether the app will work. It would
 * have brightened their phone and sold them nothing.
 *
 * `userAgentData.platform` is the modern signal (Chrome/Edge). Safari has no
 * such API, so fall back to the deprecated `navigator.platform`, and guard
 * against iPadOS — which reports "MacIntel" in desktop mode — by requiring
 * zero touch points, something no iPad reports and every Mac does.
 */
function isMacPlatform(): boolean {
  const uaData = (navigator as Navigator & { userAgentData?: { platform?: string } })
    .userAgentData;
  if (uaData?.platform) return uaData.platform === 'macOS';
  return /Mac/.test(navigator.platform) && navigator.maxTouchPoints === 0;
}

/**
 * Site-wide boost state. Lives in the root layout so the EDR video overlay
 * covers every page, the toggle state survives client-side navigation, and —
 * via sessionStorage — full page loads too (the clip is muted, so browsers
 * allow it to resume without a fresh user gesture).
 */
export default function BoostProvider({
  children,
}: {
  children: React.ReactNode;
}) {
  const [enabled, setEnabled] = useState(false);
  const [supported, setSupported] = useState<boolean | null>(null);
  const [isMac, setIsMac] = useState<boolean | null>(null);
  const [unlocker, setUnlocker] = useState<UnlockerState | null>(null);
  const onUnlockerState = useCallback((s: UnlockerState) => setUnlocker(s), []);

  useEffect(() => {
    // EDR/HDR capability check — a hint, not a headroom measurement.
    const mq = window.matchMedia('(dynamic-range: high)');
    const mac = isMacPlatform();
    setSupported(mq.matches);
    setIsMac(mac);
    const onChange = (e: MediaQueryListEvent) => setSupported(e.matches);
    mq.addEventListener('change', onChange);

    // Resume the boost across full page loads within this tab.
    if (mac && mq.matches && sessionStorage.getItem(STORAGE_KEY) === '1') {
      setEnabled(true);
    }
    return () => mq.removeEventListener('change', onChange);
  }, []);

  const toggle = useCallback(() => {
    setEnabled((v) => {
      const next = !v;
      try {
        sessionStorage.setItem(STORAGE_KEY, next ? '1' : '0');
      } catch {
        // Private-mode storage restrictions — boost still works this page.
      }
      trackEvent(next ? 'boost_enabled' : 'boost_disabled');
      return next;
    });
  }, []);

  return (
    <BoostContext.Provider value={{ enabled, supported, isMac, unlocker, toggle }}>
      {/* Prime on an EDR-capable Mac: keeps the headroom warm so the boost
          toggle is instant instead of ramping over a second or two. Priming
          plays HDR video continuously, so it stays off anywhere the demo is
          not offered — no point spending a phone's battery on it. */}
      {children}
      {/* Rendered after children (it's position:fixed, so DOM order doesn't
          affect its placement) — keeps Next's scroll target off this fixed
          element, avoiding the "Skipping auto-scroll" console warning. */}
      <BrightnessUnlocker
        prime={supported === true && isMac === true}
        enabled={enabled}
        onStateChange={onUnlockerState}
      />
    </BoostContext.Provider>
  );
}
