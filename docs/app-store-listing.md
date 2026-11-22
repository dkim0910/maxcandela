# App Store listing — the version after 2.0.0

Paste-ready text for App Store Connect. **This describes the version after
2.0.0, not 2.0.0.** 2.0.0 went to review with the text in commit `7f65659`.
Since then: Extra Dim is free, the Pro trial is 14 days (was 5), there are
Shortcuts actions and `maxcandela://boost/…` links, ten more tools, a Menu
Layout option, and Window Snapping is gone from the App Store build
(2026-11-22). Guideline 2.3 requires the listing to match the binary, so this text goes in with the build
that carries those changes, not before. Translations for six more locales are
in `app-store-listing-localized.md`. Character counts are checked by
`scripts/check-listing-lengths.py`; every claim was checked against the code on
2026-11-22. Re-check if the tools change before submission.

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
27 Mac tools under one menu bar icon. 14 are free. Pro adds screenshots with markup, a clipboard manager, per-app volume and an XDR brightness boost.
```

## Keywords (100 max, comma-separated, no spaces)

```
screenshot,clipboard,keep awake,pomodoro,ocr,bluetooth,volume,calendar,brightness,dim,hide icons
```

Words already in the name and subtitle (MaxCandela, menu, bar, tools, XDR,
boost) are left out on purpose — Apple indexes those fields too. "window
snap" went with the tool; "color picker" and "timer" were dropped for
screenshot, pomodoro, bluetooth, volume and calendar to stay under 100.
"hide icons" now also covers the free Hide Desktop Icons, which works on
macOS 27 where Hide Menu Bar Icons does not.

## Description (4000 max)

```
MaxCandela puts 27 Mac tools under one icon in your menu bar. 14 are free with no time limit. Pro is free to try for 14 days.

FREE TOOLS
• Keep Awake — keep the display on for 30 minutes, hours, or until you turn it off.
• Timer — a menu bar countdown with a chime.
• Focus — 25/5, 50/10 or 90/20 minute work and break cycles, counted down in the menu bar.
• Breaks — a 20-second look-away reminder after 20 to 60 minutes of screen time. Never takes focus.
• Clipboard tools — case, sort lines, URL, Base64, JSON, SHA-256, JWT and more, plus a 15-item history.
• Scratchpad — floating notes that save as you type.
• Color Picker — copy any on-screen colour's hex code.
• Generate — UUID, password, timestamp, ISO date, filler text, or a QR code of what you copied.
• World Clock — the time in the cities you choose.
• Calendar — this month as a grid in the menu.
• Sound — switch audio devices and mute the microphone.
• System — CPU, memory, disk, battery health, uptime and local IP, pinnable to the menu bar.
• Desktop — hide the desktop icons, or hide the notch behind a black menu bar strip.
• Extra Dim — darker than the brightness keys allow. Any Mac.

PRO TOOLS
• Screenshot — capture a region, window or screen and mark it up: arrows, boxes, text, highlighter, pixelate, redact, crop. Copy or save.
• Copy Text from Screen — copy the text in any box you drag. Recognised on your Mac.
• Scan QR Code from Screen — copy what a QR code or barcode on screen holds.
• Clipboard Manager — 200 entries, search, pins and optional saving.
• File Shelf — park files on a floating shelf. Convert images to JPEG, PNG or HEIC, resize, remove location details, merge PDFs. New files go to Downloads.
• App Volume — each app's volume, from silent to 200%.
• Bluetooth — connect and disconnect paired devices in one click; battery levels for devices that report them the standard way (not AirPods or Magic accessories).
• Dim Background Windows — darken all windows but the front app's.
• Hide Menu Bar Icons — tuck icons behind a chevron. macOS 26 and earlier.
• Shortcuts — run your Apple Shortcuts from the menu bar.
• Next Meeting — upcoming events with a one-click Join for video calls, also shown in the Calendar grid.

DISPLAY TOOLS (also Pro)
• XDR Brightness Boost — on a MacBook Pro 14″ or 16″ with a Liquid Retina XDR display, or a Pro Display XDR, raises everyday content above the brightness macOS normally limits it to. Colour-calibrated; it eases back as the display warms. Switch it from the menu, a keyboard shortcut, Shortcuts, Spotlight or Siri.
• Warmth — a warmer white, all day or only at night. Any Mac.

WHICH MACS
Every tool except the brightness boost works on any Mac with macOS 15.6 or later; Hide Menu Bar Icons needs macOS 26 or earlier. The boost needs a display with HDR headroom: MacBook Air, iMac and standard external monitors do not have it. Use the free trial to confirm the boost works on your Mac before buying.

PRIVACY AND PERMISSIONS
No account. Permissions are requested only when you first use the tool that needs one: Screen Recording for Screenshot, Copy Text and Scan QR Code; Calendar for Next Meeting; Bluetooth for Bluetooth; System Audio Recording for App Volume, which passes an app's sound through MaxCandela live and never records it. File Shelf opens only the files you drop on it. Nothing these tools read leaves your Mac. Clipboard history is off until you turn it on and skips passwords from password managers.

PRICING
Free to download. The 14 free tools are free to keep. MaxCandela Pro is free for 14 days from the day you first download the app, then:
• MaxCandela Pro Lifetime — $9.99, one-time purchase
• MaxCandela Pro Monthly — $0.99 per month, auto-renewing until cancelled in your App Store account settings

One purchase covers every Mac signed in to your Apple Account.

Terms of Use (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://maxcandela.com/privacy/
```

## What's New in This Version (4000 max)

```
• New free tools: Focus (work and break cycles), Breaks (look-away reminders), Scratchpad, a Calendar month view, Desktop (hide desktop icons, hide the notch), and QR codes in Generate.
• New Pro tools: Screenshot with a markup editor, Scan QR Code from Screen, File Shelf with image conversion and PDF merging, App Volume for per-app volume, Bluetooth quick-connect, Dim Background Windows, and your events in the Calendar view.
• Options > Menu Layout: keep every tool in one list, or group them into five short menus that fit any screen.
• Shortcuts actions: turn the brightness boost on, off or toggle it from the Shortcuts app, Spotlight or Siri — or from Raycast, Alfred and other launchers with maxcandela://boost/on, /off and /toggle links.
• Extra Dim is now free for everyone, on any Mac.
• The free trial of Pro is now 14 days.
• Window Snapping has been removed: apps from the Mac App Store cannot move other apps' windows.
```

The last line assumes 2.0.0 reached users with Window Snapping in it (it is
in the 2.0.0 binary). Drop it if 2.0.0 never ships.

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
| `com.maxcandela.pro.lifetime` | MaxCandela Pro Lifetime | Every Pro tool, the XDR boost and Warmth, forever. |
| `com.maxcandela.pro.monthly` | MaxCandela Pro Monthly | Pro tools, the XDR boost and Warmth, billed monthly. |

Both descriptions used to describe a brightness unlock only, and then "every
display tool", which stopped being true when Extra Dim went free; update them, and
re-shoot the IAP review screenshot (the paywall now lists the Pro tools).
Apple's limits for these two fields are short — check them in the form.

## App Review notes

```
MaxCandela is a menu bar toolbox with no window and no Dock icon: click the sun icon in the menu bar to open the menu. (On a Mac that used an earlier version, a single click toggles the brightness boost; double-click or right-click opens the menu.)

MENU LAYOUT AND QUIT
By default every tool has its own row, so on a 14" MacBook Pro or 13" MacBook Air the menu is taller than the screen and macOS scrolls it. Options > Menu Layout > Grouped by Category puts the tools in five short submenus so the whole menu fits. Quit MaxCandela is always the last row.

NO SPECIAL HARDWARE NEEDED
The XDR brightness boost needs a MacBook Pro 14"/16" with a Liquid Retina XDR display or a Pro Display XDR; elsewhere that row explains no boost is available. Every other tool works on any Mac, except Hide Menu Bar Icons, which is not shown on macOS 27.

FREE: Keep Awake, Timer, Focus, Breaks, Clipboard, Scratchpad, Color Picker, Generate, World Clock, Calendar, Sound, System, Desktop, Extra Dim. No purchase or permission.

PRO ("Display" and "Pro Tools"): unlocked by the 14-day trial or either in-app purchase; afterwards shown as "… — Pro" rows that open the purchase dialog. Quit and Purchases > Restore Purchases are always available.

WINDOW SNAPPING REMOVED
2.0.0 had a Window Snapping tool using the Accessibility API. Apple has said a sandboxed app cannot move other apps' windows, so it is not in this build and the app no longer asks for Accessibility.

PERMISSIONS AND ENTITLEMENTS
Requested only on first use of the tool, never at launch. Nothing they give access to is transmitted.
• Screen Recording — Screenshot (Pro Tools > Screenshot > Capture Region…), Copy Text from Screen, Scan QR Code from Screen. Only the region, window or screen the user picks is captured; text and codes are read on-device with Vision.
• Calendar (personal-information.calendars) — Pro Tools > Next Meeting > Allow Calendar Access…. Lists upcoming events and finds a video-call link. The Calendar month view only uses access already granted.
• Bluetooth (device.bluetooth) — Pro Tools > Bluetooth > Allow Bluetooth Access…. Lists paired devices, connects or disconnects the one clicked, reads the standard GATT Battery Level where offered.
• System Audio Recording (device.audio-input) — Pro Tools > App Volume: play sound in any app, move its slider off 100%. A Core Audio process tap on that app plays its sound at the chosen level, live, never recorded; at 100% the tap is removed. The microphone is never opened; process taps need audio-input in the sandbox.
• files.user-selected.read-write — File Shelf (Pro Tools > File Shelf > Show Shelf, drop files) bookmarks dropped files so they survive a relaunch and never modifies them. Screenshot's Save… writes only to the file chosen in the save panel.
• files.downloads.read-write — File Shelf's Convert menu (JPEG/PNG/HEIC, resize, merge PDFs) writes new files to ~/Downloads; the sandbox does not allow writing next to the original.
• Dim Background Windows reads only window bounds, layer and owner PID (CGWindowListCopyWindowInfo). No names, no pixels, no permission.

CLIPBOARD
History is off by default (Tools > Clipboard > Keep Clipboard History), in memory only unless the Pro option "Remember After Quit" saves it in the app's container. Password-manager items are skipped.

OTHER
• Hide Menu Bar Icons adds two status items and changes only its own divider's length.
• Desktop draws click-through windows at desktop level (wallpaper from its file, or a colour; a black band behind the menu bar for Hide the Notch). No screen capture.
• Breaks counts screen time from lock, screen saver and sleep notifications, not input.
• Shortcuts runs the user's shortcuts via shortcuts://. App Intents and maxcandela://boost/on|off|toggle follow the menu's rules: boost on needs the trial or a purchase; off is never restricted.
• No private APIs. No data collected beyond the anonymous analytics in the privacy label.
```

## Before submitting — not done

- **Run every Pro tool on a real Mac, sandboxed, first** — see "Pro tools
  pack" and "Ten more tools" in CLAUDE.md for what is unverified (App Volume
  has never created a tap; Bluetooth, Screenshot, File Shelf and Dim
  Background Windows have not been used on the glass). Remove from this
  listing, the site and the paywall anything that does not work.
- Screenshots: `assets/screenshots/store/` has six for this release
  (2026-11-22): 1-toolbox, 2-calendar, 3-focus, 4-clipboard, 5-present,
  6-generate-and-clocks. In App Store Connect, **delete the old "Snap
  windows into place" screenshot** and upload these in order. None shows the
  brightness effect itself, and none shows the Screenshot tool's editor (a
  version was made and dropped — Daniel's call).
- The M5 Pro / M5 Max caveat is in the app as a one-time notice and on the
  site; it is not in the description.
- Privacy label: no new data leaves the Mac and there are no new analytics
  events, so the declared categories do not change.
