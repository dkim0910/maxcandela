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
  unlocker: UnlockerState | null;
  toggle: () => void;
}

const BoostContext = createContext<BoostContextValue>({
  enabled: false,
  supported: null,
  unlocker: null,
  toggle: () => {},
});

export const useBoost = () => useContext(BoostContext);

const STORAGE_KEY = 'maxcandela.boost';

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
  const [unlocker, setUnlocker] = useState<UnlockerState | null>(null);
  const onUnlockerState = useCallback((s: UnlockerState) => setUnlocker(s), []);

  useEffect(() => {
    // EDR/HDR capability check — a hint, not a headroom measurement.
    const mq = window.matchMedia('(dynamic-range: high)');
    setSupported(mq.matches);
    const onChange = (e: MediaQueryListEvent) => setSupported(e.matches);
    mq.addEventListener('change', onChange);

    // Resume the boost across full page loads within this tab.
    if (mq.matches && sessionStorage.getItem(STORAGE_KEY) === '1') {
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
    <BoostContext.Provider value={{ enabled, supported, unlocker, toggle }}>
      {/* prime on any EDR display: keeps the headroom warm so the boost
          toggle is instant instead of ramping over a second or two. */}
      <BrightnessUnlocker
        prime={supported === true}
        enabled={enabled}
        onStateChange={onUnlockerState}
      />
      {children}
    </BoostContext.Provider>
  );
}
