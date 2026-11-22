# Boost coverage: which Macs the boost can reach, and how to reach more

Research note, 2026-11-22. Nothing in here is built. It exists because
BetterDisplay ships four ways to raise brightness and MaxCandela ships one,
and the Macs that one way misses are the newest MacBook Pros, which belong to
the people most likely to go looking for a brightness app.

## Where we are

MaxCandela has **one** method: an EDR trigger window plus a gamma lift through
`CGSetDisplayTransferByTable` (`GammaController`). It works wherever that call
reaches the glass. Two places it does not, or might not:

- **M5 Pro / M5 Max.** Reported broken by Apple's own DTS engineer (forum
  thread 819331, FB22273730, still open at macOS 27.2.1). The call returns
  success and reads back correctly while the screen does not change. **We
  have not reproduced it**: the dev Mac is an M1 Pro. `KnownIssues` handles it
  by telling the user once, without blocking the toggle.
- **PROLED XDR MacBook Pro.** Untested. BetterDisplay states that its "direct"
  method does not support PROLED panels; it says nothing either way about its
  colour-table method there.

**External HDR monitors already qualify in code.** `DisplayInfo.supportsBoost`
is `potentialHeadroom > 1.0` (`DisplayManager.swift`). Nothing checks for a
built-in panel, so a third-party HDR monitor that reports EDR headroom gets
a boost toggle today. Nobody has tried one. BetterDisplay notes that
third-party displays "must be in HDR mode", which suggests the headroom is
only reported while macOS has HDR switched on for that display. That is
**not verified here**.

## What BetterDisplay ships (from its guide, read 2026-11-22)

All four are Pro-only there.

| Method | What their guide says |
|---|---|
| Direct built-in XDR | "Expands hardware brightness", default range 0–1600 nits. Not on PROLED. Built-in panels only. Marked experimental. Avoids colour-table clipping of HDR content. Mechanism not documented; it controls the panel itself, which no public API we know of does. |
| Colour-table | Apple silicon. "Efficient desktop upscaling, but active color-table adjustments can clip HDR content." The same mechanism as ours. |
| Metal | "Intel, or a compatible fallback with color-table control disabled." "Uses extra processing. HDR results can differ by GPU/path." Mechanism not documented. |
| Legacy native XDR preset | "Unavailable from macOS 26.3 onward." |

They say nothing about M5 Pro / M5 Max, and nothing about heat beyond "may
add heat… use the lowest brightness that meets your needs". There is no
thermal guard, battery pause or per-app rule.

## Ways to brighten without the gamma table

### A. Capture and re-render (ScreenCaptureKit + Metal)

Capture the display with `SCStream` (our own overlay excluded through
`SCContentFilter`), multiply each frame by the gain in a Metal pass, and
present it in a fullscreen, click-through, EDR-enabled `CAMetalLayer` above
everything else. This is the escalation path `CLAUDE.md` already names, and
the most likely shape of anything called a "Metal" method.

Costs, each of which needs measuring before this ships:

- **Screen Recording permission.** We already ask for it for Copy Text from
  Screen, so it isn't a new permission to explain to App Review. It is a scary
  prompt for a brightness feature, though.
- **GPU and battery.** A full-resolution capture (3456×2234 on a 16″) at the
  panel's refresh rate, plus a render pass, every frame the boost is on. That
  adds heat on the same machine whose heat we are trying to manage, so
  `ThermalMonitor` would need to count it.
- **Latency.** Content shows at least one frame late. The cursor is drawn by
  hardware above our window and would not lag. Scrolling and video would.
- **Protected video.** FairPlay content is expected to capture as black, which
  would turn a Netflix window black under the overlay. That is a deal-breaker
  unless it can be detected. **Unverified; test first.**
- **Input.** The overlay must ignore mouse events and must not take focus.
  `EDROverlayWindow` already solves this for a 4×4 window.

### B. Blending a window over other apps' windows

The web app brightens with `mix-blend-mode: multiply`, but that only blends
inside one page. A macOS window cannot multiply over other processes' windows
through any public API we know of, because the window server composites
windows only with normal alpha blending. The private window-server calls that
can do it are ruled out on the App Store.

### C. Driving the backlight directly

`DisplayServices` / `CoreDisplay` are private. `CLAUDE.md` rules them out for
the App Store build. This is probably what BetterDisplay's "direct" method is,
and it is one reason they don't sell through the App Store.

## Recommended order

1. **Test on an external HDR monitor.** It is cheap, and it may already work.
   If it does, the support copy (`SupportMessages`, the site's "Which Macs"
   FAQ, the listing's WHICH MACS section) should say so. If it only works with
   HDR switched on in System Settings ▸ Displays, the no-headroom alert should
   say that as well.
2. **Confirm the M5 Pro / M5 Max bug ourselves** on a real machine (an Apple
   Store demo unit is enough: run the bundled `dist/MaxCandela.app`) and on
   the newest macOS. If Apple has fixed FB22273730, delete `KnownIssues` and
   recover those buyers for free.
3. **Only if it is still broken:** prototype A as an opt-in "compatibility
   mode", offered only on the chips `KnownIssues` names, behind a DEBUG flag
   first. Prototype it on the M1 Pro with the gamma lift switched off. Measure
   GPU load, the heat it adds and the protected-video behaviour before it gets
   anywhere near a release.
