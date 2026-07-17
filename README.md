# MaxCandela

**Unlock the full brightness of your MacBook Pro display.**

MaxCandela is a lightweight macOS menu-bar utility that pushes your Mac's display
past its normal SDR brightness ceiling by rendering into the panel's unused
**Extended Dynamic Range (EDR)** headroom. On mini-LED (Liquid Retina XDR) and
many external HDR displays, this can boost usable brightness well beyond the
~500–600 nit SDR cap that macOS enforces for ordinary content — the same
headroom macOS itself only lights up for HDR video.

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

MaxCandela places a transparent, click-through overlay window over each screen
backed by a `CAMetalLayer` with `wantsExtendedDynamicRangeContent = true`.
Rendering into that layer at values above 1.0 signals macOS to drive the
backlight higher, raising the effective brightness of everything on screen. A
menu-bar slider maps to a boost multiplier between 1.0 (off) and the display's
reported EDR maximum.

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

```bash
# From the repo root
swift build              # debug build
swift run MaxCandela     # build and launch the menu-bar app
swift build -c release   # optimized build
```

The app appears as a sun icon in the menu bar. Click it for the brightness
slider and per-display controls.

To package a distributable `.app` bundle, see `scripts/` (bundling and codesign
helpers) — TODO, tracked in CLAUDE.md.

## Usage

1. Launch MaxCandela — a ☀️ icon appears in the menu bar.
2. Open the menu and drag the **Boost** slider.
3. `1.0×` is a no-op (native brightness). Higher values light up EDR headroom.
4. Toggle **Enabled** to instantly return to native brightness.

Boost level and enabled-state persist across launches.

## Safety & battery

- Boosting brightness increases backlight power draw and heat. Expect reduced
  battery life and, on sustained high boost, thermal throttling of the backlight
  by the OS.
- MaxCandela respects the OS-reported EDR ceiling and clamps to it; it does not
  bypass thermal protection.
- If anything looks wrong, toggling **Enabled** off (or quitting) returns the
  display to normal immediately — no persistent system state is changed.

## Project layout

```
maxcandela/
├── Package.swift              # SwiftPM manifest (executable + tests)
├── README.md                  # you are here
├── CLAUDE.md                  # technical spec, architecture, working agreements
├── LICENSE
├── Sources/MaxCandela/
│   ├── main.swift             # entry point
│   ├── AppDelegate.swift      # app lifecycle, menu-bar setup
│   ├── MenuBarController.swift # status item + menu + slider
│   ├── BrightnessController.swift # orchestrates overlays across displays
│   ├── DisplayManager.swift   # display enumeration + EDR capability queries
│   ├── EDROverlayWindow.swift # per-screen EDR overlay window
│   ├── MetalRenderer.swift    # CAMetalLayer EDR render loop
│   └── Preferences.swift      # persisted settings
└── Tests/MaxCandelaTests/
    └── DisplayManagerTests.swift
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
