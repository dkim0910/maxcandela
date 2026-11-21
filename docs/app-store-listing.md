# App Store listing — 2.0.0 (the toolbox release)

Paste-ready text for App Store Connect. **Nothing here has been submitted.**
Guideline 2.3 requires the listing to match the binary, so this goes in with
the 2.0.0 build. Character counts are checked by
`scripts/check-listing-lengths.py`; every claim was checked against the code on
2026-11-21 — re-check if the tools change before submission.

Each field's text is the fenced block under its heading, exactly as it should
be pasted.

## Name (30 max)

```
MaxCandela
```

Unchanged. A rename also means a new domain and losing the search ranking.

## Subtitle (30 max)

```
Menu Bar Tools & XDR Boost
```

## Promotional text (170 max — editable any time without review)

```
17 Mac tools under one menu bar icon. Eight are free. Pro adds window snapping, a clipboard manager, hidden menu bar icons and an XDR brightness boost.
```

## Keywords (100 max, comma-separated, no spaces)

```
menu bar,window snap,clipboard,keep awake,color picker,ocr,timer,brightness,xdr,dim,hide icons
```

Words already in the name and subtitle (MaxCandela, tools, boost) are left out
on purpose — Apple indexes those fields too.

## Description (4000 max)

```
MaxCandela puts 17 Mac tools under a single icon in your menu bar. Eight are free with no time limit. Pro is free to try for 5 days.

FREE TOOLS
• Keep Awake — stop the display sleeping for 30 minutes, a few hours, or until you turn it off.
• Timer — a countdown shown right in the menu bar, with a chime at the end.
• Clipboard tools — change case, trim, sort or de-duplicate lines, URL- and Base64-encode or decode, format JSON, hash with SHA-256 or MD5, decode a JWT. Optional history of the last 15 things you copied.
• Color Picker — pick any colour on screen and copy its hex code.
• Generate — a UUID, a strong password, a Unix timestamp, an ISO date, or filler text, straight to the clipboard.
• World Clock — the time in the cities you choose.
• Sound — switch output and input devices and mute the microphone.
• System — CPU, memory, free disk space, battery health and cycle count, uptime and local IP address. Pin the figures you want to the menu bar.

PRO TOOLS
• Hide Menu Bar Icons — tuck rarely used icons behind a chevron.
• Clipboard Manager — 200 entries, search, pins, a shortcut to open it, and optional saving between restarts.
• Window Snapping — halves, quarters, maximize and centre, from the menu or with keyboard shortcuts.
• Copy Text from Screen — drag a box over anything and get its text. Recognised on your Mac, never uploaded.
• Shortcuts — run your Apple Shortcuts from the menu bar.
• Next Meeting — your upcoming events with a one-click Join for video calls.

DISPLAY TOOLS (also Pro)
• XDR Brightness Boost — on a MacBook Pro 14″ or 16″ with a Liquid Retina XDR display, or a Pro Display XDR, raises everyday content above the brightness macOS normally limits it to. Colour-calibrated, and it eases itself back as the display warms.
• Extra Dim — go darker than the brightness keys allow. Any Mac.
• Warmth — a warmer white, all day or only at night. Any Mac.

WHICH MACS
Every tool except the brightness boost works on any Mac running macOS 15.6 or later. The boost needs a display with HDR headroom: MacBook Air, iMac and standard external monitors do not have it. Please use the free trial to confirm the boost works on your Mac before buying.

PRIVACY AND PERMISSIONS
No account. Permissions are requested only when you first use the tool that needs one, never at launch: Window Snapping asks for Accessibility, Copy Text from Screen asks for Screen Recording, and Next Meeting asks for Calendar access. Clipboard history is off until you turn it on, stays in memory unless you choose to save it, and skips passwords copied from password managers.

PRICING
Free to download. The eight free tools are free to keep. MaxCandela Pro is free for 5 days from the day you first download the app, then:
• MaxCandela Pro Lifetime — $9.99, one-time purchase
• MaxCandela Pro Monthly — $0.99 per month, auto-renewing until cancelled in your App Store account settings

One purchase covers every Mac signed in to your Apple Account.

Terms of Use (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://maxcandela.com/privacy/
```

## What's New in This Version (4000 max)

```
MaxCandela is now a menu bar toolbox.

• New free tools: Keep Awake, Timer, Clipboard tools, Color Picker, Generate, World Clock, Sound and a System read-out you can pin to the menu bar.
• New Pro tools: Hide Menu Bar Icons, Clipboard Manager, Window Snapping, Copy Text from Screen, Shortcuts and Next Meeting.
• New display tools: Extra Dim and Warmth, with an "only at night" schedule.
• New options: a keyboard shortcut you choose, pause the boost on battery, boost only in chosen apps, choose which display to boost, launch at login.
• A redesigned menu. If you are new, a single click opens it. If you already used MaxCandela, a click still toggles the boost — change it under Options.
```

## URLs

```
Support URL:        https://maxcandela.com/support/
Marketing URL:      https://maxcandela.com/
Privacy Policy URL: https://maxcandela.com/privacy/
```

## Categories

Primary: **Utilities** (matches `LSApplicationCategoryType` in Info.plist).
Secondary: **Productivity**.

## In-app purchases

Product IDs must not change — the code looks them up by ID.

| Product ID | Display name | Description |
|---|---|---|
| `com.maxcandela.pro.lifetime` | MaxCandela Pro Lifetime | Every Pro and display tool, forever. |
| `com.maxcandela.pro.monthly` | MaxCandela Pro Monthly | Every Pro and display tool, billed monthly. |

Both descriptions used to describe a brightness unlock only; update them, and
re-shoot the IAP review screenshot (the paywall now lists the Pro tools).
Apple's limits for these two fields are short — check them in the form.

## App Review notes

```
MaxCandela 2.0 turns the app into a menu bar toolbox. It has no window and no Dock icon: click the sun icon in the menu bar to open the menu. (On a Mac that used an earlier version, a single click toggles the brightness boost instead; double-click or right-click opens the menu.)

NO SPECIAL HARDWARE NEEDED TO REVIEW
The XDR brightness boost needs a MacBook Pro 14"/16" with a Liquid Retina XDR display or a Pro Display XDR. On any other Mac, including MacBook Air, that one row explains that no boost is available. Every other tool works on any Mac.

FREE TOOLS (menu section "Tools")
Keep Awake, Timer, Clipboard, Color Picker, Generate, World Clock, Sound, System. None needs a purchase or a permission.

PRO TOOLS (menu sections "Display" and "Pro Tools")
Unlocked during the 5-day trial and by either in-app purchase. After the trial they appear as "… — Pro" rows that open the purchase dialog. Quit and Restore Purchases (Purchases > Restore Purchases) are always available.

WHY EACH PERMISSION IS REQUESTED
Each is requested only when the user first uses that tool, never at launch.
• Accessibility — Window Snapping (Pro Tools > Window Snapping > Left Half). It is the only supported way for an app to move and resize another app's window. The app does not read window contents.
• Screen Recording — Copy Text from Screen (Pro Tools > Copy Text from Screen…). The user drags a rectangle; only that rectangle is captured, the text in it is recognised on-device with the Vision framework and placed on the clipboard, and the image is discarded. Nothing is stored or transmitted.
• Calendar (com.apple.security.personal-information.calendars) — Next Meeting (Pro Tools > Next Meeting > Allow Calendar Access…). Upcoming events are read to list them in the menu and to find a video-call link to open. Events are not stored or transmitted.

CLIPBOARD
Clipboard history is off by default (Tools > Clipboard > Keep Clipboard History). When on, it is kept in memory only unless the user also enables the Pro option "Remember After Quit", which saves it inside the app's sandbox container. Items marked concealed or transient by password managers are skipped.

OTHER
• Hide Menu Bar Icons adds two status items (a divider and a chevron) and changes only the length of its own divider item.
• Shortcuts runs the user's own shortcuts through the shortcuts:// URL scheme.
• No private APIs are used. No data is collected beyond the anonymous analytics declared in the privacy label.
```

## Before submitting — not done

- **Run the six Pro tools on a real Mac first** — see "Pro tools pack" in
  CLAUDE.md for what is unverified. Remove from this listing anything that
  does not work.
- Screenshots: `assets/screenshots/store/` has five new ones. None shows the
  brightness effect itself.
- The M5 Pro / M5 Max caveat is in the app as a one-time notice and on the
  site; it is not in the description.
- Privacy label: unchanged by 2.0.0 (no new data leaves the Mac).
