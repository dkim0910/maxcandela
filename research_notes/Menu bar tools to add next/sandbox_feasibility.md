# Sandbox feasibility of candidate menu-bar tools for MaxCandela (Mac App Store, public APIs only, macOS 15–26, researched 2026-11-22)

Scope note: the brief asked for macOS 15–26. As of this research date, **macOS 27 has shipped**. Forum posts dated Sep–Oct 2026 cite macOS 27.0.1 (build 26A434). Several findings below are macOS 27 regressions, flagged where they appear. "Verified" means an Apple doc, an Apple DTS statement, or a live Mac App Store listing. Store listings prove an app is *sold* on the store. They do **not** prove it is sandboxed or that it uses the API assumed here. Quinn (DTS) warns that some store apps predate the 2012 sandbox rule.

---

## 0. Cross-cutting: what the App Sandbox actually permits (read this first)

### Takeaway
Apple's own docs list "use of accessibility APIs in assistive apps" and "terminating other running apps" as forbidden in the sandbox. DTS (Quinn) said in 2025–2026 that the three input privileges behave differently. **Input Monitoring** (listen-only event taps) is sandbox-safe. **PostEvent** (synthesising input) is sandbox-compatible but draws Guideline 2.4.5 rejections. **Accessibility** (AXUIElement: read or move other apps' windows) is *not* sandbox-compatible. That last point directly contradicts MaxCandela's shipped-but-untested Window Snapping tool.

### Cited Findings
- Apple's list of activities "forbidden by the operating system when an app runs in a sandbox" includes: "Use of accessibility APIs in assistive apps", "Sending Apple Events to arbitrary apps", "Simulating user input in Open and Save dialogs", "Accessing or modifying preferences in other apps", "Configuring network settings", "Terminating other running apps". — [Apple: Protecting user data with App Sandbox](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox)
- Apple's App Sandbox entitlement index lists these hardware/data keys: `device.camera`, `device.microphone`, `device.usb`, `print`, `device.bluetooth`, `personal-information.addressbook`, `personal-information.location`, `personal-information.calendars`, `files.user-selected.read-only/read-write`, `files.downloads.read-only/read-write`, `assets.pictures/music/movies.*`, `network.client`, `network.server`. It also states: "To distribute a macOS app through the Mac App Store, you must enable the App Sandbox capability." — [Apple: App Sandbox](https://developer.apple.com/documentation/security/app-sandbox)
- Quinn (DTS, Mar 2026) on the TCC mapping: "Both `PostEvent` and `Accessibility` map to Accessibility." / "`ListenEvent` maps to Input Monitoring." / "The APIs gated by the `Accessibility` privileged are not compatible with the App Sandbox." / "The APIs gated by the other two privileges _are_ compatible with the App Sandbox." — [Apple forums 820594](https://developer.apple.com/forums/thread/820594)
- Same thread: a clipboard manager that posts ⌘V with `CGEvent.post` was rejected twice under **Guideline 2.4.5**, the reviewer saying (paraphrased by OP) "Accessibility features should not be used for non-accessibility purposes". Later developers (Jun and Sep 2026) report the same rejection, with no resolution posted. — [Apple forums 820594](https://developer.apple.com/forums/thread/820594)
- Quinn (DTS, Apr 2025): "It's not possible for a sandboxed app to use the Accessibility privilege [1]… DTS doesn't support folks using general accessibility APIs is sandboxed apps." Footnote: "Without employing temporary exception entitlements." And: "It _is_ possible for a sandboxed app to use the Input Monitoring privilege. I regularly test this. Specifically, I'm using the `CGEventTap` API." — [Apple forums 780626](https://developer.apple.com/forums/thread/780626)
- Quinn (DTS, Jun 2022): use `CGEventTap` rather than `NSEvent` global monitors, because "the former requires the Accessibility privilege whereas the latter requires the Input Monitoring privilege. The Input Monitoring privilege is easily available to sandboxed apps, and even apps published on the Mac App Store". Preflight/request with `CGPreflightListenEventAccess` / `CGRequestListenEventAccess`. — [Apple forums 707680](https://developer.apple.com/forums/thread/707680)
- Quinn (DTS, Sep 2025): "Not all Mac App Store apps are sandboxed. Some apps shipped on the store before sandboxing was required." He advises checking with `codesign -d --entitlements -`. — [Apple forums 707680](https://developer.apple.com/forums/thread/707680)
- **Window management in a sandbox.** In late 2026 a developer asked whether a sandboxed app can move, resize or focus other apps' windows with user-granted Accessibility. Quinn answered "Yes" (the restriction does block it), "No" (no public API or entitlement), "No" (no supported MAS architecture), and recommended Developer ID distribution. He added: "There's no 'make Accessibility work' temporary exception entitlement" and "App Review takes a dim view of folks using temporary exception entitlements in Mac App Store apps." — [Apple forums 854711](https://developer.apple.com/forums/thread/854711)
- The `com.apple.systemevents.window.position` scripting-target workaround returned -10004 "privilege violation" on macOS 27.0.1. Quinn: "That's not sufficient for your requirements… Apple has been increasingly locking down this sort of thing in recently years." — [Apple forums 854881](https://developer.apple.com/forums/thread/854881)
- Developer reports: one sandboxed app gets `AXIsProcessTrusted` == true while `AXUIElementCopyAttributeValue` fails with `.cannotComplete`. — [Apple forums 794253](https://developer.apple.com/forums/thread/794253). Another says App Store Connect refuses a non-sandboxed AX app while older window managers (Magnet, Divvy) remain on the store. — [Apple forums 836644](https://developer.apple.com/forums/thread/836644)
- A conflicting developer report says `.post()` "just silently does nothing under the sandbox" for synthesised keystrokes, while event-tap *capture* works. This contradicts Quinn's "PostEvent is sandbox-compatible". — [dev.to (quicopy)](https://dev.to/quicopy/shipping-global-keyboard-shortcuts-on-macos-sandbox-the-part-apple-doesnt-document-57no)
- MaxCandela repo state (read 2026-11-22). `apps/macos/Resources/MaxCandela.entitlements` contains only `app-sandbox`, `network.client`, `personal-information.calendars`. `Tools/WindowSnapTool.swift` calls `AXIsProcessTrustedWithOptions`, `AXUIElementCopyAttributeValue` and `AXUIElementSetAttributeValue` (lines 171–208). — [repo file](/Users/daniel/Codes/maxcandela/apps/macos/Sources/MaxCandela/Tools/WindowSnapTool.swift)

### Inferences
- **The developer's premise is wrong in one place.** The brief says the app "already uses Accessibility". Per DTS, AX calls on other apps' windows from a sandboxed app are unsupported and reported to fail, and the dev binary that "has no AX grant" is unsandboxed, so it never exercised this. Window Snapping should be tested in the sandboxed `dist/` or Xcode build before any new tool leans on AX.
- **Practical permission tiers for new tools:**
  - **Tier A:** no prompt.
  - **Tier B:** an entitlement plus a standard TCC prompt (camera, microphone, location, Bluetooth, Calendar, Screen Recording, Input Monitoring). All supported.
  - **Tier C:** PostEvent / Accessibility TCC. Technically mixed, and an App Review 2.4.5 risk.
  - **Tier D:** forbidden.
- Older "precedent" apps that use AX on the store (Magnet, HazeOver id430798174) have low app IDs from the pre-2012 era and may be grandfathered or unsandboxed. Treat them as weak precedent for a *new* submission. Recent-ID apps that ask for Accessibility (e.g. KeyBlock id6751187079, §13) are better evidence of what review currently accepts.

### Gaps
- No primary source found for whether a **filtering (active, non-listen-only) `CGEventTap`**, as used by keyboard lockers and text expanders, needs the Accessibility or Input Monitoring TCC service when sandboxed.
- No App Review statement found on what 2.4.5 accepts. DTS explicitly declines to speak for App Review in every thread above.

---

## 1. File shelf / drag-and-drop stash (Dropover, Yoink)

### Takeaway
Feasible, with strong store precedent. Drag-and-drop grants access to the dropped items. The traps are persisting shelf items across launches (security-scoped bookmarks) and writing derived files next to the originals.

### Cited Findings
- Dropover is on the MAS: "floating shelves" for files, folders, images, URLs and text. Recent versions support Shift-drag to keep the shelf open and "drop items onto the notch". Requires macOS 13. — [Dropover, Mac App Store](https://apps.apple.com/app/dropover/id1355679052)
- Yoink is on the MAS ($8.99). The shelf "fades in at the edge of your screen" when a drag starts, multiple files condense into a Stack, and it includes clipboard history. v3.7 shipped 2026-01-28. — [Yoink, Mac App Store](https://apps.apple.com/us/app/yoink-better-drag-and-drop/id457622435?mt=12)
- Sandbox file access is limited to the user-selected item. Developers report "the sandbox only grants access to the selected file, not to other files in the directory". — [Apple forums 769345](https://developer.apple.com/forums/thread/769345)
- The "related items" mechanism (`NSIsRelatedItemType`) allows a same-name, different-extension sibling. — [Christian Tietze](https://christiantietze.de/posts/2020/05/related-files/); [Apple: Accessing files from the macOS App Sandbox](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox)

### Inferences
- Entitlements: `files.user-selected.read-write` plus app-scoped bookmarks, so the shelf survives a relaunch. No TCC prompt. Detecting "a drag has started anywhere" (Yoink-style auto-reveal) can use the drag pasteboard / `NSEvent` global mouse-drag monitoring, which needs no privilege for mouse events. This is unsourced and should be verified.
- Effort: **medium** (floating panel, drag source and destination, bookmarks, thumbnails via QuickLook).

### Gaps
- Not verified: whether a sandboxed app can observe an in-progress system drag without Accessibility, i.e. how Yoink's auto-reveal is implemented today.

---

## 2. Screenshot + annotate, scrolling capture, screen recording to GIF (ScreenCaptureKit)

### Takeaway
Feasible, with many MAS precedents. It needs Screen Recording, which MaxCandela already requests. Sequoia added recurring "still allow?" prompts for apps not using the system picker. Scrolling capture is the hard part, because driving the scroll for the user is a PostEvent/2.4.5 risk.

### Cited Findings
- MAS precedents with scrolling capture and annotation:
  - Xnip ("no network access permission") — [Xnip, MAS](https://apps.apple.com/us/app/id1221250572)
  - Longshot (scrolling + OCR) — [Longshot, MAS](https://apps.apple.com/app/id6450262949)
  - GIF recorder Gifox 2 (area/window recording) — [Gifox 2, MAS](https://apps.apple.com/us/app/gifox-2/id1461845568?mt=12)
- macOS 15 Sequoia re-prompts for screen-recording permission **monthly** (reduced from weekly in beta) and dropped the per-restart prompt. — [TidBITS, Aug 2024](https://tidbits.com/2024/08/19/apple-reduces-excessive-sequoia-permission-requests-shifts-to-monthly)
- Commenters report "unless you use the actual ScreenCaptureKit window picker… there is no way around those permission requests and reminders". — [9to5Mac comments](https://9to5mac.com/2024/08/14/macos-sequoia-screen-recording-prompt-monthly/?extended-comments=1)
- A separate entitlement, `com.apple.developer.persistent-content-capture`, exists for remote-access apps. — [Apple forums 761641](https://developer.apple.com/forums/thread/761641)
- **macOS 27 regression:** `CGWindowListCreateImage` "returns some gray image" from macOS 27 beta 4 onwards. DTS (Oct 2026): "I can't offer a way to capture them [desktop wallpaper windows] with ScreenCaptureKit without [Screen Recording]." — [Apple forums 849969](https://developer.apple.com/forums/thread/849969)

### Inferences
- MaxCandela's `ScreenTextTool` already uses `SCScreenshotManager`, so a screenshot tool reuses the region-selection overlay and the permission. Annotation is pure AppKit drawing. GIF export uses ImageIO `CGImageDestination` with a GIF UTI. Video uses `SCStream` plus `AVAssetWriter`.
- Scrolling capture has two options. (a) The user scrolls while the app captures frames and stitches them: no extra permission. (b) The app scrolls the target: synthetic scroll events, which means PostEvent TCC and 2.4.5 exposure (see §0). Prefer (a).
- Effort: screenshot + annotate **medium**; GIF/video recording **medium**; scrolling capture **large** (stitching / feature matching).

### Gaps
- No authoritative source found on whether macOS 26 changed the monthly re-authorisation cadence. Whether the listed MAS apps scroll the target themselves was not verified.

---

## 3. Battery charge limit (AlDente-style) and battery read-outs

### Takeaway
A charge limiter is **not feasible** (SMC writes need root), and since **macOS 26.4 it is redundant**: Apple ships a built-in 80–100% Charge Limit. Read-outs (health, cycles, time remaining) are feasible, and MaxCandela's System tool already reads `AppleSmartBattery`.

### Cited Findings
- macOS Tahoe 26.4 adds Charge Limit: "set a maximum charge level anywhere from 80 to 100 percent", in 5% steps, under System Settings → Battery → (i) next to Charging. — [MacRumors, Feb 2026](https://www.macrumors.com/2026/02/16/mac-charge-limit-macos-tahoe-26-4/)
- Apple: requires macOS Tahoe 26.4 or later and Apple silicon. The Mac occasionally charges to 100% to keep its estimates accurate, and the limit applies only while macOS is running. — [Apple Support 102338](https://support.apple.com/en-gb/102338)
- User reports say the limit stopped being respected after 26.5. These are anecdotal. — [Apple Community](https://discussions.apple.com/thread/256286525)
- AlDente installs a privileged helper because writing SMC keys requires root. Source is a search snippet of an AlDente README mirror; the page was not opened. — [AlDente README mirror](https://github.com/igit-cn/AlDente)
- A single blog claims third-party charge-limit apps broke on macOS 27 because "being root does not grant entitlements". This is unverified. — [macos-tahoe.com](https://macos-tahoe.com/blog/macos-27-battery-charge-limit-apps-broken-aldente-batt-charging-to-100-fix-2026/)
- MaxCandela's CLAUDE.md records that the System tool already shows battery % / health / cycles via `AppleSmartBattery`, and that the battery-temperature read is "verified readable under the shipping entitlements". — [repo CLAUDE.md](/Users/daniel/Codes/maxcandela/CLAUDE.md)

### Inferences
- Rather than building a limiter, add a one-line read-out or deep link ("Charge limit is set in System Settings → Battery") on 26.4+.
- Time-remaining comes from `IOPSCopyPowerSourcesInfo` / `IOPSGetTimeRemainingEstimate`. These are public IOKit.ps APIs (unsourced here; MaxCandela's `PowerMonitor` already uses IOKit.ps per CLAUDE.md).
- Effort for read-out additions: **small**.

### Gaps
- No public API was found to *read* the user's configured Charge Limit value.

---

## 4. Bluetooth / AirPods quick connect and battery levels

### Takeaway
Quick-connect to paired devices is feasible with `com.apple.security.device.bluetooth` (ToothFairy is the MAS precedent). Battery levels are only as good as what macOS itself exposes. Expect App Review to also want `network.client`, which MaxCandela already has.

### Cited Findings
- ToothFairy is sold on the MAS and on Setapp (macOS 10.13+). It shows AirPods left/right battery, but "If the macOS Bluetooth menu does not show the battery level, ToothFairy won't, either." — [ToothFairy manual](https://c-command.com/toothfairy/manual); [ToothFairy, MAS](https://apps.apple.com/app/toothfairy/id1191449274)
- Entitlement description: "A Boolean value indicating whether your app may interact with Bluetooth devices". In one rejection, App Review additionally asked for `com.apple.security.network.client`. — [Apple forums 769362](https://developer.apple.com/forums/thread/769362)
- A launchd daemon with the entitlement got a TCC refusal for "Bluetooth access in background session". — [Apple forums 738748](https://developer.apple.com/forums/thread/738748)
- `device.bluetooth` is a documented sandbox entitlement. — [Apple: App Sandbox](https://developer.apple.com/documentation/security/app-sandbox)

### Inferences
- API: `IOBluetoothDevice.pairedDevices()`, `openConnection()` / `closeConnection()`. macOS shows a Bluetooth TCC prompt (`NSBluetoothAlwaysUsageDescription`), since macOS 11 per general knowledge (unsourced).
- AirPods per-bud battery has no documented public property. ToothFairy's statement implies it reads whatever the system publishes, probably via IORegistry or IOBluetooth properties. This needs hardware testing.
- Effort: connect/disconnect **small–medium**; battery read-out **medium**, with uncertain API.

### Gaps
- No primary source found naming the public property ToothFairy uses for battery. Its sandbox status was not verified, since its app ID is mid-2016 era.

---

## 5. Wi-Fi details, network speed meter, ping/latency, public IP

### Takeaway
- **SSID:** needs Location authorisation (macOS 14+) plus `personal-information.location`, and is flaky.
- **Throughput meter:** feasible.
- **Public IP:** trivial with `network.client`.
- **Ping:** ICMP from a sandbox is murky. Use TCP-connect or HTTP latency instead.

### Cited Findings
- Apple's `CWInterface.h` header says SSID "is not available unless Location Services is enabled and the user has authorized the calling app to use location services". An Apple engineer confirmed this was a deliberate change. The current-network SSID requirement arrived in macOS 14, and 14.4 tightened it further. — [Apple forums 732431](https://developer.apple.com/forums/thread/732431)
- Sequoia 15.1: `scanForNetworks` doesn't expose SSIDs even with Location authorised. — [Apple forums 769950](https://developer.apple.com/forums/thread/769950)
- A LaunchAgent still gets a nil SSID on macOS 26.3 with Location authorised. — [Apple forums 816619](https://developer.apple.com/forums/thread/816619)
- The entitlement alone was not enough; developers had to request authorisation via `CLLocationManager`. — [Apple forums 744189](https://developer.apple.com/forums/thread/744189)
- ICMP in a sandbox: one developer reports it "requires that you have both the `com.apple.security.network.client` and `com.apple.security.network.server` entitlements". `SOCK_DGRAM`/`IPPROTO_ICMP` avoids root, but `sendto` failures are reported. — [Apple forums 43697](https://developer.apple.com/forums/thread/43697)
- Network.framework can't do ICMP. — [Apple forums 709256](https://developer.apple.com/forums/thread/709256)
- The DF bit stopped working on macOS 15. — [Apple forums 775253](https://developer.apple.com/forums/thread/775253)
- A conflicting secondhand claim says the sandbox's network-outbound rule allows only IPv4/IPv6/Unix sockets, which would block ICMP sockets. — [Xojo forum](https://forum.xojo.com/35370-traceroute-from-sandbox)
- iStat Menus 7 is sold on the MAS (macOS 14+). MAS reviewers and forum posters say the MAS build lacks some direct-version features (fan control, weather). These are user claims. — [iStat Menus 7, MAS](https://apps.apple.com/app/id6499559693); [MacRumors forum](https://forums.macrumors.com/threads/istat-menus-7-0-brings-comprehensive-redesign-and-new-features.2432615/page-14)

### Inferences
- **Throughput:** poll `getifaddrs()` `if_data` byte counters (`ifi_ibytes` / `ifi_obytes`) once per second. Public BSD API, no entitlement (unsourced; standard practice).
- **Latency:** time a TCP connect (`NWConnection`) to 1.1.1.1:443 or an HTTPS HEAD. It needs only `network.client`, which MaxCandela has, and avoids the ICMP uncertainty entirely.
- **Wi-Fi panel:** adding Location adds a prompt, an entitlement and a privacy-label change (MaxCandela's CLAUDE.md already rejected location for the Warmth schedule for this reason). RSSI, noise, channel, Tx rate and PHY mode do not appear in the Location-gated list in the sources above. Consider shipping Wi-Fi without the SSID.
- Effort: speed meter **small**; public IP **small**; TCP latency **small**; SSID **medium** (location plumbing and flaky behaviour).

### Gaps
- Not verified whether RSSI and channel via CoreWLAN are available without Location on macOS 15–26.

---

## 6. Pomodoro / focus timer, break reminders, stand-up reminders, 20-20-20

### Takeaway
Fully feasible with no permission beyond optional notifications. Store precedents abound. MaxCandela's Timer tool deliberately avoids notification permission.

### Cited Findings
- MaxCandela's existing Timer tool shows a countdown beside the status icon and plays "Glass" with "no notification permission on purpose". — [repo CLAUDE.md](/Users/daniel/Codes/maxcandela/CLAUDE.md)

### Inferences
- Timers, an `NSPanel` or full-screen break overlay, and optional `UNUserNotificationCenter`. Idle detection uses `CGEventSourceSecondsSinceLastEventType`, a public CoreGraphics call. Whether it needs Input Monitoring is unverified; check before relying on it for "pause when away".
- Effort: **small** for each variant.

### Gaps
- No research done on whether `CGEventSourceSecondsSinceLastEventType` triggers Input Monitoring TCC in a sandbox.

---

## 7. Quick notes / scratchpad, menu-bar to-do

### Takeaway
Feasible, no permissions. Storage is the app container. An optional Reminders sync would need a new entitlement and permission (Reminders full access) not in MaxCandela today.

### Cited Findings
- The sandbox gives an app a container "to which the app has unrestricted read and write access". — [Apple: Protecting user data with App Sandbox](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox)

### Inferences
- `NSTextView` in a popover or panel, autosaved to Application Support. Effort: **small**. A Reminders-backed to-do via EventKit would be **medium** and adds a permission prompt; a local-only to-do stays **small**.

### Gaps
- Did not verify the Reminders entitlement key name or prompt text for macOS 15–26.

---

## 8. Calendar month view in the menu bar (Itsycal-style) via EventKit

### Takeaway
Feasible. MaxCandela already holds the Calendar entitlement and permission for Next Meeting. Dato is the MAS precedent; Itsycal itself is direct-download.

### Cited Findings
- Dato is a "menu bar calendar and world clock" sold on the MAS. Google Calendar works if added to Calendar.app. — [Dato](https://sindresorhus.com/dato); [Dato, MAS](https://apps.apple.com/us/app/dato/id1470584107)
- Itsycal is free and open source (MIT) and shows events "as a companion to the Mac Calendar app". — [AlternativeTo: Dato alternatives](https://alternativeto.net/software/dato)
- `personal-information.calendars` is a documented sandbox entitlement. — [Apple: App Sandbox](https://developer.apple.com/documentation/security/app-sandbox)
- MaxCandela already ships it plus `NSCalendarsFullAccessUsageDescription`. — [repo entitlements](/Users/daniel/Codes/maxcandela/apps/macos/Resources/MaxCandela.entitlements)

### Inferences
- A month grid in an `NSMenuItem.view` or popover, plus `EKEventStore.events(matching:)`. No new permission. Overlaps heavily with the existing World Clock and Next Meeting tools; combining them into a "Calendar" tool is natural.
- Effort: **medium** (grid layout, event dots, week numbers, first-weekday localisation).

### Gaps
- None material.

---

## 9. Weather in the menu bar (WeatherKit)

### Takeaway
Feasible. WeatherKit includes 500k calls/month with the developer membership and requires visible Apple Weather attribution. Location is optional: offering a manual city picker avoids the Location prompt and entitlement entirely.

### Cited Findings
- "500,000 API calls/month" are included with the Apple Developer Program membership. Paid tiers: 1M $49.99, 2M $99.99, 5M $249.99, up to 200M $9,999.99/month. Unused calls don't roll over. On Apple platforms use the WeatherKit framework (Xcode 14+); the REST API is "for other platforms and websites". — [Apple: Get started with WeatherKit](https://developer.apple.com/weatherkit/get-started/)
- The quota covers development, beta and production calls. — [Apple forums 793813](https://developer.apple.com/forums/thread/793813)
- "Using this API requires attribution", with an `/attribution/{language}` endpoint. — [Apple: WeatherKit REST API](https://developer.apple.com/documentation/weatherkitrestapi)
- `personal-information.location` is a documented sandbox entitlement. — [Apple: App Sandbox](https://developer.apple.com/documentation/security/app-sandbox)

### Inferences
- WeatherKit needs the WeatherKit capability enabled on the App ID (Certificates, Identifiers & Profiles) and a signed build. `swift run` won't have it, so test in the Xcode/`dist` build.
- Cost: 500k calls/month ÷ 30 days ≈ 16.6k calls/day. At one fetch per user per 30 min (48/day), that covers ~350 daily-active weather users before paying. Caching and sharing location fetches, or polling hourly (~700 users), matters. Back-of-envelope only.
- Effort: **medium** (city search via `CLGeocoder` / `MKLocalSearch`, attribution UI, caching).

### Gaps
- Did not confirm whether `CLGeocoder` forward-geocoding from a sandboxed app needs the location entitlement. It shouldn't, but this is unverified.

---

## 10. Unit / currency converter, calculator

### Takeaway
Feasible, no permission. Currency needs a rates feed over `network.client`, which MaxCandela already has.

### Cited Findings
- No external research was performed on this item; it was judged low-risk.

### Inferences
- Units: Foundation `Measurement` / `UnitLength` etc. Calculator: `NSExpression` or a small parser. Currency: an ECB-based free API, cached daily.
- Disclosing a third-party rates endpoint may need a `/privacy` note, since MaxCandela's privacy page enumerates network use per CLAUDE.md.
- Effort: **small**.

### Gaps
- No currency-API provider terms checked.

---

## 11. Text expansion / snippets

### Takeaway
Detecting the abbreviation is sandbox-safe (listen-only `CGEventTap`, Input Monitoring). *Replacing* it means posting delete keystrokes and pasting, which is the exact `CGEvent.post` pattern that drew 2.4.5 rejections in 2026. MAS text expanders exist, but this is a high review risk and conflicts with MaxCandela's earlier "auto-paste ruled out" decision.

### Cited Findings
- Quinn: Input Monitoring via `CGEventTap` works in sandboxed and MAS apps. — [Apple forums 707680](https://developer.apple.com/forums/thread/707680); [Apple forums 780626](https://developer.apple.com/forums/thread/780626)
- PostEvent maps to the Accessibility TCC service. ⌘V-posting apps were rejected under 2.4.5 in Mar and Sep 2026. — [Apple forums 820594](https://developer.apple.com/forums/thread/820594)
- MAS text expanders exist: TypeIt4Me 7, Fast Text, Text Catalyst. — [TypeIt4Me 7, MAS](https://apps.apple.com/gb/app/typeit4me-7/id6474688391?mt=12); [Fast Text, MAS](https://apps.apple.com/us/app/fast-text-text-expander/id1597462934?mt=12); [Text Catalyst, MAS](https://apps.apple.com/app/text-catalyst/id6752991699)
- TypeIt4Me's developer wrote (2025) that the MAS version had been limited because it wasn't sandboxed, and that direct-version features were arriving there. — [Michael Tsai blog, Apr 2025](https://mjtsai.com/blog/?p=47480)
- Secure Input (enabled by password fields and some apps) prevents all text expanders from seeing keystrokes. Source is a TextExpander support snippet surfaced in search; the URL was malformed and not opened. — [TextExpander for Mac](https://textexpander.com/mac)

### Inferences
- If built, the least-risky design avoids posting. Option one is a snippet *picker* (like the Clipboard panel) that copies to the clipboard, which MaxCandela already does: "It copies, it does not paste". Option two is a Services-menu / App Intents path.
- Effort: picker-style **small** (extends `ClipboardPanel`); true inline expansion **large**, with review risk.

### Gaps
- Could not verify how the current MAS text expanders insert text, or whether they are sandboxed. Direct confirmation of TextExpander leaving the MAS over sandboxing was not obtained; a MacStories headline was seen, but the link was malformed.

---

## 12. App quitter / "Quit all apps" / force quit

### Takeaway
**Not feasible** in the sandbox. Apple lists "Terminating other running apps" as a forbidden activity, and both `terminate()` and `forceTerminate()` fail in sandboxed builds.

### Cited Findings
- "Terminating other running apps" and "Sending Apple Events to arbitrary apps" are restricted. — [Apple: Protecting user data with App Sandbox](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox)
- DTS: the sandbox restricts one app's ability to interfere with another, so `terminate` fails. — [Apple forums 122020](https://developer.apple.com/forums/thread/122020)
- `forceTerminate` returned NO because the sandbox blocks the UNIX signal. — [Apple forums 664479](https://developer.apple.com/forums/thread/664479)
- Both calls returned false in a TestFlight build. — [Apple forums 768174](https://developer.apple.com/forums/thread/768174)
- The only reported workaround is sending ⌘Q via Accessibility, which its developer called a hack. — [Apple forums 721211](https://developer.apple.com/forums/thread/721211)

### Inferences
- The only fallback is to open Activity Monitor or tell the user about ⌥⌘⎋. Not worth building. Whether a sandboxed app can programmatically open the Force Quit window was not checked.
- Effort: n/a.

### Gaps
- None. Apple's doc is explicit.

---

## 13. Keyboard cleaning lock

### Takeaway
Feasible on paper with several cheap MAS precedents, all of which require **Accessibility**. That puts it in the PostEvent/active-tap tier: technically used in shipped apps, but carrying the §0 review uncertainty.

### Cited Findings
- KeyBlock ($0.99, MAS): "Lock keyboard, keep mouse and trackpad active", menu-bar toggle, "needs only Accessibility permission". — [KeyBlock, MAS](https://apps.apple.com/hn/app/keyblock-keyboard-protector/id6751187079?l=en-GB)
- Fuzzy (MAS, free) "will not work without Accessibility permissions". — [Fuzzy, MAS](https://apps.apple.com/us/app/fuzzy/id6476941106?mt=12)
- CleanMyKeyboard (MAS, free) stays locked until "Stop" is clicked. — [CleanMyKeyboard, MAS](https://apps.apple.com/us/app/cleanmykeyboard/id6468120888?mt=12)
- Cats Lock (2026) is a newer entrant. — [MacRumors, May 2026](https://macrumors.com/2026/05/15/cats-lock-mac-app/)
- Folivora's KeyboardCleanTool is not on the MAS. — [AddictiveTips](https://www.addictivetips.com/mac-os/disable-the-keyboard-on-macos-for-cleaning)

### Inferences
- Implementation: an active `CGEventTap` (`.defaultTap`) on keyDown, keyUp and flagsChanged that returns nil, with the unlock via a mouse click on an on-screen button. The power and Touch ID keys can't be blocked.
- KeyBlock's recent app ID (id6751187079, 2025) suggests a new sandboxed submission passed review with Accessibility. That is the best evidence the active-tap path works and is accepted, but it is inference.
- Effort: **small**.

### Gaps
- Unverified whether those apps are sandboxed, and whether an active tap in a sandbox needs Accessibility or Input Monitoring.

---

## 14. Camera mirror (Hand Mirror-style)

### Takeaway
Feasible. It needs `com.apple.security.device.camera` plus the camera TCC prompt (`NSCameraUsageDescription`). Hand Mirror is a direct MAS precedent.

### Cited Findings
- Hand Mirror (MAS, free + Plus IAP $6.99): menu-bar one-click camera preview, "keep your camera always on top". Requires macOS 14.4. — [Hand Mirror, MAS](https://apps.apple.com/us/app/hand-mirror/id1502839586)
- `device.camera` is a documented sandbox entitlement. — [Apple: App Sandbox](https://developer.apple.com/documentation/security/app-sandbox)

### Inferences
- `AVCaptureSession` + `AVCaptureVideoPreviewLayer` in a popover; Continuity Camera devices appear via `AVCaptureDevice.DiscoverySession`.
- This adds a new entitlement and privacy-label line (camera use; no data collected if local-only).
- Effort: **small**.

### Gaps
- None material.

---

## 15. Mouse jiggler, cursor highlighter / click visualiser, keystroke overlay

### Takeaway
- **Keystroke overlay:** feasible via a listen-only tap (Input Monitoring), with MAS precedent Keystroke Pro.
- **Cursor highlighter:** feasible (pointer position needs no permission; click rings need a listen tap).
- **Mouse jiggler:** posts events (PostEvent → Accessibility TCC). It has many MAS precedents, but it is a 2.4.5-flavoured risk, and Keep Awake already covers display sleep.

### Cited Findings
- Keystroke Pro (MAS, macOS 11+) shows keypresses for screen shares and recordings, and "doesn't capture input in secure password fields". — [Keystroke Pro, MAS](https://apps.apple.com/app/keystroke-pro/id1572206224)
- VisualKeysPro is another MAS keystroke visualiser. — [VisualKeysPro, MAS](https://apps.apple.com/be/app/visualkeyspro/id6499581386)
- Listen-only `CGEventTap` requires Input Monitoring and is sandbox-safe. — [Apple forums 780626](https://developer.apple.com/forums/thread/780626)
- MAS jigglers:
  - Mouse Jiggler: Cursor Mover ("works without requiring admin access") — [MAS](https://apps.apple.com/us/app/id6754509295)
  - Mouse Jiggler – Shake Cursor ("Move Cursor" mode for chat apps) — [MAS](https://apps.apple.com/us/app/mouse-jiggler-shake-cursor/id6738873590?mt=12)
  - Onliner — [MAS](https://apps.apple.com/app/onliner/id6738056056)
- Posting events maps to Accessibility TCC. — [Apple forums 820594](https://developer.apple.com/forums/thread/820594)
- A developer asks why `NSEvent.addGlobalMonitorForEvents` "still work[s] in a Sandboxed macOS app". This is a title-only signal that global *mouse* monitors work sandboxed. — [Apple forums 811443](https://developer.apple.com/forums/thread/811443)

### Inferences
- **Jiggler:** the "keep awake" half is already done by Keep Awake (`IOPMAssertion`). The incremental value is defeating chat-app idle status, which needs real synthetic events. Low value, nonzero review risk; skip, or implement as an `IOPMAssertion` variant only.
- **Cursor highlighter:** a transparent, click-through, all-Spaces overlay window following `NSEvent.mouseLocation` (no permission). Click rings come from a global mouse monitor or a listen-only tap. Effort **small–medium**.
- **Keystroke overlay:** effort **medium** (keycap rendering, modifier-only mode, multi-display placement). It adds the Input Monitoring prompt.

### Gaps
- No source found for Presentify's or other cursor highlighters' permission model.

---

## 16. Desktop curtain / hide desktop icons via overlay; notch hider

### Takeaway
Both are feasible as plain overlay windows, with many MAS precedents. One gotcha: mimicking the wallpaper by capturing it now requires Screen Recording on macOS 27. A notch hider is just a black, click-through, top-level window.

### Cited Findings
- MAS desktop-cover apps:
  - Desktop Icon Hider (covers with solid colour, photo, or "a copy of the current wallpaper") — [MAS](https://apps.apple.com/us/app/desktop-icon-hider/id1559439869?mt=12)
  - DeskMat — [MAS](https://apps.apple.com/app/id6742498342)
  - Hidesktop (macOS 14+, multi-display) — [MAS](https://apps.apple.com/us/app/hidesktop/id6756816613)
  - HiddenMe (a review reports icons reappearing when switching Spaces or full-screen apps) — [MAS](https://apps.apple.com/app/hiddenme/id467040476?mt=12)
  - DeskCover (also dims inactive windows) — [MAS](https://apps.apple.com/to/app/deskcover/id1257711898?mt=12)
- **macOS 27:** a "Hide Icons" app that captured wallpaper windows via `CGWindowListCreateImage` without a TCC prompt broke (gray image). DTS says Screen Recording is now the only way to capture wallpaper windows. — [Apple forums 849969](https://developer.apple.com/forums/thread/849969)
- MAS notch hiders:
  - Hide My Notch (black bar + gradient, adjustable height) — [MAS](https://apps.apple.com/us/app/id1591442999)
  - Hide Notch — [MAS](https://apps.apple.com/us/app/id1591163653)
  - Say No to Notch (instead "pushes the menu bar down below the notch") — [MAS](https://apps.apple.com/app/say-no-to-notch/id1639306886)

### Inferences
- **Curtain:** a borderless `NSWindow` at `CGWindowLevelForKey(.desktopIconWindow) + 1`, `canJoinAllSpaces`, filled with a solid colour or a user-picked image. For "looks like my wallpaper", use `NSWorkspace.desktopImageURL(for:)` and draw the file. That avoids Screen Recording, and MaxCandela already has Screen Recording anyway.
- **Notch hider:** a black, click-through window at desktop level covering the menu-bar strip, on screens where `NSScreen.safeAreaInsets.top > 0`, so the translucent menu bar reads as black. Some MAS apps may instead swap in a wallpaper with a black top band (unverified). The "below the notch" variant (Say No to Notch) probably selects a display mode without the notch rows via `CGDisplaySetDisplayMode` (unverified; see §17).
- Follow MaxCandela's own rule from the web app: no glows or gradients that would bloom under the XDR boost.
- Effort: curtain **small**; notch hider **small**.

### Gaps
- How Hide My Notch renders under a translucent Tahoe menu bar was not verified.

---

## 17. Display resolution switcher (incl. HiDPI), rotation, refresh rate

### Takeaway
Resolution and refresh-rate switching among the modes macOS already offers is feasible with public `CGDisplayCopyAllDisplayModes` / `CGDisplaySetDisplayMode`, with MAS precedent. *Creating* new HiDPI modes (BetterDisplay-style) and **rotation** have no public API found and are not MAS-feasible.

### Cited Findings
- `CGDisplaySetDisplayMode`: the mode "persists for the life of the calling program. When the program terminates, the display mode automatically reverts to the permanent setting in the Displays panel". For mirrored sets, wrap changes in `CGBeginDisplayConfiguration` / `CGCompleteDisplayConfiguration`. — [Apple: Changing Display Modes (archive)](https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/QuartzDisplayServicesConceptual/Articles/DisplayModes.html)
- Resolution Switcher is on the MAS (macOS 10.13+). — [MAS](https://apps.apple.com/us/app/id1053819476)
- DisplayProg's listing notes Apple requested removal of an "Advanced Menu", i.e. close review of this category. — [MAS](https://apps.apple.com/us/app/id1562922883)
- ResolutionMenu warns its private CoreGraphics calls for HiDPI modes "might keep it from being accepted into the Mac App Store". — [ResolutionMenu, GitHub](https://www.github.com/robbertkl/ResolutionMenu)
- Passing `kCGDisplayShowDuplicateLowResolutionModes` = true to `CGDisplayCopyAllDisplayModes` returns HiDPI (scaled) modes. The key is declared in `CGDirectDisplay.h` but poorly documented. — [cocoa-dev, May 2014](https://lists.apple.com/archives/cocoa-dev/2014/May/msg00273.html)
- SDL found it surfaced a mode that couldn't be switched to on some machines. — [SDL bug 3949](https://bugzilla.libsdl.org/show_bug.cgi?id=3949)
- Apple-silicon Macs "notoriously don't allow sub-4K resolution displays to have HiDPI". BetterDisplay works around this and offers rotation and refresh menus; it is distributed directly (Pro licence, Homebrew), not via the MAS. — [BetterDisplay wiki](https://github.com/waydabber/BetterDisplay/wiki/Fully-scalable-HiDPI-desktop); [BetterDisplay](https://github.com/waydabber/BetterDisplay)

### Inferences
- The revert-on-exit behaviour fits MaxCandela's "quit == back to normal" invariant, but users may expect the change to stick. Persisting it would need the configure-permanently option (`CGCompleteDisplayConfiguration(…, .permanently)`), whose sandbox behaviour is unverified.
- Refresh rate (ProMotion 120/60/48 Hz, external 144/60) is just another `CGDisplayMode` (`refreshRate`). Same path.
- Effort: **small–medium**. Interaction with the boost: a mode change fires `didChangeScreenParametersNotification`, which MaxCandela already debounces and re-parks triggers on.

### Gaps
- No public rotation API found. Whether `.permanently` works in a sandbox is untested.

---

## 18. Translation, dictation / speech-to-text, text-to-speech

### Takeaway
All feasible on-device.
- **Translation:** macOS 15+ via the SwiftUI `.translationTask` host. The UI-less `TranslationSession(installedSource:target:)` arrived only in **macOS 26.4**.
- **Speech-to-text:** `SpeechAnalyzer` / `SpeechTranscriber` (macOS 26) or `SFSpeechRecognizer`, needing the microphone entitlement plus mic and speech-recognition prompts.
- **TTS:** permission-free.

### Cited Findings
- `TranslationSession.init(installedSource:target:preferredStrategy:)` availability: "macOS: 26.4.0 -". "If one or both languages aren't installed on the device, attempting to translate will throw errors. To get the person's permission to download languages… translate using a `TranslationSession` provided by… `translationTask`." — [Apple doc](https://developer.apple.com/documentation/translation/translationsession/init(installedsource:target:preferredstrategy:))
- `.highFidelity` "uses Apple Intelligence models when available on device, or falls back to `lowLatency`". — same doc.
- The Translation framework was introduced at WWDC24. AppKit apps were advised to host a SwiftUI view via `NSHostingController`. — [WWDC24 10117](https://developer.apple.com/wwdc24/10117); [Apple forums 756837](https://developer.apple.com/forums/thread/756837?answerId=791116022)
- `SpeechAnalyzer` (WWDC25) runs on-device with a system-managed model. — [WWDC25 session 277](https://developer.apple.com/videos/play/wwdc2025/277/); [addpipe blog](https://blog.addpipe.com/apple-speechanalyzer-api/)
- `SpeechTranscriber.isAvailable` can be false on some hardware; check at runtime. — [Apple forums 806765](https://developer.apple.com/forums/thread/806765)
- Apple's entitlement index lists `com.apple.security.device.microphone`. — [Apple: App Sandbox](https://developer.apple.com/documentation/security/app-sandbox). A 2026 forum post refers to it as `com.apple.security.device.audio-input`. — [Apple forums 848578](https://developer.apple.com/forums/thread/848578). The naming differs between sources; use whatever Xcode's "Audio Input" checkbox writes.

### Inferences
- MaxCandela targets macOS 15.6, so translation needs a hidden SwiftUI host on 15.6–26.3 and can use the direct init on 26.4+. A "translate clipboard" or "translate OCR result" action pairs well with the existing Clipboard and Copy-Text-from-Screen tools.
- TTS: `AVSpeechSynthesizer` ("speak clipboard"), no permission. Effort **small**.
- Dictation-to-clipboard: effort **medium**; adds microphone and speech-recognition prompts and an entitlement. *Inserting* dictated text into the front app hits the §0 posting problem, so copy to clipboard instead.
- Translation: effort **small–medium**.

### Gaps
- No primary Apple statement found on the exact Info.plist keys for `SpeechAnalyzer` (the third-party source says `NSSpeechRecognitionUsageDescription` + mic).

---

## 19. QR code generator and reader

### Takeaway
Feasible with no new permission. Generation uses Core Image. Reading from an image or the clipboard uses Vision. Reading from the screen reuses the Screen Recording grant MaxCandela already has for OCR.

### Cited Findings
- MaxCandela's Copy Text from Screen already captures a region via `SCScreenshotManager.captureImage` and runs Vision (`VNRecognizeTextRequest`). — [repo CLAUDE.md](/Users/daniel/Codes/maxcandela/CLAUDE.md)

### Inferences
- Generate: the `CIQRCodeGenerator` filter → copy PNG to the clipboard. Read: `VNDetectBarcodesRequest` on the same captured region. "Scan QR on screen" is nearly free given the OCR pipeline.
- Effort: **small**.

### Gaps
- No external sources consulted; considered standard public API.

---

## 20. Image resize / convert / compress dropped files; PDF merge

### Takeaway
Feasible (ImageIO, PDFKit). The sandbox trap is the output location: writing `photo.webp` beside a dropped `photo.jpg` is denied unless you use related items, an `NSSavePanel`, a user-chosen output folder, or the Downloads entitlement.

### Cited Findings
- Writing adjacent to a user-selected file fails because "the sandbox only grants access to the selected file". — [Apple forums 769345](https://developer.apple.com/forums/thread/769345)
- Related items with `NSIsRelatedItemType` handle same-name, different-extension siblings; one developer also needed `CFBundleTypeRole` = Editor. — [Christian Tietze](https://christiantietze.de/posts/2020/05/related-files/)
- One developer reports "Failed to issue extension" even with related items. — [Apple forums 813856](https://developer.apple.com/forums/thread/813856)
- The fallback is to "ask the user to choose the folder". — [Apple forums 769345](https://developer.apple.com/forums/thread/769345)
- `files.downloads.read-write` is a documented entitlement. — [Apple: App Sandbox](https://developer.apple.com/documentation/security/app-sandbox)

### Inferences
- Simplest MAS-safe UX: drop files on the shelf → output goes to ~/Downloads (`files.downloads.read-write`) or an `NSSavePanel` / folder picker remembered via a security-scoped bookmark. Pairs naturally with the File Shelf (§1).
- Effort: **small–medium**.

### Gaps
- No MAS precedent checked for this specific category.

---

## 21. Dim inactive windows (HazeOver-style)

### Takeaway
Partially feasible. An overlay that dims everything except the frontmost app's windows can be built from `CGWindowListCopyWindowInfo` bounds plus `NSWorkspace` activation, without AX. Matching HazeOver's precision (focused-window tracking via AX) runs into the §0 Accessibility block.

### Cited Findings
- HazeOver is on the MAS ($4.99) and dims background windows (35% by default). — [HazeOver, MAS](https://apps.apple.com/app/id430798174); [Daring Fireball, Mar 2026](https://daringfireball.net/2026/03/hazeover)
- It "can use macOS Accessibility to improve focus detection" (third-party listing). — [FileHorse](https://mac.filehorse.com/download-hazeover-distraction-dimmer)
- Its MAS app ID (430798174) dates from the 2011 era, pre-sandbox-mandate (see Quinn's caveat, [Apple forums 707680](https://developer.apple.com/forums/thread/707680)).
- DeskCover (MAS) also dims inactive windows. — [DeskCover, MAS](https://apps.apple.com/to/app/deskcover/id1257711898?mt=12)
- Accessibility APIs are restricted in the sandbox. — [Apple: Protecting user data with App Sandbox](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox)

### Inferences
- Approach: one full-screen click-through overlay per display, at a level just below the frontmost app's windows, punched out (masked) over the frontmost app's window rects from `CGWindowListCopyWindowInfo(.optionOnScreenOnly)` (`kCGWindowBounds`, `kCGWindowOwnerPID`). Bounds don't require Screen Recording (only window *names* do since 10.15). This is unverified for macOS 26/27 and must be tested, given the macOS 27 `CGWindowList*` tightening in §16.
- It is the same "gamma vs overlay" family as Extra Dim. The overlay must not sit above the EDR trigger windows, or it would interact with the boost.
- Effort: **medium** (window-ordering edge cases, Spaces, full-screen apps, live window moves at 30–60 Hz).

### Gaps
- Not verified: whether `CGWindowListCopyWindowInfo` bounds remain permission-free on macOS 26/27.

---

## 22. Focus / Do Not Disturb toggle

### Takeaway
There is no public API to set Focus. The only supported route is a user-built Shortcut using the system "Set Focus" action, which MaxCandela's existing Shortcuts runner can already launch.

### Cited Findings
- A developer forum request for programmatic Focus on/off on macOS has no Apple answer. — [Apple forums 729475](https://developer.apple.com/forums/thread/729475)
- Community tools rely on UI scripting or private preference structures. The legacy `doNotDisturb` pref works only before Big Sur. — [sindresorhus/do-not-disturb-cli](https://github.com/sindresorhus/do-not-disturb-cli)
- The OmniGroup developer says the system supplies a Focus Shortcuts action "so the user can programmatically reconfigure their Focus settings using Shortcuts". — [Omni Group forum](https://discourse.omnigroup.com/t/how-should-set-omnifocus-focus-filter-while-in-focus-mode-be-used-in-shortcuts/70708)
- Writing other apps' preferences is a sandbox-restricted activity. — [Apple: Protecting user data with App Sandbox](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox)
- MaxCandela's Shortcuts tool runs `shortcuts://run-shortcut?name=`. — [repo CLAUDE.md](/Users/daniel/Codes/maxcandela/CLAUDE.md)

### Inferences
- Ship a "Focus" row that runs a named Shortcut ("MaxCandela Focus On/Off"), with an onboarding link to install a pre-made shortcut via an iCloud link. Effort **small**. A pure in-app toggle: not feasible.

### Gaps
- Whether `INFocusStatusCenter` (read-only Focus status) is usable on macOS by non-communication apps was not researched.

---

## 23. Night Shift / True Tone toggle

### Takeaway
Not feasible with public API: Night Shift is controlled via the private `CBBlueLightClient` (CoreBrightness). MaxCandela's own Warmth gamma tint is already the public-API substitute. True Tone: no public API found.

### Cited Findings
- `CBBlueLightClient` lives in the private CoreBrightness framework (`setStrength:commit:`, `setEnabled:`). — [MacScripter](https://macscripter.net/viewtopic.php?pid=200999); [smudge/nightlight](https://github.com/smudge/nightlight)
- Apple forum answer: "there is currently not an API for determining if Night Shift is active". — [Apple forums 43356](https://developer.apple.com/forums/thread/43356)
- f.lux publicly asked Apple to open a Night Shift API in 2016. — [AppleInsider](https://appleinsider.com/articles/16/01/14/flux-says-it-is-original-innovator-of-nighttime-display-color-tech-asks-apple-to-open-night-shift-api)

### Inferences
- MaxCandela's CLAUDE.md already flags that a cached gamma base table may go stale under Night Shift / True Tone while Warmth is held. The interaction risk exists regardless of whether a toggle is added. Effort: n/a.

### Gaps
- True Tone has no public API; nothing primary was found either way.

---

## 24. Per-app volume (and, by extension, volume boost)

### Takeaway
**More feasible than the developer assumed.** Core Audio process taps (`AudioHardwareCreateProcessTap`, macOS 14.2+) with `CATapMutedWhenTapped` let an app mute a process's direct output and re-render it at its own gain, with no audio driver. A 2026 report says this works inside the App Sandbox, and at least one MAS app (VolumeHub) markets per-app volume built on it. Evidence is thin (no Apple statement, one sandbox report), so it needs a spike.

### Cited Findings
- A developer (Sep 2026) reports: "AudioHardwareCreateProcessTap with a CATapDescription that excludes the app's own process and uses CATapMutedWhenTapped… works inside the App Sandbox with com.apple.security.device.audio-input; no microphone usage string is required for a tap". It also needs a "system audio permission". Caveats from the same post:
  - "Two process taps on the same device from different processes interfere with each other". This conflicts with SoundSource-style apps running at the same time.
  - "The tap delivers IOProc callbacks only while some process is rendering".
  - No Apple reply.
  — [Apple forums 848578](https://developer.apple.com/forums/thread/848578)
- VolumeHub is listed on the MAS advertising per-app volume sliders on Apple's Audio Tap API. — [VolumeHub, MAS](https://apps.apple.com/us/app/volumehub/id6758415969)
- Muted-when-tapped routes the app's audio through the tap, where volume can be changed. — [DEV Community](https://dev.to/thalesbmc_75/macos-still-has-no-volume-mixer-so-i-built-one-cmb)
- Reference implementation: [insidegui/AudioCap](https://github.com/insidegui/AudioCap)
- Reported problems:
  - Per-app levels vary with output routing and channel-pair count — [Apple forums 806799](https://developer.apple.com/forums/thread/806799)
  - All-zero buffers while audio is audible — [Apple forums 825780](https://developer.apple.com/forums/thread/825780)
- `AudioHardwareTap` class doc lists macOS 15.0+, and the tap API is reported as introduced in 14.2. — [Apple doc](https://developer.apple.com/documentation/coreaudio/audiohardwaretap)

### Inferences
- MaxCandela's deployment target (15.6) clears the API floor. The same mechanism with gain > 1.0 would also give a per-app **volume boost** (with a limiter to avoid clipping). That reopens an item the developer ruled out as "needs an audio driver".
- Costs:
  - New entitlement (microphone/audio-input) and a system-audio-recording TCC prompt
  - Latency
  - Fighting other tap-based apps
  - Re-creating taps as apps launch and quit
  - Privacy-label review: audio is processed locally, nothing collected
- Effort: **large**, and it needs a hardware spike before committing.

### Gaps
- No Apple documentation or DTS statement confirms process taps in sandboxed MAS apps. VolumeHub's sandbox status and implementation were not verified. The exact Info.plist key for the system-audio permission was not confirmed from a primary source (`NSAudioCaptureUsageDescription` is the commonly cited key).

---

## 25. Consolidated feasibility matrix (synthesis of the sections above)

### Takeaway
Of the 24 candidates:
- **~13** are clean wins: no new risky permission, small–medium effort, clear MAS precedent.
- **~5** are feasible but add a new entitlement or prompt.
- **~4** sit in the Accessibility/PostEvent grey zone.
- **~4** are infeasible or redundant.

### Cited Findings
- See per-section citations; this section only aggregates them.

### Inferences

| Tool | Feasible (MAS sandbox)? | API | New entitlement / permission for MaxCandela | Precedent on MAS | Effort |
|---|---|---|---|---|---|
| File shelf | Yes | AppKit drag & drop, bookmarks | `files.user-selected.read-write` (+ bookmarks) | Dropover, Yoink | M |
| Screenshot + annotate | Yes | ScreenCaptureKit | none new (Screen Recording already) | Xnip, Longshot | M |
| Screen → GIF/video | Yes | SCStream + ImageIO/AVAssetWriter | none new | Gifox 2 | M |
| Scrolling capture | Yes, if the user scrolls | SCK + stitching | none (auto-scroll = PostEvent risk) | Xnip, Longshot | L |
| Charge limit | **No** (SMC/root); redundant on 26.4+ | — | — | none (AlDente is direct) | — |
| Battery read-outs | Yes | IOKit.ps, AppleSmartBattery | none | — | S |
| Bluetooth quick-connect | Yes | IOBluetooth | `device.bluetooth` + BT prompt | ToothFairy | S–M |
| AirPods battery | Partly | IOBluetooth/IORegistry (undocumented) | `device.bluetooth` | ToothFairy | M |
| Wi-Fi SSID | Yes, with Location | CoreWLAN + CoreLocation | `personal-information.location` + prompt | — | M |
| Net speed / public IP / TCP latency | Yes | getifaddrs, URLSession, NWConnection | none (network.client already) | iStat Menus 7 | S |
| ICMP ping | Uncertain | SOCK_DGRAM ICMP | maybe `network.server` too | — | S–M |
| Pomodoro / breaks / 20-20-20 | Yes | timers, overlay | none (optional notifications) | many | S |
| Notes / to-do | Yes | AppKit | none (local) | many | S |
| Calendar month view | Yes | EventKit | none new | Dato | M |
| Weather | Yes | WeatherKit | WeatherKit capability; Location optional | many | M |
| Units / currency / calc | Yes | Foundation | none | many | S |
| Text expansion (inline) | Risky | listen tap + CGEvent.post | Input Monitoring + Accessibility; 2.4.5 risk | TypeIt4Me 7, Fast Text | L |
| Snippet picker (copy only) | Yes | ClipboardPanel | none | — | S |
| Quit / force-quit apps | **No** | — | forbidden by sandbox | — | — |
| Keyboard cleaning lock | Probably | active CGEventTap | Accessibility TCC | KeyBlock, Fuzzy | S |
| Camera mirror | Yes | AVFoundation | `device.camera` + prompt | Hand Mirror | S |
| Mouse jiggler | Risky / low value | CGEvent.post | Accessibility TCC | several | S |
| Cursor highlighter | Yes | overlay + mouse monitor | none or Input Monitoring | — | S–M |
| Keystroke overlay | Yes | listen-only CGEventTap | Input Monitoring prompt | Keystroke Pro | M |
| Desktop curtain | Yes | overlay window | none | Desktop Icon Hider, Hidesktop | S |
| Notch hider | Yes | overlay window | none | Hide My Notch | S |
| Resolution / refresh switch | Yes (existing modes) | CGDisplaySetDisplayMode | none | Resolution Switcher | S–M |
| Custom HiDPI modes / rotation | **No** public API | private | — | none (BetterDisplay is direct) | — |
| Translation | Yes | Translation (15+, UI-less 26.4+) | none | — | S–M |
| Dictation → clipboard | Yes | SpeechAnalyzer / SFSpeech | microphone + speech prompts | — | M |
| Text-to-speech | Yes | AVSpeechSynthesizer | none | — | S |
| QR generate / read | Yes | Core Image / Vision | none new | — | S |
| Image convert / PDF merge | Yes | ImageIO / PDFKit | `files.user-selected` / `files.downloads` | — | S–M |
| Dim inactive windows | Partly | overlay + CGWindowList | none, if CGWindowList bounds stay free | HazeOver (legacy), DeskCover | M |
| Focus / DND toggle | Only via Shortcuts | shortcuts:// | none | — | S |
| Night Shift / True Tone | **No** (private) | CBBlueLightClient | — | — | — |
| Per-app volume / volume boost | Plausibly | Core Audio process taps | mic/audio-input + system-audio prompt | VolumeHub (claimed) | L |

- Highest value per unit of risk for MaxCandela specifically:
  1. QR + "scan QR on screen" (reuses the OCR pipeline)
  2. Desktop curtain + notch hider (overlay infrastructure already exists for EDR triggers)
  3. Network speed / public IP / latency
  4. Calendar month view (permission already held)
  5. Resolution / refresh switcher (display domain fits the brand)
  6. Screenshot + annotate (permission already held)
  7. Camera mirror (one new entitlement)
- **Urgent non-new-tool finding:** sandbox-test the existing Window Snapping tool. DTS states AX window control is unsupported in sandboxed apps ([Apple forums 854711](https://developer.apple.com/forums/thread/854711)), and the site copy advertises it.

### Gaps
- Effort sizes are judgement calls, not measured. Precedent apps' sandbox status was not individually verified with `codesign`.
- **macOS 26 menu-bar changes** (e.g. any new system-level hiding of third-party menu-bar items that could affect Hide Menu Bar Icons and the overall toolbox) were not researched.
