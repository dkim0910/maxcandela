# CLAUDE.md — MaxCandela

Guidance for Claude Code (and humans) working in this repository.

## Working agreements

- **Do not commit.** The maintainer commits personally; Claude prepares changes
  and verifies builds/tests, then stops. (Standing instruction from 2026-07-18.)

## What this project is

MaxCandela raises a Mac display's usable brightness beyond the SDR ceiling by
lighting up the display's **Extended Dynamic Range (EDR)** headroom. Think
Vivid / BetterDisplay's brightness-boost feature, built from scratch. macOS
only — the target hardware is MacBook Pros with XDR panels. No Android/Windows.

It's a monorepo with two apps:

- **`apps/macos/`** — native menu-bar app, Swift + AppKit + Metal. Build system
  is **Swift Package Manager** (no `.xcodeproj` — SwiftPM drives everything).
  Left-clicking the ☀️ status icon toggles full brightness on/off; right-click
  opens a menu with live status, license/purchase items, and Quit. There is
  deliberately **no boost slider** (removed 2026-07 — toggle always targets the
  panel's max headroom; a manual level didn't add value and confused testing).
- **`apps/web/`** — Next.js 15 (App Router, TypeScript, static export) site
  with a brightness toggle in its top nav bar. Unlocks brightness inside the
  browser via the HDR-video trick (see below).

Shared tooling lives in `scripts/`.

## Business model / App Store

Free download on the Mac App Store, 7-day full trial, then in-app purchase:

- `com.maxcandela.pro.lifetime` — non-consumable, **$9.99**
- `com.maxcandela.pro.monthly` — auto-renewable subscription, **$0.99/month**

Purchases are per-Apple-ID (App Store rule — per-device licensing is not
possible on MAS; marketed as "one purchase, all your Macs"). `StoreManager`
implements StoreKit 2 entitlement checks + purchases; the trial clock is
first-launch date in UserDefaults (v1 — receipt original-purchase-date is the
robust upgrade, see TODO). The paywall gates *turning the boost on*; turning it
OFF and quitting are never gated (kill-switch invariant).

DEBUG builds bypass the paywall so `swift run` stays usable; set
`MAXCANDELA_FORCE_PAYWALL=1` to test paywall flows in debug.

Packaging: `scripts/bundle-macos.sh` builds a universal release binary,
generates the icon (`scripts/make-icon.swift`), assembles `dist/MaxCandela.app`
with `Resources/Info.plist` (LSUIElement) + sandbox entitlements, codesigns
(ad-hoc by default; `SIGN_IDENTITY`/`INSTALLER_IDENTITY` + `--pkg` for App
Store upload). App Store Connect steps are listed at the top of that script.

## Core technical concept — read this before touching brightness code

macOS enforces a brightness cap on **SDR** (standard dynamic range) content —
typically ~500–600 nits — but keeps additional backlight headroom in reserve for
**HDR** content. Apple exposes that headroom to apps via EDR.

Key API surface:

- `NSScreen.maximumExtendedDynamicRangeColorComponentValue` — the *current* EDR
  headroom as a multiple of SDR white (1.0). E.g. 2.0 means the panel can render
  "white" twice as bright as SDR white right now. **This value is dynamic** — it
  changes with ambient light, battery state, thermal state, and current
  brightness. Poll/observe it; never cache it.
- `NSScreen.maximumPotentialExtendedDynamicRangeColorComponentValue` — the
  theoretical max headroom regardless of current conditions. Use for UI ("this
  display supports up to N×"), not for clamping live output.
- `CAMetalLayer.wantsExtendedDynamicRangeContent = true` — opts a layer into EDR.
- `CAMetalLayer.pixelFormat = .rgba16Float` — EDR requires a float pixel format.
- `CAMetalLayer.colorspace = CGColorSpace(name: .extendedLinearDisplayP3)` (or
  `.extendedLinearSRGB` / `.extendedLinearITUR_2020`) — an *extended* linear
  colorspace lets component values exceed 1.0.
- Rendering values `> 1.0` into that layer drives the backlight above the SDR
  cap. Value `1.0` == SDR white; `headroom` == the brightest the panel will go
  right now.

### The boost mechanism (implemented: trigger + gamma lift)

The effect we want is "make everything on screen brighter," not "put a bright
white rectangle on screen." Key OS behavior (verified on hardware via the web
app, 2026-07): **macOS compensates SDR pixels downward while EDR content is
displayed** — EDR presence alone raises the backlight but nothing visibly
brightens. So the implemented approach is two-part (the Lunar/Vivid "XDR
brightness" technique):

1. **EDR trigger** — a tiny (~4×4 px) click-through window in the corner of
   each boosted screen (`EDROverlayWindow`) rendering EDR white at the current
   headroom, which keeps the compositor in EDR mode with headroom engaged.
2. **Gamma lift** — `GammaController` scales every SDR pixel up into that
   headroom via display transfer tables (`CGSetDisplayTransferByTable`, formula
   fallback). **Hardware-verified 2026-07: macOS honors table values > 1.0**
   (screen visibly brightened). Two rules keep colors intact, both learned the
   hard way on hardware:
   - Tables hold *gamma-encoded* values: a luminance multiply of S needs an
     encoded gain of S^(1/2.2). Multiplying encoded values by S directly
     over-drives luminance by S^2.2 → channel clipping → washed-out color.
   - Never replace the calibration: read the display's current ColorSync
     tables once (cache before first lift; re-reading after would compound)
     and scale those, preserving per-channel curve shapes.

Safety facts: CG gamma changes are **per-process and auto-restore on process
exit** (crash-safe), and `CGDisplayRestoreColorSyncSettings()` is the explicit
restore used on disable/quit.

**Escalation path if both gamma experiments clamp at 1.0 on hardware:**
capture-and-remap — use `ScreenCaptureKit` to sample the framebuffer, re-render
it multiplied into EDR range, and present that. Accurate, but heavy: needs
Screen Recording permission, more GPU, and careful latency handling. Not built;
gated on the gamma finding.

Private-API fallback (evaluate only if EDR proves insufficient on some panels):
`DisplayServices` / `CoreDisplay` (`DisplayServicesSetBrightness`,
`CoreDisplay_Display_SetUserBrightness`). These control *native* brightness, not
above-cap boost, and are private — prefer the public EDR path. Do not ship
private APIs without a clearly documented reason here.

### Non-negotiable safety rules

- **Always clamp the live boost to the current `maximum…ColorComponentValue`.**
  Never render above the OS-reported *current* headroom — that's the OS's
  thermal/power ceiling. Re-clamp whenever the value changes.
- Provide an instant kill path: disabling the app must tear down overlays and
  restore native brightness immediately. We change no persistent system state,
  so "quit == back to normal" must always hold.
- Never bypass thermal throttling. If the OS lowers headroom, follow it down.

## Web app technique (apps/web)

**Critical fact (verified on hardware 2026-07): when HDR content is on screen,
macOS raises the backlight but simultaneously compensates SDR pixels downward,
so SDR content keeps the same apparent brightness.** A hidden HDR video
therefore does *nothing visible* — we tried it first and it failed. Any boost
strategy must lift the target pixels themselves into EDR range, not just wake
the backlight.

The working approach: a **fullscreen EDR-white video** covering the viewport
with `mix-blend-mode: multiply` and `pointer-events: none`. Multiply gives
`page × EDR-white(>1.0)` — the page's own pixels are scaled into HDR headroom
and genuinely brighten. Scope: only the browser window; a web page cannot
brighten other apps (that's the native app's job).

Rules that make this work:

- The `<video>` must be visible while boosting (it's hidden with
  `display:none` only when the boost is off).
- Two encodings are needed: **HEVC 10-bit PQ** (`hvc1`, BT.2020/SMPTE-2084) for
  Safari and **VP9 10-bit HLG** (BT.2020/arib-std-b67) for Chrome/Firefox. Both
  live in `apps/web/public/hdr/` and are committed.
- Regenerate them with `scripts/generate-hdr-video.sh` (needs ffmpeg). Gotcha:
  libvpx only writes the WebM Colour element if the *input frames* carry the
  metadata — hence the `setparams` filter in the script. Verify with
  `ffprobe -show_entries stream=color_transfer` after any change.
- Capability detection is `matchMedia('(dynamic-range: high)')` — a capability
  hint only, not a live headroom value.
- `video.play()` must be triggered from a user gesture (the nav-bar toggle) or
  autoplay policy may reject it.

Structure: `app/page.tsx` owns toggle state + detection; `components/NavBar.tsx`
is the presentation-only nav bar with the toggle button;
`components/BrightnessUnlocker.tsx` owns the hidden video element.

## Native app architecture (apps/macos)

```
main.swift            → NSApplication bootstrap, .accessory activation policy
AppDelegate           → lifecycle; owns MenuBarController + BrightnessController
MenuBarController      → NSStatusItem; left-click = instant toggle (gated by
                         license), right-click menu w/ live "Boosting N×" line,
                         purchase/restore items, Quit. No slider.
BrightnessController   → orchestrator: tiny EDR trigger per boost-capable
                         screen; 1 s headroom poll; gamma lift fades via 30 Hz
                         animator; toggle-on targets max headroom
GammaController        → per-display SDR→EDR lift via transfer tables
                         (table w/ >1.0 values, formula fallback); restoreAll()
DisplayManager         → enumerates NSScreens, reports EDR capability per screen,
                         observes NSApplication.didChangeScreenParametersNotification
EDROverlayWindow       → ~4×4 px borderless click-through corner window per
                         screen; hosts the CAMetalLayer EDR trigger patch
MetalRenderer          → owns MTLDevice/queue; drives the CAMetalLayer render
                         loop (CVDisplayLink); clears drawable to EDR white ×boost
Preferences            → UserDefaults-backed enabled flag + boost level
```

Data flow: toggle → `BrightnessController` → per-tick
`targetScale(requested, currentHeadroom)` → trigger renderer boost + gamma
lift (faded by the animator) per display.

Also removed 2026-07: the web app's three-level boost selector (single
1000-nit clip with codec detection remains; the 700/1600-nit clips still exist
in `public/hdr/` and the generator script if ever needed again).

## Build / run / test

```bash
# macOS app (from apps/macos/)
swift build                 # debug
swift run MaxCandela        # launch the menu-bar app
swift build -c release      # release
swift test                  # unit tests

# Web app (from apps/web/)
npm install
npm run dev                 # http://localhost:3000
npm run build               # static export → apps/web/out/
```

There is no CI yet. When adding it, run `swift build`/`swift test` (in
`apps/macos`) and `npm run build` (in `apps/web`) on macOS-latest.

### Verifying a brightness change actually works

Unit tests can't observe backlight. To verify boost behavior you must run the
app on real EDR-capable hardware and watch the display. When testing EDR output,
log `NSScreen.maximumExtendedDynamicRangeColorComponentValue` before/after and
confirm the clamp holds. A perceptual check (does the screen visibly brighten,
does disabling instantly restore it) is required before claiming it works.

## Conventions

- Swift 5.9, macOS 13+ deployment target. Prefer public frameworks (AppKit,
  Metal, QuartzCore, CoreGraphics). Flag any private API in this file first.
- AppKit, not SwiftUI, for the menu-bar surface (finer control over
  status-item/overlay window behavior). Overlay windows are `NSWindow`, not
  SwiftUI scenes.
- Activation policy is `.accessory` (menu-bar only, no Dock icon).
- Match the existing file structure and comment density. One responsibility per
  file. Keep the kill-switch invariant intact in any change to the overlay path.
- No force-unwraps on `MTLCreateSystemDefaultDevice()` in shipping paths — a Mac
  can lack a usable Metal device; degrade gracefully.

## Current status / TODO

- [x] Project scaffold: SwiftPM manifest, docs, source skeleton, tests.
- [x] Monorepo layout: `apps/macos` + `apps/web` + `scripts/`.
- [x] Menu-bar icon = instant toggle (left-click); right-click menu w/ slider.
- [x] Web app: Next.js static export, nav-bar toggle, HDR video assets
      (`scripts/generate-hdr-video.sh`), `dynamic-range` detection.
- [x] Web boost verified on hardware (fullscreen multiply-blend; 3 nit levels).
- [x] Native trigger + gamma lift implemented; live 1 s headroom poll/clamp.
- [x] Native gamma lift verified on hardware — table path with >1.0 values
      works. Color washout fixed via encoded-gain math + calibration-preserving
      tables (see boost mechanism section).
- [ ] Re-verify color fidelity on hardware after the encoded-gain fix.
- [x] StoreKit 2 paywall: 7-day trial, $9.99 lifetime / $0.99 monthly IAP,
      restore purchases, transaction listener; off/quit never gated.
- [x] Packaging: Info.plist, sandbox entitlements, generated icon,
      `bundle-macos.sh` (.app verified locally with ad-hoc signing; --pkg for
      App Store).
- [x] Web: marketing page (hero, live demo, features, pricing, FAQ).
- [ ] Verify gamma/EDR APIs work inside the **sandboxed** build before
      submission (sandbox may behave differently than swift run).
- [ ] App Store Connect setup: app record, both IAP products, screenshots,
      privacy labels ("data not collected").
- [ ] Trial clock hardening: use receipt original-purchase-date instead of
      UserDefaults first-launch.
- [ ] Real App Store badge asset + store URL on the web page (CTAs are
      placeholders until the app is live).
- [ ] Graceful behavior on non-EDR displays (disable, explain in menu).
- [ ] Web deployment (static host of user's choice; `out/` is ready as-is).

Keep this list current as work lands.

## Gotchas

- EDR headroom is **dynamic**. Code that samples it once and caches will clamp
  wrong. Observe it.
- EDR requires a float pixel format (`.rgba16Float`) *and* an extended-linear
  colorspace. Miss either and values >1.0 just clip to white with no boost.
- Overlay windows must be click-through (`ignoresMouseEvents = true`), high
  window level, and joined to all Spaces, or they'll steal input / vanish in
  fullscreen.
- SwiftPM executable targets can build AppKit apps, but a bare binary isn't a
  bundle — some behaviors (LSUIElement, icon) need the `.app` wrapper. That's
  why bundling scripts are on the list.
