# App Review reply — 2.1.4 (24), information request, 2026-11-27

Submission ID `1dbf648f-39b4-4926-acea-a718a6c8b42e`, reviewed on a MacBook Air
(15-inch, M3). Not a rejection of the code: two questions, answered by reply,
**no new binary**. Apple asked (2.1) which API keeps the screen awake, and
(2.4.5(i)) where `device.bluetooth`, `files.downloads.read-write` and
`personal-information.calendars` are used.

Every statement below was checked against the source on 2026-11-28:
`KeepAwakeTool` is the only `IOPMAssertion*` caller in `Sources/` (no
`beginActivity`, no other assertion type); the assertion doc is quoted from the
SDK's `IOPMLib.h`; menu labels, row titles and messages are the literal strings
in `KeepAwakeTool`, `CalendarTool`, `MonthCalendarTool`, `BluetoothTool` and
`FileShelfPanel`/`FileShelfConvert`. The menu paths assume the default flat
layout ("Tools" / "Pro Tools" section headings).

App Store Connect caps a reply at **4,000 characters** (the first draft was
764 over). This version is 3,332.

## Reply text (paste into App Store Connect)

```
Hello,

Thank you for the review. Our answers are below. Everything described is in build 24 as submitted.

GUIDELINE 2.1 — KEEPING THE SCREEN AWAKE

Only the "Keep Awake" tool (Tools section of the menu) keeps the screen awake. It uses one public IOKit API:

• IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep, kIOPMAssertionLevelOn, "MaxCandela Keep Awake", &assertionID), called when the user picks a duration.
• IOPMAssertionRelease(assertionID), called to end it.

While the assertion is held, the display does not dim or turn off from inactivity, and, as IOPMLib.h documents, the Mac does not idle-sleep. Sleep the user asks for (closing the lid, Apple menu > Sleep) still happens. The purpose is to keep the screen on while presenting, reading or watching a long download.

The assertion is created only when the user clicks Keep Awake > For 30 Minutes, 1 Hour, 2 Hours, 4 Hours, or Until I Turn It Off. It is never created at launch or automatically. It is released on Keep Awake > Off, when the time runs out, and at quit. macOS also drops it if the process exits.

To verify: choose For 30 Minutes, then run "pmset -g assertions" in Terminal. It lists a PreventUserIdleDisplaySleep assertion named "MaxCandela Keep Awake". Choose Off and the assertion is gone. The app uses no other sleep-prevention API.

GUIDELINE 2.4.5(i) — ENTITLEMENTS

All three are used by Pro tools. The 14-day free trial unlocks them, and they appear under the menu's "Pro Tools" heading. Each permission is requested only when the user clicks that tool's "Allow … Access…" row, never at launch. Nothing these tools read leaves the Mac.

com.apple.security.personal-information.calendars
Next Meeting (Pro Tools > Next Meeting > Allow Calendar Access…) calls EKEventStore.requestFullAccessToEvents. It then lists up to six events in the next 36 hours, with a "Join" item for Zoom, Google Meet, Teams, Webex or Whereby links. Once access is granted, Tools > Calendar also marks days that have events and lists the events of the day you click. Access is read-only. With no upcoming events it shows "Nothing in the next day and a half"; add an event in Calendar to see one.

com.apple.security.device.bluetooth
Bluetooth (Pro Tools > Bluetooth > Allow Bluetooth Access…) creates a CBCentralManager, which shows the system prompt. It then lists paired devices (IOBluetoothDevice pairedDevices) and checkmarks the connected ones. Clicking a device connects or disconnects it (openConnection / closeConnection). Where a device offers the standard GATT Battery Service (0x180F), its battery level is shown. With no paired devices it shows "No paired devices"; pair a keyboard, mouse or headphones in System Settings > Bluetooth to see one.

com.apple.security.files.downloads.read-write
File Shelf (Pro Tools > File Shelf > Show Shelf): drop images or PDFs on the shelf, select them, and use the Convert pop-up. It saves images as JPEG, PNG or HEIC (optionally resized or without location data) and merges PDFs. The new file is written to ~/Downloads under a new name, and the pop-up says "New files go to Downloads". Downloads is used because the sandbox does not allow writing next to the original. Nothing is overwritten, and the dropped files are never modified.

Thank you, and please let us know if you need anything else.
```

---

# App Review reply — 1.0.4 (4) rejection, 2026-07-20

Submission ID `dd1bf338-4793-4df1-ac57-89e8db931fd2`. Five issues: **two were
fixed in code (below), three are App Store Connect metadata and must be done by
hand before resubmitting.**

Root cause of the two app-side rejections: the review device was a **MacBook Air
(15-inch, M3)**, which has no EDR headroom. Left-clicking the ☀️ produced only
the "no boost available" alert, and Quit / Restore Purchases lived behind a
right-click the reviewer never tried.

---

## 1. Code changes (done — shipping as 1.0.7 build 7)

- **Guideline 4 (no way to quit)** and **3.1.1 (no Restore Purchases)**: the
  menu no longer hides behind a right-click. **Double-clicking** the status
  item opens it, and on a display with **no EDR headroom — the reviewer's
  MacBook Air — a single click opens it**, so the exact path they took now
  lands on a menu containing Quit MaxCandela (⌘Q) and Restore Purchases
  instead of a dead-end alert. A single click on a supported Mac still toggles
  the boost instantly.
- **Restore Purchases** is no longer hidden once the license is active
  (`MenuBarController.refresh()`), so it is present in every state.
- **Get Support** added under Legal, linking maxcandela.com/support.
- First-run welcome copy updated to teach single-click / double-click.

Version is already set to 1.0.7 (7) in `apps/macos/Resources/Info.plist` +
`project.yml` — regenerate the Xcode project (`xcodegen generate`) before
archiving, since the `.xcodeproj` is gitignored.

## 2. App Store Connect checklist (must be done by hand)

- [ ] **2.1(b)** — On the version page, section *In-App Purchases and
      Subscriptions* → **+** → attach **both** `com.maxcandela.pro.lifetime`
      and `com.maxcandela.pro.monthly`. Creating them is not the same as
      submitting them. Each needs its own **App Review screenshot** (the paywall
      alert) or it stays in "Missing Metadata".
- [ ] **2.3.2** — Add to the App Description, near the top:

      MaxCandela is free to download with a 5-day full-featured trial.
      Continued use requires MaxCandela Pro: a one-time $9.99 purchase
      (MaxCandela Pro Lifetime) or a $0.99/month auto-renewing subscription
      (MaxCandela Pro Monthly). One purchase covers all your Macs.

- [ ] **3.1.2(c)** — Add to the App Description (Apple's standard EULA):

      Terms of Use (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
      Privacy Policy: https://maxcandela.com/privacy/

      The Privacy Policy URL field on the version page must also be filled in.
- [ ] Paste the reply text below into **App Review Information → Notes** so the
      next reviewer sees it up front.

---

## Reply text (paste into Resolution Center)

Thank you for the detailed review. We have addressed all five items.

**Guideline 4 — quitting the app.** The app always had a Quit item, but it was
only reachable by right-clicking the menu bar icon, which was not discoverable.
In this build the menu also opens on a **double-click**, and — importantly for
your test — on any display without HDR headroom, such as the MacBook Air used
for this review, a **single click opens the menu** rather than showing an
alert. "Quit MaxCandela" (⌘Q) is always visible at the bottom of that menu.

**Guideline 3.1.1 — Restore Purchases.** A distinct "Restore Purchases" item is
now permanently visible in that same menu, in every license state, and calls
StoreKit's restore flow only when the user clicks it. Nothing is restored
automatically at launch.

**Guideline 2.1(b) — In-App Purchases not submitted.** Both In-App Purchase
products (MaxCandela Pro Lifetime and MaxCandela Pro Monthly) have now been
submitted for review with App Review screenshots and attached to this version.

**Guideline 2.3.2 — paid content in metadata.** The App Description now states
clearly that the app is free with a 5-day trial and that continued use requires
a one-time $9.99 purchase or a $0.99/month subscription.

**Guideline 3.1.2(c) — subscription information.** The App Description now
includes a functional link to Apple's standard Terms of Use (EULA) and to our
privacy policy. Inside the app, the purchase dialog states the subscription
title, length (monthly), price, and that it auto-renews until cancelled in App
Store account settings, with clickable Terms of Use and Privacy Policy links;
the menu also carries both links under "Legal".

**Note on testing.** The review device was a MacBook Air (M3), whose display has
no HDR/EDR headroom, so the brightness boost itself cannot engage on that Mac —
the app explains this instead of showing a fake on-state. All purchase, restore,
legal, and quit functionality is fully testable on any Mac. To see the boost
itself, please test on a MacBook Pro 14"/16" (2021 or later) or a Pro Display
XDR. Note also that the effect is applied in the display pipeline and therefore
cannot be captured by a screen recording — our attached video was filmed with a
camera.
