# App Review reply — 1.0.4 (4) rejection, 2026-07-20

Submission ID `dd1bf338-4793-4df1-ac57-89e8db931fd2`. Five issues: **two were
fixed in code (below), three are App Store Connect metadata and must be done by
hand before resubmitting.**

Root cause of the two app-side rejections: the review device was a **MacBook Air
(15-inch, M3)**, which has no EDR headroom. Left-clicking the ☀️ produced only
the "no boost available" alert, and Quit / Restore Purchases lived behind a
right-click the reviewer never tried.

---

## 1. Code changes (done — needs a new build number)

- **Guideline 4 (no way to quit)** and **3.1.1 (no Restore Purchases)**: every
  click on the status item now opens the menu. "Turn Boost On/Off" is the first
  item; Quit MaxCandela (⌘Q) and Restore Purchases are always visible, one click
  from the icon. The instant left-click toggle is gone.
- **Restore Purchases** is no longer hidden once the license is active
  (`MenuBarController.refresh()`), so it is present in every state.
- First-run welcome copy updated to describe the menu instead of right-click.

Bump `CFBundleShortVersionString` / `CFBundleVersion` (→ 1.0.5 / 5) in
`apps/macos/Resources/Info.plist` + `project.yml`, then Archive and upload.

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
In this build, any click on the menu bar icon opens the menu, and "Quit
MaxCandela" (⌘Q) is always visible at the bottom.

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
