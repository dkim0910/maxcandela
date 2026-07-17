# CLAUDE.md — MaxCandela

Guidance for Claude Code (and humans) working in this repository.

## What this project is

MaxCandela is a macOS menu-bar app, written in Swift with AppKit + Metal, that
raises a Mac display's usable brightness beyond the SDR ceiling by rendering
into the display's **Extended Dynamic Range (EDR)** headroom. Think Vivid /
BetterDisplay's brightness-boost feature, built from scratch.

It is a native app distributed as a `.app` bundle. Build system is **Swift
Package Manager** (no `.xcodeproj` checked in — SwiftPM drives everything).

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

### The boost mechanism

The effect we want is "make everything on screen brighter," not "put a bright
white rectangle on screen." Two candidate strategies:

1. **Transparent EDR headroom primer (MVP).** A full-screen, click-through,
   transparent overlay whose `CAMetalLayer` is filled with EDR white at the
   target multiplier, at a low alpha. Presenting EDR content anywhere on screen
   causes macOS to raise the backlight; SDR content underneath then appears
   brighter relative to the (now higher) backlight. Simple, no screen capture,
   but tone-mapping/perceptual results are approximate and can wash out.
   **This is where we start.**

2. **Capture-and-remap (v2).** Use `ScreenCaptureKit` to sample the framebuffer,
   re-render it multiplied into EDR range, and present that. Accurate, but heavy:
   needs Screen Recording permission, more GPU, and careful latency handling.

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

## Architecture

```
main.swift            → NSApplication bootstrap, .accessory activation policy
AppDelegate           → lifecycle; owns MenuBarController + BrightnessController
MenuBarController      → NSStatusItem, menu, boost slider, enable toggle
BrightnessController   → orchestrator: one EDROverlayWindow per active NSScreen;
                         reacts to screen-config + EDR-headroom changes; clamps
DisplayManager         → enumerates NSScreens, reports EDR capability per screen,
                         observes NSApplication.didChangeScreenParametersNotification
EDROverlayWindow       → borderless, transparent, click-through NSWindow per
                         screen; hosts the CAMetalLayer; ignoresMouseEvents
MetalRenderer          → owns MTLDevice/queue; drives the CAMetalLayer render
                         loop (CVDisplayLink); clears drawable to EDR white ×boost
Preferences            → UserDefaults-backed enabled flag + boost level
```

Data flow: slider → `BrightnessController.setBoost(_:)` → clamp against
`DisplayManager` headroom → each `EDROverlayWindow.renderer.boost = clamped`.

## Build / run / test

```bash
swift build                 # debug
swift run MaxCandela        # launch the menu-bar app
swift build -c release      # release
swift test                  # unit tests
```

There is no CI yet. When adding it, run `swift build` and `swift test` on
macOS-latest.

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
- [ ] MVP EDR primer overlay renders and visibly boosts on XDR hardware.
- [ ] Live clamp against dynamic headroom + KVO on the headroom value.
- [ ] Multi-display: create/tear down overlays on screen (dis)connect.
- [ ] Menu-bar slider wired to persisted `Preferences`.
- [ ] Graceful behavior on non-EDR displays (disable, explain in menu).
- [ ] `scripts/`: `.app` bundling, codesign, notarization helpers.
- [ ] Icon assets + Info.plist (`LSUIElement = true`).
- [ ] Evaluate capture-and-remap (v2) vs. primer quality.

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
