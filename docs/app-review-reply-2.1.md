# App Review reply — Guideline 2.1 (Information Needed)

Paste the "Reply text" below into the Resolution Center thread in App Store
Connect, attach the screen recording, and ALSO copy it into
**App Information → App Review Information → Notes** so future submissions
carry it automatically.

---

## Reply text (paste into App Store Connect)

Thank you for the review. Here is the requested information.

**1. Screen recording**

A recording is attached. Important context: MaxCandela's core feature is a
*physical* change to the display's brightness (it drives the panel's HDR/EDR
backlight headroom via Apple's public EDR APIs). Framebuffer-based screen
captures cannot show a backlight change, so the recording was filmed with a
camera pointed at the Mac's display. It shows, in order: launching the app,
the first-run welcome popover, the menu-bar status menu (trial status and
live boost level), toggling the brightness boost on and off (the physical
brightening is visible on camera), the purchase flow for both in-app
purchases (paywall → StoreKit purchase sheet), Restore Purchases, and
quitting the app (which instantly restores normal brightness).

The app has no account registration, login, or account deletion (no accounts
exist), no user-generated content, and no prompts for sensitive data or
device capabilities — it requests no protected resources (no location,
contacts, camera, tracking, etc.), so there are no permission prompts or
purpose strings.

**2. Devices and operating systems tested**

- MacBook Pro 16-inch (2021), Apple M1 Pro, Liquid Retina XDR display
  (MacBookPro18,1) — macOS 26.5.2 (25F84)

**3. Purpose and target audience**

MaxCandela is a single-purpose menu-bar utility for Macs with HDR-capable
(XDR) displays. macOS caps the brightness of standard (SDR) content well
below what the panel can physically produce, reserving the rest for HDR
content. MaxCandela uses Apple's public Extended Dynamic Range (EDR) APIs to
make that reserved headroom available for everything on screen, so the whole
display becomes brighter. The target audience is Mac users who work in
bright environments — outdoors, in sunlight, near windows — where the
default brightness ceiling makes the screen hard to read.

Safety behavior: the boost never exceeds the EDR headroom macOS itself
reports at that moment (the OS's thermal/power ceiling), it eases down
automatically as the machine warms and dims below normal at critical thermal
state, and turning the boost off or quitting the app instantly restores
normal brightness. No persistent system state is changed.

**4. Setup and access instructions**

No login, credentials, or sample files are required.

1. Launch MaxCandela. It runs as a menu-bar app (no Dock icon); a ☀️ icon
   appears in the menu bar, with a first-run popover pointing to it.
2. Left-click the icon to toggle the brightness boost on/off.
3. Right-click the icon for the status menu: current boost level, trial/
   license status, purchase and Restore Purchases items, and Quit.
4. A full-featured 5-day free trial starts automatically on first launch.
   After it expires, turning the boost ON requires an in-app purchase —
   $9.99 lifetime (non-consumable) or $0.99/month (auto-renewable
   subscription). Turning the boost OFF and quitting are never gated.
5. The boost requires a display with EDR headroom (built-in screen of
   MacBook Pro 14″/16″ 2021 or later, Pro Display XDR, or other HDR
   displays). On displays without headroom the app explains that no boost
   is available instead of showing a fake on-state.

**5. External services, tools, and platforms**

The core functionality uses only public Apple frameworks (AppKit, Metal,
QuartzCore, CoreGraphics) and requires no external services or network
connection. Payments are handled exclusively by Apple In-App Purchase
(StoreKit 2). The only third-party service is Google Analytics 4, used for
anonymous usage analytics (an anonymous per-install UUID; no personal
identifiers, no tracking across apps), disclosed in our privacy policy at
https://maxcandela.com/privacy and in the App Privacy label ("Usage Data —
Analytics, not linked to identity"). There are no authentication providers,
AI services, or external data providers.

**6. Regional differences**

None. The app's features and content are identical in all regions; only
App Store pricing is localized by Apple.

**7. Regulated industries / protected third-party material**

Not applicable. The app does not operate in a regulated industry and
contains no third-party protected material. It is built entirely on public
Apple APIs.

---

## Screen recording — filming checklist (before you upload)

The gamma lift is applied in the display pipeline, so **QuickTime/screen
capture will NOT show the brightening** — film the Mac with your iPhone.
Filming the physical machine also satisfies "captured on a physical device."
Dim the room a bit so the boost is obvious on camera.

1. Reset first-run state so the welcome popover shows:
   `defaults delete com.maxcandela.MaxCandela` (and quit any running copy:
   `pkill -x MaxCandela`).
2. Launch `dist/MaxCandela.app` (or the archived build) from Applications.
3. Show the welcome popover, then right-click the ☀️ icon → status menu
   (trial countdown, live headroom line).
4. Left-click → boost ON (visible brightening). Left-click again → OFF.
5. Purchase flow: use the purchase items in the right-click menu (or force
   the paywall with a debug build: `MAXCANDELA_FORCE_TRIAL=expired`), tap
   through to the StoreKit sheet with a **sandbox Apple ID**, complete the
   purchase, show the menu now reading Pro/licensed.
6. Show Restore Purchases.
7. Quit the app — brightness visibly returns to normal.

Keep it one continuous take if possible; 2–4 minutes is plenty.
