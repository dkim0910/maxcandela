# MaxCandela

**Unlock the full brightness of your MacBook Pro display.**

MaxCandela pushes your Mac's display past its normal SDR brightness ceiling by
lighting up the panel's unused **Extended Dynamic Range (EDR)** headroom. On
mini-LED (Liquid Retina XDR) and many external HDR displays, this can boost
usable brightness well beyond the ~500–600 nit SDR cap that macOS enforces for
ordinary content — the same headroom macOS itself only lights up for HDR video.

It ships in two forms (macOS only — no Android/Windows):

- **Native menu-bar app** (`apps/macos`) — a ☀️ toggle in your Mac's top nav
  bar. One click boosts the whole system to the panel's maximum; one click
  restores it. Free 7-day trial, then $9.99 lifetime or $0.99/month.
- **Web app** (`apps/web`) — the marketing site (features, pricing, FAQ,
  about, legal pages) with a live **Try the boost** demo that unlocks
  brightness right in Safari/Chrome, no install needed. The boost is instant
  and stays on across every page of the site.

> ⚠️ **Early / experimental.** This is a code-first project scaffold. The
> architecture is in place; the EDR compositing path is under active
> development. See [CLAUDE.md](./CLAUDE.md) for the technical plan and current
> status.

---

## How it works (the short version)

macOS caps SDR content brightness, but keeps extra backlight headroom in reserve
for HDR. Apple exposes that headroom to apps through EDR: a screen's
`maximumExtendedDynamicRangeColorComponentValue` reports how much brighter than
"SDR white" (1.0) the panel can currently go — often 1.6× to 16× on capable
displays.

**Native app:** keeps a tiny (4 px) EDR trigger window on each screen so the
display's HDR headroom stays engaged, then lifts every SDR pixel into that
headroom with a color-calibrated gamma transfer — the whole desktop gets
brighter with colors preserved, fading smoothly between levels.

**Web app:** keeps a tiny HDR white clip playing (HEVC/PQ for Safari, VP9/HLG
fallback) so the browser's HDR headroom stays warm, then composites the page
into it fullscreen with `mix-blend-mode: multiply` when boosting — the page's
own pixels are lifted into HDR range, instantly and without washing out.

Full detail, including the compositing strategy and the private-API fallbacks
we're evaluating, lives in [CLAUDE.md](./CLAUDE.md).

## Supported hardware

| Display | EDR headroom | Notes |
|---|---|---|
| MacBook Pro 14"/16" (2021+), mini-LED XDR | High (up to ~16×) | Best results |
| MacBook Air/Pro with Liquid Retina | Moderate | Boost varies by model |
| Pro Display XDR | High | |
| External HDR / HDR10 displays | Varies | Depends on the panel's reported headroom |
| Older non-HDR panels | None (1.0×) | No headroom to unlock; app runs but does nothing |

MaxCandela never exceeds the headroom the OS itself reports, so it cannot drive a
panel beyond what Apple already considers safe for HDR playback.

## Requirements

- macOS 13 (Ventura) or later
- Apple silicon or Intel Mac with an EDR-capable display
- Swift 5.9+ toolchain (Xcode 15+ or the Swift toolchain) to build

## Build & run

### Native app

```bash
cd apps/macos
swift build              # debug build
swift run MaxCandela     # build and launch the menu-bar app
swift build -c release   # optimized build
swift test               # unit tests
```

To package a distributable `.app` bundle, see `scripts/` (bundling and codesign
helpers) — TODO, tracked in CLAUDE.md.

### Web app

```bash
cd apps/web
npm install
npm run dev              # http://localhost:3000
npm run build            # static export → apps/web/out/ (host anywhere)
```

## Usage

### Native app

1. Launch MaxCandela — a ☀️ icon appears in the menu bar (your Mac's top nav bar).
2. **Click the icon** to toggle full brightness on/off instantly. The icon
   fills in (`sun.max.fill`) while boosted. The boost always targets the
   panel's maximum available headroom and follows it live (thermals, battery).
3. **Right-click** (or ⌃-click) the icon for live status ("Boosting N×"),
   trial/purchase options, and Quit.

Enabled-state persists across launches. Licensing: 7-day free trial, then
$9.99 lifetime or $0.99/month via in-app purchase.

### Web app

1. Open the site in Safari or Chrome on an XDR MacBook Pro.
2. Press the big **Try the boost** button in the demo section (also reachable
   via "Try it" in the nav bar).
3. The site instantly brightens beyond the normal SDR cap and stays boosted as
   you browse its pages; press again (or close the tab) to restore. Nothing is
   installed. The demo brightens the site's own pages only — the Mac app is
   the system-wide version.

If the button is disabled, the browser reports no EDR headroom on the current
display (`(dynamic-range: high)` media query is false).

## Safety & battery

- Boosting brightness increases backlight power draw and heat. Expect reduced
  battery life.
- **Thermal-aware:** the app reads the system thermal state and automatically
  eases the boost down as the Mac gets hot (halved at "serious", off at
  "critical"), restoring it once cool. It cannot control fans — that needs SMC
  access a sandboxed App Store app isn't permitted; easing its own boost is the
  responsible lever it does have.
- MaxCandela respects the OS-reported EDR ceiling and clamps to it; it does not
  bypass thermal protection.
- If anything looks wrong, toggling off (or quitting) returns the display to
  normal immediately — no persistent system state is changed.

## Project layout

```
maxcandela/
├── README.md                  # you are here
├── CLAUDE.md                  # technical spec, architecture, working agreements
├── LICENSE
├── apps/
│   ├── macos/                 # native menu-bar app (SwiftPM)
│   │   ├── Package.swift
│   │   ├── Sources/MaxCandela/
│   │   │   ├── main.swift             # entry point
│   │   │   ├── AppDelegate.swift      # app lifecycle
│   │   │   ├── MenuBarController.swift # ☀️ toggle + right-click menu
│   │   │   ├── BrightnessController.swift # orchestrator + fade animator
│   │   │   ├── GammaController.swift  # calibration-preserving gamma lift
│   │   │   ├── ThermalMonitor.swift   # eases boost down when the Mac is hot
│   │   │   ├── StoreManager.swift     # StoreKit 2: trial + IAP licensing
│   │   │   ├── Analytics.swift        # anonymous GA4 events (off in DEBUG)
│   │   │   ├── DisplayManager.swift   # display enumeration + EDR queries
│   │   │   ├── EDROverlayWindow.swift # tiny per-screen EDR trigger window
│   │   │   ├── MetalRenderer.swift    # CAMetalLayer EDR render loop
│   │   │   └── Preferences.swift      # persisted settings
│   │   ├── Resources/                 # Info.plist + sandbox entitlements
│   │   └── Tests/MaxCandelaTests/
│   └── web/                   # Next.js web app (static export)
│       ├── app/               # pages + sitemap.ts/robots.ts + icons
│       ├── components/        # BoostProvider (site-wide boost state),
│       │                      # BrightnessUnlocker (HDR video), NavBar,
│       │                      # LegalShell, SiteFooter, Analytics
│       ├── lib/               # site.ts (domain), analytics.ts (GA4)
│       └── public/            # og.png, brand.png, hdr/ clips
└── scripts/
    ├── generate-hdr-video.sh  # regenerates public/hdr/ clips (needs ffmpeg)
    ├── make-hero.swift        # renders og.png social/brand image
    ├── make-icon.swift        # renders the app icon / favicon
    └── bundle-macos.sh        # builds the signed .app / App Store .pkg
```

## Contributing

This is an early-stage scaffold. Start with [CLAUDE.md](./CLAUDE.md) for the
architecture and the current TODO list. Keep new code consistent with the
existing structure and matching comment style.

## License

MIT — see [LICENSE](./LICENSE).

## Disclaimer

MaxCandela is an independent project and is not affiliated with, endorsed by, or
sponsored by Apple Inc. "MacBook Pro", "Liquid Retina XDR", and "Pro Display
XDR" are trademarks of Apple Inc. Use at your own risk.
