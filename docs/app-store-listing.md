# App Store listing — draft for 2.0.0 (the toolbox release)

Draft copy for App Store Connect. **Nothing here has been submitted.** Guideline
2.3 requires the listing to match the binary, so this goes in with the 2.0.0
build, not before. Every claim below was checked against the code on
2026-11-21; re-check if tools change before submission.

## Name / subtitle

- **Name:** MaxCandela *(unchanged — a rename also means a new domain and
  losing the existing search ranking; decide separately)*
- **Subtitle (30 chars max):** `Menu Bar Tools & XDR Boost` (26)

## Promotional text (170 chars max, editable without review)

17 Mac tools under one menu-bar icon. Eight are free. Pro adds window snapping,
a clipboard manager, hidden menu bar icons and an XDR brightness boost.

## Description

MaxCandela puts 17 Mac tools under a single icon in your menu bar. Eight are
free with no time limit. Pro is free to try for 5 days.

FREE TOOLS
• Keep Awake — stop the display sleeping for 30 minutes, a few hours, or until
  you turn it off.
• Timer — a countdown shown right in the menu bar, with a chime at the end.
• Clipboard tools — change case, trim, sort or de-duplicate lines, URL- and
  Base64-encode or decode, format JSON, hash with SHA-256 or MD5, decode a
  JWT. Optional history of the last 15 things you copied.
• Color Picker — pick any colour on screen and copy its hex code.
• Generate — a UUID, a strong password, a Unix timestamp, an ISO date, or
  filler text, straight to the clipboard.
• World Clock — the time in the cities you choose.
• Sound — switch output and input devices and mute the microphone.
• System — CPU, memory, free disk space, battery health and cycle count,
  uptime and local IP address.

PRO TOOLS
• Hide Menu Bar Icons — tuck rarely used icons behind a chevron.
• Clipboard Manager — 200 entries, search, pins, a shortcut to open it, and
  optional saving between restarts.
• Window Snapping — halves, quarters, maximize and centre, from the menu or
  with keyboard shortcuts. Uses the Accessibility permission.
• Copy Text from Screen — drag a box over anything and get its text.
  Recognised on your Mac. Uses the Screen Recording permission.
• Shortcuts — run your Apple Shortcuts from the menu bar.
• Next Meeting — your upcoming events with a one-click Join for video calls.
  Uses Calendar access.

DISPLAY TOOLS (also Pro)
• XDR Brightness Boost — on a MacBook Pro 14″ or 16″ with a Liquid Retina XDR
  display, or a Pro Display XDR, raises everyday content above the brightness
  macOS normally limits it to. Colour-calibrated, and it eases itself back as
  the display warms.
• Extra Dim — go darker than the brightness keys allow. Any Mac.
• Warmth — a warmer white, all day or only at night. Any Mac.

The brightness boost needs a display with HDR headroom. MacBook Air, iMac and
standard external monitors do not have it — every other tool works on every
Mac. Please use the free trial to confirm the boost works on your Mac before
buying.

Permissions are requested only when you first use the tool that needs one,
never at launch.

PRICING
Free to download. The eight free tools are free to keep. MaxCandela Pro is
free for 5 days from the day you first download the app, then:
• MaxCandela Pro Lifetime — $9.99, one-time purchase
• MaxCandela Pro Monthly — $0.99 per month, auto-renewing until cancelled in
  your App Store account settings

One purchase covers every Mac signed in to your Apple Account.

Terms of Use (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://maxcandela.com/privacy/

## Keywords (100 chars max)

`menu bar,window snap,clipboard,keep awake,color picker,ocr,timer,brightness,xdr,dim,hide icons` (93)

## What's New in 2.0.0

MaxCandela is now a menu-bar toolbox.
• New free tools: Keep Awake, Timer, Clipboard tools, Color Picker, Generate,
  World Clock, Sound and a System read-out.
• New Pro tools: Hide Menu Bar Icons, Clipboard Manager, Window Snapping,
  Copy Text from Screen, Shortcuts and Next Meeting.
• New display tools: Extra Dim and Warmth (with an "only at night" schedule).
• New options: a keyboard shortcut you choose, pause the boost on battery,
  boost only in chosen apps, per-display boost, launch at login.
• A redesigned menu. If you are new, a single click opens it; if you already
  used MaxCandela, a click still toggles the boost (change it under Options).

## Before submitting — not done

- New screenshots: the current set shows only the brightness effect.
- App Review notes: say the reviewer's Mac needs no XDR display — seven tools
  work on any Mac — and how to reach each tool.
- The M5 Pro / M5 Max caveat (see CLAUDE.md, "Beyond the boost") is in the app
  as a one-time notice; decide whether the description should mention it too.
- Privacy label: no new data leaves the Mac, so the *label* is unchanged — but
  the build now carries the Calendar entitlement and asks for Accessibility,
  Screen Recording and Calendar. App Review will ask why; the review notes
  must explain each (Window Snapping, Copy Text from Screen, Next Meeting).
- **Do not submit until the six Pro tools have been run on a real Mac** —
  see "Pro tools pack" in CLAUDE.md for what is unverified.
