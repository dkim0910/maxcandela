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
  Single-clicking the ☀️ status icon toggles full brightness; double-click or
  right-click opens the menu (status, purchases, Legal ▸ Get Support, Quit).
  On a display with no EDR headroom a single click opens the menu instead —
  App Review rejected a build where the menu was right-click-only and the
  reviewer's MacBook Air hit a dead end (2026-07-20; see
  `docs/app-review-reply.md`). There is
  deliberately **no boost slider** (removed 2026-07 — toggle always targets the
  panel's max headroom; a manual level didn't add value and confused testing).
- **`apps/web/`** — Next.js 16 (App Router, TypeScript, static export) site
  with a brightness toggle in its top nav bar. Unlocks brightness inside the
  browser via the HDR-video trick (see below).

Shared tooling lives in `scripts/`.

## Business model / App Store

Free download on the Mac App Store, 5-day full trial, then in-app purchase:

- `com.maxcandela.pro.lifetime` — non-consumable, **$9.99**
- `com.maxcandela.pro.monthly` — auto-renewable subscription, **$0.99/month**

Purchases are per-Apple-ID (App Store rule — per-device licensing is not
possible on MAS; marketed as "one purchase, all your Macs"). `StoreManager`
implements StoreKit 2 entitlement checks + purchases; the trial clock uses the
App Store receipt's original purchase date (`AppTransaction.shared`,
tamper-proof) and falls back to the UserDefaults first-launch date when no
receipt is present (dev builds). The paywall gates *turning the boost on*;
turning it OFF and quitting are never gated (kill-switch invariant). On a
display with no EDR headroom, clicking the icon shows a "no boost available"
explanation instead of a fake on-state.

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

### Thermal handling (no fan control — it's impossible here)

The boost is a heat source. The app **cannot control fans**: SMC access needs
root or a privileged kernel helper, which the App Store sandbox forbids (apps
like Macs Fan Control ship outside the App Store for this reason). Shedding our
own heat is the only lever, and `ThermalMonitor` decides how much to shed.

**Why it is not `ProcessInfo.thermalState` (measured 2026-07-27).** That
property tracks *SoC* pressure and the boost's heat lands in the panel. On an
M1 Pro 16": `pmset -g therm` → "No thermal warning level has been recorded",
seven days of `thermalmonitord` logs → zero level transitions, live state
`.nominal` throughout a verified 4.0× boost. The original ladder hung off it
alone was **unreachable in the exact scenario it existed for**. Two more dead
ends, both measured, so don't re-litigate them: there is no panel thermometer
in the sandbox (`AppleCLCD2` has only a boot-time `InitialPanelTemperature`,
`PDCGlobalTemp` = 0), and live EDR headroom does *not* decay with panel heat
(pinned at 4.000 for 28 min).

So heat is judged on three axes, **lowest ceiling wins**:

- **`exposure`** (0…1) — the panel-heat estimate, and the only axis that
  responds to the heat the boost itself makes. It *relaxes* toward how hard the
  backlight is currently driven (`advanceExposure`, Newton's law, exponential
  so any tick length is exact). The response is **proportional**:
  `exposureCeiling` slides the ceiling from full at `easeAboveExposure` (0.5) to
  zero at `protectAboveExposure` (0.85).
- **`ChassisTemperature`** — battery sensor via IORegistry (public API, verified
  readable under the shipping entitlements). Real degrees, but **blind to
  display-only heat**: 20 min at 4.0× moved it 30.23 → 30.22 °C. It is there to
  catch a genuinely hot *machine*, not a hot screen. Hysteresis via
  `recoveryMarginC`; `nil` on desktop Macs silences this axis only.
- **`ProcessInfo.thermalState`** — kept for the case where something *else* is
  cooking the SoC while we add to it.

**The ceiling must be proportional, not stepped — do not "simplify" this back.**
A stepped ceiling over a linear heat integrator was built first and **pulsed on
hardware**: cut out → cool → return at half → climb → cut out, every ~25 min at
shipping constants. At the eased level the panel still accumulates heat, so any
fixed step re-reaches the cut-out threshold forever. Sliding the ceiling makes
driving harder always cost headroom, so the loop settles wherever supply meets
demand. Verified on hardware at an accelerated time constant: full 4.00× held,
then ceiling 1.00 → 0.95 → … → 0.67, settling at gamma gain **1.6196** (model
predicted 1.620) and dead steady for 3 min, with **zero** cut-outs.
`testClosedLoopSettlesInsteadOfPulsing` is the regression guard.

- `Limits{boostCeiling, dimTo, engagesEDR}`. `boostCeiling` scales only the
  boost above native. **`engagesEDR: false` is what actually sheds heat** — the
  trigger windows come down so the panel leaves HDR mode. A gamma dim alone
  leaves the compositor in EDR with the backlight budget open, so the screen
  only *looks* dimmer while it keeps heating. (That was a real bug: the ceiling
  reached the gamma lift but never the trigger.) Ordering matters — the gamma
  fade must land **before** the triggers drop, or headroom collapses under
  lifted pixels and clips them to white.
- `dimTo` caps *below* native and is set **only** by the OS's own `.critical`;
  our own heat ladder stops at "boost off". `targetScale(requested:
  currentHeadroom:thermalCeiling:dimTo:)` folds it in and the 30 Hz animator
  fades it.
- `thermalStateDidChangeNotification` triggers immediate re-eval. It is posted
  **on the global dispatch queue** (NSProcessInfo.h), so the callback hops to
  main — the controller touches NSScreen and main-thread-only state.
- Menu via `thermalStatus` (.normal/.eased/.paused/.dimmed).
- Tuning dials live together under "Panel-exposure model" in `ThermalMonitor`.
- DEBUG: `MAXCANDELA_FORCE_THERMAL=serious|critical|fair|nominal`,
  `MAXCANDELA_FORCE_TEMP=43.5` force each axis. For the exposure axis, shrink
  `thermalTimeConstantMinutes` temporarily — that is how the runs above were
  done.

**Future direction (not built):** a *non-sandboxed direct-download* build could
add real fan control via a privileged helper (`SMAppService`/`SMJobBless`, runs
as root, Developer ID + notarized, no SIP change with the clean API). That's a
separate product from the App Store build — different distribution, and it must
never drive fans *below* what macOS requests.

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

- **Priming for an instant toggle**: on any EDR-capable display the clip plays
  *continuously* at 2×2 px in a corner (never `display:none` while priming — a
  hidden video drops out of the HDR pipeline). macOS's 1–2 s headroom ramp
  happens once at page load (invisible thanks to SDR compensation); the boost
  toggle is then a pure style swap (tiny corner ↔ fullscreen multiply), so
  brightness changes instantly. Trade-off: EDR mode stays engaged while the
  site is open.
- **Site-wide boost**: state + the video element live in
  `components/BoostProvider.tsx`, mounted in the root layout. All internal
  navigation MUST use `next/link` — a plain `<a>` triggers a full page load,
  unmounting the video and visibly blinking the boost off/on. sessionStorage
  (`maxcandela.boost`) restores the boost after hard reloads (muted video may
  resume without a gesture).
- **No glows in the CSS**: no `box-shadow` halos or `radial-gradient` washes —
  under the boost they multiply into EDR and read as light bleed ("blooming").
  Hard-edged gradients inside elements are fine.
- Two encodings are needed: **HEVC 10-bit PQ** (`hvc1`, BT.2020/SMPTE-2084,
  white pinned at ~1000 nits) for Safari/Chrome-with-HEVC and **VP9 10-bit
  HLG** (BT.2020/arib-std-b67) as fallback. Both live in `apps/web/public/hdr/`
  and are committed; pick via `canPlayType`.
- Regenerate them with `scripts/generate-hdr-video.sh` (needs ffmpeg). Gotcha:
  libvpx only writes the WebM Colour element if the *input frames* carry the
  metadata — hence the `setparams` filter in the script. Verify with
  `ffprobe -show_entries stream=color_transfer` after any change.
- Capability detection is `matchMedia('(dynamic-range: high)')` — a capability
  hint only, not a live headroom value.
- In the `BrightnessUnlocker` effect, never let error state or callbacks into
  the dependency array — a failed `play()` re-triggering the effect creates an
  infinite retry loop; a staleness flag silences the expected
  "play() interrupted by pause()" on fast toggles.

Structure: `components/BoostProvider.tsx` (root-layout context: state,
detection, sessionStorage, renders the video) → `components/
BrightnessUnlocker.tsx` (the video element + prime/boost styling).
`app/page.tsx` is the marketing page (hero, demo section with the big toggle,
features, pricing, FAQ); `components/NavBar.tsx` is links-only (toggle
deliberately lives in the demo section); `components/LegalShell.tsx` +
`SiteFooter.tsx` wrap the secondary pages `/about`, `/privacy`, `/terms`,
`/support`. `next.config.mjs` sets `output: 'export'` + `trailingSlash: true`
(folder/index.html per route so static hosts serve them).

### SEO / metadata / analytics (apps/web)

- **Domain**: `maxcandela.com`, single source of truth in `lib/site.ts`
  (`SITE_URL`). `layout.tsx` sets `metadataBase`, canonical, and OpenGraph/
  Twitter tags; the share image is `public/og.png` (1200×630, solid bg —
  generated by `scripts/make-hero.swift`). `app/sitemap.ts` and `app/robots.ts`
  emit `sitemap.xml` / `robots.txt` at build (both `force-static` for export);
  add new routes to the sitemap array. `SITE_URL` must NOT be exported from
  `layout.tsx` — Next rejects non-standard layout exports; hence `lib/site.ts`.
- **Brand mark**: `app/icon.png` (favicon), `app/apple-icon.png` (touch icon),
  `public/brand.png` (nav + footer), all from `scripts/make-icon.swift`.
  Favicon + nav mark are transparent; the touch icon is opaque on purpose —
  iOS composites alpha to black on the home screen.
- **Analytics**: GA4 — **LIVE** with real ID `G-2E5J2Q7FC8` (the `G-XXXX`
  placeholder era is over; `gaConfigured` in `lib/analytics.ts` now passes).
  Web = `lib/analytics.ts` (`GA_ID`) + `components/Analytics.tsx` (gtag,
  IP-anonymized, ad signals off); events fire via `trackEvent`. App =
  `Analytics.swift` (Measurement Protocol, anonymous per-install UUID, nothing
  in DEBUG). Analytics changed the privacy posture — keep `/privacy` and the
  App Store privacy label ("Usage Data → Analytics, not linked to identity")
  in sync. GA cookies imply an EU consent-banner decision (see TODO).

## Native app architecture (apps/macos)

```
main.swift            → NSApplication bootstrap, .accessory activation policy
AppDelegate           → lifecycle; owns MenuBarController + BrightnessController
AppMenu               → the invisible main menu. An accessory app shows no menu
                         bar, but ⌘X/⌘C/⌘V are dispatched via
                         mainMenu.performKeyEquivalent BEFORE the responder
                         chain — with no Edit menu, paste is dead in every text
                         field we present. Do not delete it as "unused UI".
MenuBarController      → NSStatusItem. Single click = instant toggle; double
                         click / right-click = menu; single click on a
                         no-headroom display = menu (so Quit stays reachable
                         where the boost can't work — the App Review path).
                         Menu: "Turn Boost On/Off" carrying the live figure on
                         the same row (attributedTitle, dimmed suffix), stated
                         as headroom *left* — 0.00× once driven to the ceiling.
                         Figures are **per display** (one row each when several
                         can boost); never collapse them, headroom is a ratio
                         against that panel's own SDR white. A second line
                         appears *only* to explain something — thermal
                         ease/pause/dim, or the no-headroom copy.
                         Then the two buy items (top level — they must not be
                         missable), Purchases ▸ (Restore Purchases, Redeem
                         Code…, View in Mac App Store), Legal ▸ (Terms,
                         Privacy, Get Support), Quit. No slider. Restore
                         Purchases stays visible in every license state
                         (Guideline 3.1.1) — but "Redeem Code…" hides once
                         `StoreManager.ownsLifetime`, i.e. the permanent unlock
                         is owned. Keyed on that, NOT on `.licensed`: a monthly
                         subscriber is licensed too, and subscription offer
                         codes are exactly what they might still redeem.
                         Owns licence *enforcement*:
                         enforceLicense() restores or suspends the boost once
                         currentState() resolves — see the trial-enforcement
                         note in the status list.
SupportMessages        → user-facing "which Macs are supported" copy, kept
                         out of the UI layer so it's unit-testable
BrightnessController   → orchestrator: tiny EDR trigger per boost-capable
                         screen; 0.25 s headroom poll (`pollInterval` — sized
                         for how fast the boost must follow the brightness
                         slider, not for the heat model, which integrates over
                         real elapsed time and so is tick-length agnostic);
                         gamma lift fades via 30 Hz animator; toggle-on targets
                         max headroom
ThermalMonitor         → the heat guard: panel-exposure model + chassis
                         temperature + OS thermal state → Limits{boostCeiling,
                         dimTo, engagesEDR}. See "Thermal handling".
ChassisTemperature     → battery-sensor °C via IORegistry (public API,
                         sandbox-safe); nil on Macs with no battery
GammaController        → per-display SDR→EDR lift via transfer tables
                         (table w/ >1.0 values, formula fallback); restoreAll()
DisplayManager         → enumerates NSScreens, reports EDR capability per screen,
                         observes NSApplication.didChangeScreenParametersNotification
EDROverlayWindow       → ~4×4 px borderless click-through corner window per
                         screen; hosts the CAMetalLayer EDR trigger patch
MetalRenderer          → owns MTLDevice/queue; drives the CAMetalLayer render
                         loop (CADisplayLink via NSView.displayLink); clears
                         drawable to EDR white ×boost
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
swift run MaxCandela        # launch the menu-bar app  (pkill -x MaxCandela first
                            #   — a second instance means two ☀️ in the menu bar)
swift build -c release      # release
swift test                  # unit tests — 51 across BoostLogic, DisplayManager,
                            #   SupportMessages. Pure logic only: no test can
                            #   observe the backlight, see "Verifying a
                            #   brightness change actually works".

# Web app (from apps/web/)
npm install
npm run dev                 # http://localhost:3000
npm run lint                # next lint
npx tsc --noEmit            # safe to run while dev is serving — prefer this
npm run build               # static export → apps/web/out/  (NOT while dev runs)
```

### DEBUG-only preview flags (macOS)

Compiled out of release builds, so they can never affect real users. Prefix the
run command, e.g. `MAXCANDELA_FORCE_TRIAL=3 swift run MaxCandela`. Kill any
running instance first (`pkill -x MaxCandela`) to avoid two menu-bar icons.

| Flag | Effect |
|---|---|
| `MAXCANDELA_FORCE_TRIAL=5\|4\|3\|2\|1 swift run MaxCandela` | Trial with N days left (countdown +   tooltip) |
| `MAXCANDELA_FORCE_TRIAL=expired swift run MaxCandela` (or `0`) | Trial ended → paywall on click |
| `MAXCANDELA_FORCE_TRIAL=trial\|licensed swift run MaxCandela` | Full trial / Pro-unlocked |
| `MAXCANDELA_FORCE_PAYWALL=1 swift run MaxCandela` | Skip the debug auto-unlock and run the **real** entitlement + trial-clock code (see below — this is not a way to force a paywall) |
| `MAXCANDELA_FORCE_WELCOME=1 swift run MaxCandela` | Re-show the first-run welcome popover |
| `MAXCANDELA_FORCE_THERMAL=nominal\|fair\|serious\|critical swift run MaxCandela` | Force an OS thermal state (eases/cuts the boost) |
| `MAXCANDELA_FORCE_TEMP=43.5 swift run MaxCandela` | Fake the chassis thermometer → walk the ease/protect ladder without cooking the Mac |
| `MAXCANDELA_FORCE_NO_HEADROOM=1 swift run MaxCandela` | Pretend no display has EDR headroom → preview the "no boost available" alert (what App Review saw on a MacBook Air) |

**The offer-code sheet is NOT ours to position** (measured 2026-07-28, installed
1.1.3 build 14). `centerAttachedSheet` logged *nothing at all* across a 2-hour
window while the sheet was demonstrably presented — its strings are in the
shipped binary, so the code ran and found `anchor.attachedSheet == nil`. The
sheet is drawn by `StoreKitUIServiceMac` out of process, so there is no window
of ours to move and the sandbox offers no supported way to move another
process's window. Do not "fix" the centring by tweaking the maths — it never
gets a window. `hostedWindow(of:)` also checks `childWindows` in case some
StoreKit UI attaches that way, and a one-shot `redeem survey —` log line dumps
what windows existed; read that before touching this again. The **payment**
sheet is different — `purchase(confirmIn:)` takes an NSWindow explicitly and
plausibly is a real sheet, so centring may work there. Unverified.

**"Redeem Code…" cannot be tested under `swift run`** (verified 2026-07-28 from
`log show`). `AppStore.presentOfferCodeRedeemSheet` throws `ASDErrorDomain 507
"No client to present code redemption sheet"` — a bare SwiftPM binary is not an
App Store-installed bundle, so StoreKit has no client to host the sheet. The
`catch` then opens `apps.apple.com/redeem` in the browser, which looks like the
app "going to the gift-card page" but is just the documented fallback. The
store-installed build presents it correctly, in-process, via
`StoreKitUIServiceMac` (`…/redeem/?pbid=com.maxcandela.MaxCandela&ctx=offercodes`).
Test redemption **only in the Mac App Store copy** — not `swift run`, not
`dist/MaxCandela.app`. Note that sheet is an `AMSUIWebView` in *another
process*, so `AppMenu`'s Edit menu may not reach it; ⌘V there is unverified.

Note: plain `swift run` (DEBUG) auto-unlocks (returns `.licensed`) so dev isn't
gated on the App Store — that's why the trial/paywall don't show without a flag.
The auto-unlock also reports `ownsLifetime`, so **"Redeem Code…" is hidden in a
plain `swift run`** (and under `FORCE_TRIAL=licensed`). That is the shipping
behaviour for a lifetime owner, not a broken menu — use `FORCE_TRIAL=trial` to
see the item.

#### `FORCE_TRIAL=expired` vs `FORCE_PAYWALL=1` — they are not the same

Easy to confuse, since both are "about the paywall". They exercise opposite
things (`StoreManager.currentState()`):

- **`MAXCANDELA_FORCE_TRIAL=expired`** returns `.expired` immediately
  (`StoreManager.swift:86`). StoreKit is never consulted, the receipt is never
  read, the clock never runs. It fakes the *answer* — use it to test the
  paywall **UI**. Deterministic, so this is the one for **App Store IAP review
  screenshots**.
- **`MAXCANDELA_FORCE_PAYWALL=1`** forces no state at all. It only disables the
  debug auto-unlock, letting execution fall through to the **real production
  path**: `Transaction.currentEntitlements` → `AppTransaction.shared` →
  `trialDaysRemaining(firstLaunch:)`. Use it to verify the licensing **logic**.

Consequences worth remembering:

- `FORCE_PAYWALL=1` usually shows **no paywall**. Under `swift run` there's no
  App Store receipt, so it falls back to the `com.maxcandela.firstLaunchDate`
  UserDefaults stamp; if this Mac first ran the app under 5 days ago the real
  answer is `.trial`. That's correct behaviour, not a bug.
- **`FORCE_TRIAL` wins if both are set** — it returns before the `FORCE_PAYWALL`
  check is reached.
- Only `FORCE_PAYWALL=1` can catch a broken trial clock or receipt read; the
  forced states bypass that code entirely, so ship-check with it at least once.

There is no CI yet. When adding it, run `swift build`/`swift test` (in
`apps/macos`) and `npm run build` (in `apps/web`) on macOS-latest.

### App Store build (Xcode project via XcodeGen)

SwiftPM has no Archive flow, so the App Store build uses a generated Xcode
project. `apps/macos/project.yml` is the source of truth; the `.xcodeproj` is
gitignored and regenerated:

```bash
cd apps/macos
brew install xcodegen          # once
xcodegen generate              # → MaxCandela.xcodeproj
open MaxCandela.xcodeproj      # then Product → Archive → Distribute
```

The project reuses the same `Sources/MaxCandela` code, `Resources/Info.plist`,
`Resources/MaxCandela.entitlements` (sandbox + network), and an app-icon asset
catalog at `Resources/Assets.xcassets` (generated from `make-icon.swift`'s
PNGs). A post-build script injects `GA_API_SECRET` from the repo-root `.env`
before signing (same as the CLI bundler). `Bundle.module` (icon load) is guarded
by `#if SWIFT_PACKAGE` so it compiles under both SwiftPM and Xcode.

The CLI path (`scripts/bundle-macos.sh --pkg`) still exists as an alternative.

### Submitting to the App Store (Xcode Archive — like iOS)

Full walkthrough, since SwiftPM has no Archive button and this is easy to forget.

**Prerequisites**
- Signed into the Apple ID in Xcode → Settings → Accounts (team YU66583SCF).
- App Store Connect app record exists (bundle `com.maxcandela.MaxCandela`).

**Open the project**
```bash
open /Users/daniel/Codes/maxcandela/apps/macos/MaxCandela.xcodeproj
# regenerate first if project.yml changed:  cd apps/macos && xcodegen generate
```

**One-time signing setup (in Xcode)**
1. Select the **MaxCandela** target → **Signing & Capabilities**.
2. Check **Automatically manage signing** → pick the **Team**. Xcode
   auto-creates the Apple Distribution cert + App Store provisioning profile —
   no manual cert/profile downloads (the big win over the CLI path).
3. **App Sandbox** already shows (from the entitlements file) — leave as-is.

**Archive & upload (same as iOS)**
4. Set the run destination to **Any Mac** (not a specific device).
5. **Product → Archive**, wait for the build.
6. Organizer opens → **Distribute App** → **App Store Connect** → **Upload** →
   click through defaults → **Upload**.
7. Xcode signs with the distribution profile and uploads.

**After upload (App Store Connect)**
8. Build appears under the app after a few minutes of processing.
9. Finish: both IAP products, screenshots (product + IAP review), App Privacy
   label ("Usage Data → Analytics, not linked to identity"), attach the build
   to the version → **Submit for Review**.

The CLI `.pkg` + Transporter path is the fallback if Xcode signing ever fails.

### Verifying a brightness change actually works

Unit tests can't observe backlight. To verify boost behavior you must run the
app on real EDR-capable hardware and watch the display. When testing EDR output,
log `NSScreen.maximumExtendedDynamicRangeColorComponentValue` before/after and
confirm the clamp holds. A perceptual check (does the screen visibly brighten,
does disabling instantly restore it) is required before claiming it works.

## Conventions

- Shipping deployment target is **macOS 15.6** (Info.plist + project.yml). The
  SwiftPM `Package.swift` stays at macOS 14 for dev (`.v15` would force Swift 6
  tools / strict concurrency). The code uses no APIs newer than 14
  (`NSView.displayLink`); raising the target higher buys nothing but loses users
  — flagged to Daniel.
- Swift 5.9. Prefer public frameworks (AppKit,
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
- [x] Menu-bar icon opens the menu (toggle, status, purchases, Legal, Quit).
- [x] Web app: Next.js static export, nav-bar toggle, HDR video assets
      (`scripts/generate-hdr-video.sh`), `dynamic-range` detection.
- [x] Web boost verified on hardware (fullscreen multiply-blend; verified with
      3 nit levels at the time — the selector was since removed, single
      1000-nit clip remains).
- [x] Native trigger + gamma lift implemented; live 1 s headroom poll/clamp.
- [x] Native gamma lift verified on hardware — table path with >1.0 values
      works. Color washout fixed via encoded-gain math + calibration-preserving
      tables (see boost mechanism section).
- [x] Color fidelity verified on hardware after the encoded-gain fix (in daily
      use since, no washout).
- [x] StoreKit 2 paywall: 5-day trial, $9.99 lifetime / $0.99 monthly IAP,
      restore purchases, transaction listener; off/quit never gated. Paywall +
      first-run welcome dialogs use the brand logo (bundled `AppIcon.png`
      resource). Debug: `MAXCANDELA_FORCE_TRIAL`, `MAXCANDELA_FORCE_WELCOME`.
- [x] First-run onboarding: welcome popover anchored to the ☀️ status item
      ("MaxCandela lives up here") so users find the menu-bar-only app.
- [x] Brand mark everywhere, from **one source of truth**:
      `assets/brand/MaxCandela_Logo.png` (transparent MacBook + starburst,
      1254², supplied artwork). `scripts/make-icon.swift <out.iconset> --all`
      resamples it into the macOS iconset, `Assets.xcassets`, the SPM
      `Resources/AppIcon.png` (dialogs), and the web icons;
      `scripts/make-hero.swift apps/web/public` renders `og.png`.
      **Both scripts used to *draw* the mark procedurally** — replacing the
      PNG alone would have been silently overwritten on the next
      `bundle-macos.sh` run, so they now read the source file instead.
      macOS icons get a dark rounded tile (`tile: true`): the artwork's laptop
      is near-black, so on transparency it disappears against dark wallpapers
      in the Dock at 16–32 px. Web assets stay transparent.
- [x] Packaging: Info.plist, sandbox entitlements, generated icon,
      `bundle-macos.sh` (.app verified locally with ad-hoc signing; --pkg for
      App Store).
- [x] Web: marketing page (hero, live demo, features, pricing, FAQ) + UX
      polish (anchor scroll-margin, ScrollLink so nav/CTAs don't pollute the
      back stack, thermal-dim explanation copy).
- [x] Verify gamma/EDR APIs work inside the **sandboxed** build — confirmed via
      the codesigned `dist/MaxCandela.app` (boost + thermal work sandboxed).

### App Store submission — DONE (Daniel drives, Apple-side)

> **Status check 2026-07-28:** MaxCandela is **live on the Mac App Store**
> (`id6792267034`), 1.0.9 published 2026-07-27, confirmed present in the US, KR
> and GB storefronts via the iTunes lookup API. The web CTAs point at the real
> store URL (`APP_STORE_URL` in `apps/web/lib/site.ts` → hero badge + both
> pricing cards); the remaining ScrollLinks are section jumps, which is correct.
> Nothing in this section is outstanding — it is kept as the record of what the
> first submission required. New versions only need the Archive → Distribute
> steps in "Submitting to the App Store" above.

- [x] Xcode project generated (XcodeGen, `apps/macos/project.yml`) — builds &
      archives for the App Store; icon asset catalog, entitlements, GA-secret
      injection all wired. Full Archive steps in the "Submitting to the App
      Store" section above.
- [x] App Store Connect setup — COMPLETE: app record (bundle
      `com.maxcandela.MaxCandela`, SKU `maxcandela-macos-001`), keywords,
      content-rights/age (4+), and everything below:
  - [x] Finish both IAP products: `com.maxcandela.pro.lifetime` ($9.99
        non-consumable) + `com.maxcandela.pro.monthly` ($0.99/mo subscription
        in a "MaxCandela Pro" group) — product IDs must match the code exactly.
  - [x] Set the App Privacy label: **"Usage Data → Analytics, not linked to
        identity"** (NOT "data not collected" — the app sends anonymous GA4).
        Note: adding AdSense to the *website* doesn't change the *app's* label.
  - [x] **Create + upload screenshots**: App Store product screenshots (Mac
        sizes, e.g. 2880×1800) showing the menu-bar toggle + brightness effect,
        AND an IAP review screenshot (the paywall / purchase menu) per product.
  - [x] **Archive & upload**: Xcode → Product → Archive → Distribute App →
        App Store Connect (auto-signing creates the cert + profile — no manual
        certs/`.pkg` needed). CLI `.pkg` + Transporter is the fallback.
  - [x] **Submit for App Review.**

### Analytics / ads

- [x] Google Analytics configured & LIVE. Web Measurement ID `G-2E5J2Q7FC8` in
      `apps/web/lib/analytics.ts`; app uses the same ID (baked into
      `Resources/Info.plist`) + API secret injected from the gitignored `.env`
      (Xcode build-phase and the CLI bundler). App events: app_launch,
      boost_enabled/boost_disabled, paywall_shown, purchase_completed; web:
      page views + boost toggle. DEBUG never sends. `/privacy` discloses it.
- [x] Google AdSense loader added (`ca-pub-7400069037778721` in `layout.tsx`) +
      `/privacy` disclosure. NOTE: no ad units placed yet; won't show ads until
      AdSense approves the site; adds ad cookies (see EU-consent item). Ads on a
      paid-app landing page are questionable — flagged to Daniel.
- [x] App menu polish: trial countdown (`Free trial — N days left`) + hover
      tooltip on the ☀️; menu now shows the *real live* headroom instead of the
      inflated theoretical max; brand logo in the paywall + welcome dialogs.
- [x] Web legal pages: /privacy, /terms (incl. subscription disclosures),
      /support, /about — shared footer links from every page. App Store
      Connect requires the Privacy Policy + Support URLs, so the site must be
      **deployed** before submission (any static host; out/ is the artifact).
- [x] Web: site-wide instant boost (BoostProvider in root layout, priming,
      next/link navigation, sessionStorage restore); glow-free CSS.
- [x] Thermal-aware protection: `ThermalMonitor` eases the boost as the Mac
      warms and — at critical — actively **dims below native** (`criticalDim`
      0.8) to shed heat; fan control documented as impossible in-sandbox.
- [x] **Thermal protection actually reachable (2026-07-27).** Users reported a
      hot screen with no protection, and they were right: it hung off
      `ProcessInfo.thermalState`, which never leaves `.nominal` for display
      heat, and the ceiling reached only the gamma lift, never the EDR trigger —
      so even at critical the panel stayed in HDR mode and just *looked*
      dimmer. Now a three-axis guard (panel-exposure model, chassis
      thermometer, OS state) drives a proportional ceiling and drops EDR when
      cut. Also fixed: the thermal notification ran `refreshTargets()` off the
      main thread. Hardware-verified; see "Thermal handling".
      Versioned as **1.0.9 (9)** — LIVE on the Mac App Store since 2026-07-27.
- [x] SEO: domain maxcandela.com wired (`lib/site.ts`), canonical + OG/Twitter
      tags + `og.png`, `sitemap.xml` + `robots.txt`, JSON-LD SoftwareApplication
      structured data (with prices, no fake ratings), per-page meta descriptions.
- [x] Web deployment: LIVE at https://maxcandela.com via GitHub Pages +
      Actions (`.github/workflows/deploy-web.yml`), custom domain + HTTPS.
      Pushes to `main` touching `apps/web/**` auto-rebuild/redeploy.
      *(2026-07-21: workflow moved off EOL Node 20 → Node 24 LTS; `checkout@v7`
      + `setup-node@v6` for the node24 runner runtime — Node 20 is removed from
      GitHub runners 2026-09-16. `@types/node` bumped ^22 → ^24 to match.
      Pages actions stay at v3/v4 — no newer majors exist yet. Same day:
      **Next 15.5 → 16.2.10** + React 19.2.7 — tsc + static export verified.
      **TypeScript 7 was tried and REVERTED to 5.9.3**: TS 7's own `tsc
      --noEmit` passes, but `next build` crashes in Next's TS integration
      ("The id argument must be of type string") — retry when Next supports
      TS 7.)*
- [x] Update / refresh the website UI — visual design pass on the current dark
      theme (hero, sections, spacing, imagery) to make it feel more polished.
- [x] After the next deploy, verify ownership in **Google Search Console** and
      submit `https://maxcandela.com/sitemap.xml` (this is what gets indexed).
- [x] **Trial enforcement (2026-07-27) — was a total paywall bypass.**
      `BrightnessController.init` restored the persisted boost with **no
      entitlement check**, so anyone who simply left the boost on kept full
      brightness forever; the menu said "Trial ended" while the boost ran.
      Verified by forcing `.expired` with the boost persisted on: gamma table
      read 1.8779 (a live 4.0× boost). Fixed by splitting the restore out of
      `init` into `restorePersistedBoostIfWanted()`, called from
      `MenuBarController.enforceLicense()` *after* `currentState()` resolves;
      expiry mid-session calls `suspendForLicense()` (stops boosting but keeps
      the user's saved preference, so buying restores their setting) and shows
      the paywall once per launch. `isEnabled` now means *actually running*,
      distinct from the persisted `wantsPersistedBoost`. Re-verified on
      hardware: expired → 1.0000 and zero boost events; 3-day trial → 1.8779.
      Enforcement also runs on a 30-min timer + `didWakeNotification`, not only
      at launch/menu-open — otherwise a Mac left running across the expiry
      moment kept boosting. Versioned as **1.0.9 (9)** — LIVE on the Mac App
      Store since 2026-07-27.
- [x] **Trial starts at download, not first open — SETTLED 2026-07-28, do not
      re-open.** `AppTransaction.originalPurchaseDate` anchors the 5-day clock,
      so someone who downloads today and opens in a week gets a short trial,
      and at 6+ days none at all — their first click is the paywall. That is
      the accepted cost of a tamper-proof anchor, chosen over fairness on
      purpose: a locally-stored first-launch date is resettable for unlimited
      free trials, and no unforgeable "first open" exists without a server
      (there is no backend — the site is a static export). Keychain storage is
      *not* the fix: it adds friction, but the user can still delete the item.
      Disclosed in both places, verified 2026-07-28 — `/terms` ("measured from
      the date your Apple Account first downloads MaxCandela") and the home FAQ
      ("open it soon after installing to get the full five days"); keep that
      copy accurate if the clock ever changes.
      The one idea worth costing if it is ever reconsidered: start at first
      launch but hard-expire at `originalPurchaseDate + N days`, which bounds
      the abuse instead of eliminating it, with no server. Not built.
- [x] Trial clock hardening: uses the App Store receipt's original purchase
      date (`AppTransaction.shared`) as the trial start, tamper-proof, with a
      UserDefaults first-launch fallback for dev builds.
- [x] Graceful behavior on non-EDR displays: clicking the icon on a display
      with no EDR headroom shows a "no boost available" explanation instead of
      flipping to a do-nothing on-state. Copy lives in `SupportMessages` and is
      model-specific — **never write "M1 or newer"**, an M1/M3 MacBook Air has
      no XDR panel and never boosts (this exact confusion cost the 1.0.4
      review). `SupportMessagesTests` fails the build on a bare "M1" claim.
- [x] Guideline 3.1.2 compliance (2026-07-20, after the 2.1 info-request
      rejection): paywall alert now spells out title/length/price + auto-renewal
      terms with clickable Terms of Use / Privacy Policy links (NSTextView
      accessory); right-click menu gained Terms of Use + Privacy Policy items
      and a renewal tooltip on Subscribe. Reply draft for the rejection lives
      in `docs/app-review-reply.md` (superseded by the 1.0.4 reply in the same file).
- [x] 1.0.4 rejection (2026-07-20, 5 issues) — app-side fixes DONE, shipping as
      **1.0.7 (7)**: Quit + Restore Purchases are reachable without knowing to
      right-click (Guideline 4 / 3.1.1) — double-click opens the menu, and on a
      no-headroom display (the reviewer's MacBook Air) a *single* click does,
      so that path can't dead-end again. Restore stays visible in every license
      state. A "Get Support" link was added under Legal.
      REMAINING, all App Store Connect metadata:
      attach + submit both IAPs with review screenshots (2.1(b)), state the
      trial/pricing in the App Description (2.3.2), and add the standard Apple
      EULA link to the description (3.1.2(c)). Checklist + reply text in
      `docs/app-review-reply.md`.
- [x] Support address is `hello+maxcandela@nelera.net` (`SUPPORT_EMAIL` in
      `apps/web/app/support/page.tsx`; the `+` is percent-encoded in the
      mailto). The app links the support *page*, not a mailto, so the address
      can change without an app update. Verify the alias actually delivers.
- [x] Need to update the image in our web
- [x] Need to update the image in the app
- [x] Real App Store badge asset + store URL on the web page — live, not
      placeholders: `APP_STORE_URL` (`apps/web/lib/site.ts`) drives the hero
      badge (`public/download-on-mac-app-store.svg`) and both pricing CTAs.
- [x] Promo codes: told the users how to redeem, **and corrected the premise**.
      This item used to read "tell them it will be applied after the 5day free
      trial ends" — that is **false**. `currentState()` checks
      `Transaction.currentEntitlements` *first* and returns `.licensed`
      immediately, so a redeemed code unlocks on the spot and simply replaces
      the trial; the two never interact (our trial is a private app-side clock,
      not an Apple introductory offer, so Apple has nothing to defer a code
      behind). Menu gained **"Redeem Code…"**
      (`AppStore.presentOfferCodeRedeemSheet(from:)`, macOS 15+, guarded because
      SwiftPM dev targets 14; falls back to `apps.apple.com/redeem`, which is
      also the *only* route for non-consumable IAP promo codes — the sheet takes
      subscription offer codes). `/support` + home FAQ document it.
- [~] **1.1.5 (15)** — current source version, set 2026-07-28, built and tested,
      **not yet uploaded**. Bump the *build* number for every upload; Apple only
      requires increasing values, so the skipped 1.1.0–1.1.4 are harmless.
      Version numbering state, as of 2026-07-28 (three different things, easy to
      confuse — check all three before assuming a fix is missing):

  | Where | Version | Note |
  |---|---|---|
  | This repo | 1.1.5 (15) | not uploaded |
  | `/Applications/MaxCandela.app` | 1.1.3 (14) | what Daniel is testing |
  | iTunes lookup API | 1.0.9 | still cached/propagating |

      **A fix you can't see is usually a build older than the fix** — confirm
      with `defaults read /Applications/MaxCandela.app/Contents/Info
      CFBundleShortVersionString`, and `strings …/MacOS/MaxCandela | grep <a
      literal from the change>` to prove whether the code is even in there.

      Contents of this release: `AppMenu` (copy/paste in our own dialogs);
      Purchases ▸ submenu; "Redeem Code…" hides for lifetime owners; menu
      figures restated as headroom *left*, reported **per display**; live
      updating — 0.2 s ticker while the menu is open plus `pollInterval`
      1 s → 0.25 s so the boost follows the brightness slider. Sheet centring
      is in for the payment sheet but **does not work for the offer-code
      sheet** — see the note in the DEBUG-flags section; that is an Apple
      out-of-process window, not a bug in our maths.
      Web copy updated to match (`/support` + home FAQ): menu paths say
      **Purchases ▸**, the headroom line describes "N× left", and the promo-code
      answer leads with `apps.apple.com/redeem` (works for every code type),
      naming the in-app sheet second with its subscription-offer-code limit.
      ⚠️ That limit is **asserted, not tested** — see the redemption note in the
      DEBUG-flags section; it can only be confirmed in the store-installed
      build. Correct this copy if it turns out the sheet takes Lifetime codes.
      The site states no version number, so nothing to bump.
- [x] Promo codes, the practical version (2026-07-28). **App-level promo codes
      are useless here** — they grant a free *download*, and the app is already
      free; they grant no entitlement and Apple rejects them in the in-app
      sheet. Giveaways must use **IAP promo codes** generated inside
      `com.maxcandela.pro.lifetime` (requires that IAP to be *Approved*),
      redeemed at `apps.apple.com/redeem` or Mac App Store → Redeem — **not**
      the in-app sheet, which takes subscription offer codes only. Codes expire
      28 days after generation, are single-use, production-only (never
      sandbox/TestFlight), locked to the Connect storefront's country, and fail
      if the Apple ID already owns the product. The entitlement only appears in
      the **App Store-downloaded** copy — a local `dist/` or `swift run` build
      has no receipt, so `currentEntitlements` stays empty there.
      Once redeemed, "Redeem Code…" hides itself (`StoreManager.ownsLifetime`).
- [x] Copy/paste in app dialogs (2026-07-28): ⌘V did nothing in the redeem-code
      sheet and the paywall text view because `NSApp.mainMenu` was never set —
      AppKit matches command keys against the main menu before the responder
      chain sees them, so with no Edit menu `paste:` was never sent. Fixed with
      `AppMenu` (App + Edit menus, nil targets → first responder), installed in
      `applicationDidFinishLaunching`. Also: the StoreKit sheets now centre
      themselves. A sheet hangs off its parent window's top edge, and the
      invisible anchor window carried a fixed `+120` offset tuned for the
      payment sheet, so the differently-sized redeem sheet sat off-centre —
      `centerAttachedSheet` now measures the sheet and nudges the anchor.
- [ ] GDPR/ePrivacy: GA cookies are live; the AdSense **loader script** is on
      the site but AdSense is not approved and serves no ads yet. An EU consent
      banner will be needed once ads serve (AdSense requires a certified CMP for
      EU traffic). Options: consent banner, or drop ads + switch to cookieless
      analytics. *(2026-07-21: AdSense isn't active — leave this for
      now; revisit when/if AdSense approves.)*

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
- **Never run `npm run build` while `next dev` is serving** — they share
  `.next/`, and the build yanks compiled chunks out from under the dev server
  ("Cannot find module './NNN.js'"). Cure: stop dev, `rm -rf apps/web/.next`,
  restart. Use `npx tsc --noEmit` for verification while dev is running.
- A menu that is open runs the run loop in **event-tracking mode**, where a
  plain `scheduledTimer` (default mode) never fires. Timers meant to update an
  open menu must be `RunLoop.main.add(timer, forMode: .common)`. `showMenu()`
  brackets its ticker around `performClick`, which blocks for exactly as long
  as the menu is on screen. While that ticker runs, `refresh()` is a hot path —
  don't insert/remove menu items or rebuild images in it unless they changed.
- Gamma changes must never be applied as hard table swaps in a loop — each
  swap reads as screen flicker. Fade via the 30 Hz animator; likewise debounce
  `didChangeScreenParametersNotification` (our own EDR engagement fires it).
- `NSWindow`'s `screen:` initializer variant traps in Swift subclasses on
  newer macOS ("unimplemented initializer") — call the base designated
  `init(contentRect:styleMask:backing:defer:)` with global coordinates instead.
- Hydration-mismatch warnings citing `data-*` attributes on `<html>`/`<body>`
  are browser extensions (Grammarly etc.), not bugs — both elements carry
  `suppressHydrationWarning` in the root layout.
