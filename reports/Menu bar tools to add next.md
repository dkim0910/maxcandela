# Build screenshots next, but fix Pro first

MaxCandela's next tool should be **screen capture with annotation, sold as Pro**. After it come a **menu-bar month calendar**, a **background-window dimmer**, a **file shelf that converts dropped files**, and **QR scan and generate**. Each one either reuses a permission the app already holds (Screen Recording, Calendar) or needs no permission, and none of the free Mac App Store toolboxes offers the Pro ones. Two shipped Pro tools need attention before any of this. Apple's Developer Technical Support (DTS) engineer says a sandboxed app cannot move other apps' windows through the Accessibility API. The App Store build of Hidden Bar now tells buyers it "cannot hide icons" on macOS 27 "because the App Store sandbox blocks it", and MaxCandela's Hide Menu Bar Icons uses the same technique. These are the two Pro tools tied to the biggest paid markets in the data: window snapping charts in every storefront checked, and menu-bar management has the largest Setapp rating count. If both fail, the Pro tier loses its two strongest "replaces a paid app" claims. Meanwhile free App Store toolboxes such as BarBox Tools and Octobar already give away OCR, QR codes, clipboard history and Shortcut launching. Several popular requests should not be built at all: a battery charge limiter (built into macOS 26.4), quitting other apps, Night Shift and Dark Mode toggles, and inline text expansion. Reddit could not be read, so the demand ranking rests on Setapp rating counts, App Store chart ranks and Hacker News. The feasibility verdicts come from Apple documentation and DTS, so the Reddit gap does not affect them.

## Window Snapping and Hide Menu Bar Icons probably fail where they are sold

**Window Snapping calls an API that DTS says sandboxed apps cannot use.** MaxCandela's `WindowSnapTool` first checks `AXIsProcessTrustedWithOptions`. It then reads the front app's focused window with `AXUIElementCopyAttributeValue`, and moves it with `AXUIElementSetAttributeValue`. If that read fails, the tool beeps and returns ([WindowSnapTool.swift](/Users/daniel/Codes/maxcandela/apps/macos/Sources/MaxCandela/Tools/WindowSnapTool.swift)). Apple's list of activities the operating system forbids in a sandboxed app includes **"Use of accessibility APIs in assistive apps"** ([Apple](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox)). In March 2026, DTS split the three input privileges apart. Listening to input and posting synthetic events both work in a sandbox. The APIs behind the Accessibility privilege itself are **"not compatible with the App Sandbox"** ([Apple forums 820594](https://developer.apple.com/forums/thread/820594)). In a late-2026 thread, a developer asked whether a sandboxed app can move, resize or focus other apps' windows. Quinn of DTS said:

- the sandbox blocks it;
- no public API or entitlement allows it;
- no supported App Store architecture achieves it;
- "There's no 'make Accessibility work' temporary exception entitlement."

He recommended Developer ID distribution instead ([Apple forums 854711](https://developer.apple.com/forums/thread/854711)). Another developer describes exactly the failure MaxCandela's code would hit: `AXIsProcessTrusted` returns true and `AXUIElementCopyAttributeValue` still fails with `.cannotComplete` ([Apple forums 794253](https://developer.apple.com/forums/thread/794253)). For a paying user, that means granting Accessibility, pressing ⌃⌥←, and hearing a beep. The project's own notes record that the tool was **never run** with an Accessibility grant ([CLAUDE.md](/Users/daniel/Codes/maxcandela/CLAUDE.md)). The development binary is an unsandboxed `swift run` build, so it could not reproduce the failure in any case.

The obvious objection is that **Magnet is #2 among US paid Productivity apps and carries Editor's Choice** ([chart](https://apps.apple.com/us/mac/charts/6007?chart=top-paid), [listing](https://apps.apple.com/us/app/magnet/id441258766)). BetterSnapTool and Moom Classic chart as well. Those listings are weak precedent. Magnet's app ID dates from 2011, and Quinn has warned that **"Not all Mac App Store apps are sandboxed"** because some shipped before sandboxing became mandatory ([Apple forums 707680](https://developer.apple.com/forums/thread/707680)). Another developer reports that App Store Connect refused their unsandboxed Accessibility app, while the older window managers stayed on sale ([Apple forums 836644](https://developer.apple.com/forums/thread/836644)). The window-management apps that are newer and well known stay off the store and say why: the Lasso developer says the sandbox would limit it, and Supercharge's developer says much of that app "wouldn't be possible there because of sandboxing" ([AlternativeTo](https://alternativeto.net/software/lasso-window-manager/about), [Supercharge](https://sindresorhus.com/supercharge)). The stakes are high. Rectangle was the single most-recommended app in HN's 2026 new-Mac thread ([HN](https://news.ycombinator.com/item?id=48643848)), and window snapping is the clearest *paid* category on the Mac App Store. MaxCandela most likely cannot sell into it from the sandbox.

**Hide Menu Bar Icons faces a separate failure on macOS 27, which has already shipped.** The App Store description of Hidden Bar 1.13.1, updated 2026-11-21, reads: **"On macOS 27 this App Store version cannot hide icons, because the App Store sandbox blocks it,"** and points buyers to the free direct download ([iTunes lookup](https://itunes.apple.com/lookup?id=1452453066&country=us)). Octobar, a 2026 App Store toolbox, labels its icon-hiding module **"temporarily unavailable on macOS 27"** ([Octobar](https://apps.apple.com/app/id6766087919)). MaxCandela's `MenuBarHiderTool` uses the same Hidden Bar technique: a divider status item whose length jumps to 10,000 points to push icons off screen ([MenuBarHiderTool.swift](/Users/daniel/Codes/maxcandela/apps/macos/Sources/MaxCandela/Tools/MenuBarHiderTool.swift)). A vendor blog covering the macOS 27 beta says three things changed:

- the menu bar now renders as a single window;
- Apple added a native overflow arrow near the notch;
- Ice, Thaw, Bartender and Hidden Bar all broke in beta 1.

That blog sells a competing app ([Badgeify](https://badgeify.app/macos-27-golden-gate-menu-bar-changes/)). The Ice issue tracking macOS 27 breakage has about 55 upvotes and no maintainer reply ([GitHub](https://github.com/jordanbaird/Ice/issues/954)). One HN user wrote on 20 November 2026 that "Since switching to version 27.2, that need has gone away for now" ([HN](https://news.ycombinator.com/item?id=50573415)). The tool may therefore be **broken and redundant at the same time** on the newest OS. It probably still works on macOS 26: a MacRumors poster says Hidden Bar "has worked thru every beta & official version of tahoe" ([MacRumors](https://forums.macrumors.com/threads/best-bartender-replacement-fur-2026.2476628/)). The two developers' statements are store copy, not Apple documentation. No one in this research verified the macOS 27 behaviour on hardware.

The practical sequence follows from this. First, run Window Snapping in the **sandboxed** `dist/` or Xcode build on macOS 26 and 27. Run Hide Menu Bar Icons on a macOS 27.x Mac. The development Mac runs Darwin 25.6, which is macOS 26, so the second test needs another machine or an upgrade. Second, if either fails, gate it by OS or pull it from the Pro list, the website and the 2.0.0 listing draft before submission. Third, do not refill the Pro tier by moving free tools behind the paywall. Store reviews punish exactly that. An iBar reviewer complained the free app "became paid" ([App Store](https://apps.apple.com/us/app/ibar-menubar-icon-control-tool/id6443843900?mt=12&see-all=reviews&platform=mac)), and a Menuist reviewer objected that the features they wanted were greyed out ([App Store](https://apps.apple.com/us/app/menuist-right-click-menubar/id6737160756?mt=12)).

Three further risks matter less, but the Pro pitch still has to answer them.

- **Free App Store toolboxes undercut the other Pro tools.**
  - BarBox Tools, released August 2026, is free with no in-app purchase. It includes OCR, a QR generator, 20-item clipboard history, keep-awake, a timer, generators, IP info and mic mute ([App Store](https://apps.apple.com/app/id6802093315)).
  - Octobar's free tier allows five modules, chosen from a list that includes Run Shortcut, Read QR Code, Translate and Stay Awake ([App Store](https://apps.apple.com/app/id6766087919)).
  - MeetingBar is free on the store ([GitHub](https://github.com/leits/MeetingBar)).
  - After those overlaps, the Pro tools that remain hard to copy are the **XDR boost**, which none of nine competitor toolboxes advertises, and the **Clipboard Manager**, whose paid demand Maccy proves at $9.99, #7 in US Productivity ([chart](https://apps.apple.com/us/mac/charts/6007?chart=top-paid)).
- **Screen Recording prompts recur.** macOS 15 re-asks monthly for Screen Recording permission ([TidBITS](https://tidbits.com/2024/08/19/apple-reduces-excessive-sequoia-permission-requests-shifts-to-monthly)), and commenters report that only the system's own window picker avoids it ([9to5Mac](https://9to5mac.com/2024/08/14/macos-sequoia-screen-recording-prompt-monthly/?extended-comments=1)). That nag affects Copy Text from Screen today and any capture tool added later.
- **The clipboard manager's "copies, does not paste" design is correct.** Clipboard managers that post ⌘V were rejected under Guideline 2.4.5 in March and September 2026 ([Apple forums 820594](https://developer.apple.com/forums/thread/820594)).

## Screen capture leads a shortlist built on permissions already held

The ranking uses five tests: measured demand (chart rank, Setapp rating count, GitHub stars, toolbox prevalence), sandbox fit, effort, whether a free or entrenched rival already owns the job, and fit with a display-first brand. Effort sizes are judgement calls, not measurements. A "toolbox" count of four out of nine means four of the nine multi-tool competitors examined list the feature.

| # | Tool | Tier | Strongest demand signal | Sandbox route; new entitlement or prompt | Effort | Who already owns it |
|---|---|---|---|---|---|---|
| 1 | Screenshot capture + annotate (later GIF/video) | Pro | CleanShot X 14,477 Setapp ratings; Greenshot charts US #14, GB #11 | ScreenCaptureKit; **none new** (Screen Recording already granted) | M (scrolling capture L) | Paid leader is off the App Store at $35 + $19/yr; no App Store toolbox has it |
| 2 | Menu-bar calendar (month grid + agenda; absorbs Next Meeting, World Clock) | Grid free, events Pro | Dato $18 (881 Setapp); InstaCal €22.99 DE #20; Itsycal 4,058 stars | EventKit; **none new** (calendar entitlement held) | M | Itsycal free but not on the App Store; Dato is the paid anchor |
| 3 | Background-window dimmer | Pro | HazeOver $4.99 charts US #13, GB #4, JP #12; 1,210 Setapp | Overlay + window bounds, no Accessibility; **none** if bounds stay free (spike first) | M | HazeOver entrenched but pre-sandbox; no toolbox has it |
| 4 | File shelf + drop-to-convert | Pro | Yoink 1,967 Setapp, JP #14; HEIC→JPG Ask HN, 47 comments | Drag and drop; `files.user-selected.read-write` + `files.downloads.read-write` | M | Yoink and Dropover sell on the App Store; conversion free in BarBox |
| 5 | QR generate + scan from screen | Generate free, scan Pro | Minimal QR Code JP #8 paid; 4 of 9 toolboxes | Core Image + Vision; **none new** | S | Free in BarBox and Octobar (parity, not a hook) |
| 6 | Desktop curtain + notch hider | Free | HiddenMe JP #4 paid; hide-desktop in 3 of 9 toolboxes | Overlay windows; **none** | S | Many cheap App Store apps; Octobar free |
| 7 | Bluetooth / AirPods quick-connect | Pro | AirBuddy 1,579 Setapp; ToothFairy $6.99 | IOBluetooth; `device.bluetooth` + Bluetooth prompt | S–M | ToothFairy sells on the App Store; BarBox shows battery free |
| 8 | Focus timer + break reminders (extends Timer) | Free | Session 2,100 Setapp; SitTall $5.99 | Timers + overlay; **none** | S | Free everywhere (parity) |
| 9 | Scratchpad / quick notes | Free | SideNotes $12.99 at US #11; Unclutter 652 Setapp | App container; **none** | S | Raycast notes free (parity) |
| 10 | Per-app volume + volume boost | Pro | Background Music 19,400 stars; Boom 3D 1,791 Setapp | Core Audio process taps; audio-input entitlement + system-audio prompt | L, spike first | Free leaders are off the App Store; VolumeHub is the only App Store entrant found |

### 1. Screen capture fills the largest uncovered paid pool

Screenshots are the biggest demand pool MaxCandela doesn't cover. On Setapp, CleanShot X has **14,477 ratings at 99%**, second only to Bartender among menu-bar apps ([Setapp](https://setapp.com/apps/cleanshot)). On the Mac App Store, the $1.99 Greenshot charts **#14 in US and #11 in GB paid Productivity** ([US](https://apps.apple.com/us/mac/charts/6007?chart=top-paid), [GB](https://apps.apple.com/gb/mac/charts/6007?chart=top-paid)).

The leader has left room underneath it. CleanShot now costs **$35 with one year of updates, then $19 a year**, and is not on the App Store ([CleanShot](https://cleanshot.com/pricing)). HN users call its cloud "overpriced" ([HN](https://news.ycombinator.com/item?id=45826010)) and say they "got tired of paying for cleanshotx and missing features in shottr" ([HN](https://news.ycombinator.com/item?id=49241402)). Shottr, the free alternative, is a direct download ([Shottr](https://shottr.cc/)). None of the App Store toolboxes examined (Barista, UtilsBar, BarBox, SuperMenuBar) lists capture with annotation.

Building it is an extension, not a new start. `ScreenTextTool` already captures a region with `SCScreenshotManager` and runs Vision on it ([ScreenTextTool.swift](/Users/daniel/Codes/maxcandela/apps/macos/Sources/MaxCandela/Tools/ScreenTextTool.swift)), so capture → annotate → copy reuses the region overlay and the permission. Xnip, Longshot and Gifox 2 show the category passes review ([Xnip](https://apps.apple.com/us/app/id1221250572), [Longshot](https://apps.apple.com/app/id6450262949), [Gifox 2](https://apps.apple.com/us/app/gifox-2/id1461845568?mt=12)). Defer scrolling capture. Stitching frames is a large job, and scrolling the target app automatically would post synthetic events, which is the 2.4.5 risk. Let the user scroll instead.

Put OCR, QR, colour picking and annotation under one capture shortcut. That is the kind of suite a $35 incumbent sells, and it is where a $9.99 Pro unlock looks cheap.

### 2. A month calendar completes tools already half-built

Several paid calendars show demand, and so does one free one:

- **Dato** sells for $18 on the App Store and has 881 Setapp ratings ([App Store](https://apps.apple.com/us/app/dato/id1470584107), [Setapp](https://setapp.com/apps/dato)).
- **InstaCal**, a €22.99 menu-bar calendar, sits at #20 in German paid Productivity ([chart](https://apps.apple.com/de/mac/charts/6007?chart=top-paid)).
- **Itsycal** has **4,058 GitHub stars** and is a direct download, not on the App Store ([GitHub](https://github.com/sfsam/Itsycal), [Mowglii](https://www.mowglii.com/itsycal/)).

A calendar dropdown appears in four of nine toolboxes, and calendar or meeting tools appear in four of nine 2026 roundups. One user put the wish plainly: "I would like a better calendar app with a nicer UX" ([HN](https://news.ycombinator.com/item?id=39164210)).

The marginal permission cost is zero. The shipping entitlements already include `personal-information.calendars` ([entitlements](/Users/daniel/Codes/maxcandela/apps/macos/Resources/MaxCandela.entitlements)). Effort is medium: the grid, event dots, week numbers and first-weekday localisation take the work.

The tier split follows from the permission. A bare month grid needs no Calendar access, so it can be free. Events and one-click join need it, and belong in Pro beside Next Meeting. Merging the grid with the free World Clock and Next Meeting gives MaxCandela a Dato-equivalent, since Dato is likewise a calendar, world clock and meeting alert in one.

### 3. Background-window dimming extends the display franchise

HazeOver charts in three storefronts at $4.99: **#13 in US, #4 in GB and #12 in JP** paid Productivity ([US](https://apps.apple.com/us/mac/charts/6007?chart=top-paid), [GB](https://apps.apple.com/gb/mac/charts/6007?chart=top-paid), [JP](https://apps.apple.com/jp/mac/charts/6007?chart=top-paid)). It also has **1,210 Setapp ratings at 99%** ([Setapp](https://setapp.com/apps/hazeover)). Few signals in this data are as consistent, and none of the nine toolboxes lists background-window dimming. It sits naturally beside the XDR boost, Extra Dim and Warmth, the one feature family no App Store toolbox competes in.

Copying HazeOver's method would not work. HazeOver "can use macOS Accessibility to improve focus detection" ([FileHorse](https://mac.filehorse.com/download-hazeover-distraction-dimmer)), and its app ID predates the sandbox rule. MaxCandela would need a different design: one click-through overlay per display, with holes cut over the frontmost app's windows using the bounds from `CGWindowListCopyWindowInfo` and `NSWorkspace` activation events. That design needs no Accessibility.

Run a spike first. Window bounds have historically not required Screen Recording, but macOS 27 tightened `CGWindowList` capture ([Apple forums 849969](https://developer.apple.com/forums/thread/849969)), and nobody has checked whether bounds are still free. The overlay must also stay below MaxCandela's EDR trigger windows, or it will interfere with the boost.

### 4. A file shelf earns Pro; conversion alone does not

Yoink is the paid evidence. It costs $8.99, ranks **#14 in Japan's paid Utilities**, and has **1,967 Setapp ratings at 99%** ([Setapp](https://setapp.com/apps/yoink), [JP chart](https://apps.apple.com/jp/mac/charts/6002?chart=top-paid)). Dropzone has 1,204 Setapp ratings ([Setapp](https://setapp.com/apps/dropzone)), and Bartender put a Files shelf into its new $15-a-year Pro tier ([Six Colors](https://sixcolors.com/post/2026/05/bartender-6s-new-pro-feature-turns-the-macbook-notch-into-a-dynamic-peninsula/)). Conversion has its own demand: the Ask HN "How are most people converting HEIC to jpg?" drew 47 comments ([HN](https://news.ycombinator.com/item?id=46326261)), and Clop sells format optimisation at €15 ([Clop](https://lowtechguys.com/clop/)). But UtilsBar and BarBox already convert images and merge PDFs, BarBox for free, so the shelf is what earns Pro.

The sandbox shapes the design in three ways:

- **Access to dropped files.** Drag and drop grants access to the dropped items, but keeping the shelf across launches requires security-scoped bookmarks.
- **Where output can go.** Writing `photo.jpg` next to a dropped `photo.heic` is denied, because "the sandbox only grants access to the selected file" ([Apple forums 769345](https://developer.apple.com/forums/thread/769345)). Output must go to Downloads or to a folder the user picks. That means adding the `files.user-selected.read-write` and `files.downloads.read-write` entitlements.
- **A macOS 26 regression.** macOS 26 hands dragged files over as temporary SwiftUI drag paths, which broke Yoink and Dropover ([HN](https://news.ycombinator.com/item?id=47442781)). Test this on day one.

### 5. QR codes are cheap parity riding on the OCR pipeline

QR has modest but real demand: Minimal QR Code is **#8 in Japan's paid Utilities** ([chart](https://apps.apple.com/jp/mac/charts/6002?chart=top-paid)), and QR generation or scanning appears in four of nine toolboxes, Octobar's "Read QR Code" module among them ([App Store](https://apps.apple.com/app/id6766087919)). The cost is small. Core Image's QR filter generates codes, and Vision's barcode request can run on the region Copy Text from Screen already captures, so no new permission is needed.

It is not a reason to pay. BarBox generates QR codes for free. So keep the generator free, and add "copy text *or* QR" to the existing Pro capture instead of creating a separate Pro tool.

### 6. A desktop curtain and notch hider are small free hooks

Hiding desktop icons sells even as a single toggle. HiddenMe, a ¥300 app that does only that, ranks **#4 in Japan's paid Utilities** ([chart](https://apps.apple.com/jp/mac/charts/6002?chart=top-paid)). The feature also appears in One Switch, OnlySwitch and Supercharge, and as Octobar's "Tidy Desktop" and "Hide Notch" modules. Notch frustration runs deep. One HN user with eleven third-party icons bought "notch optimizer" apps ([HN](https://news.ycombinator.com/item?id=46447082)). Others push the menu bar below the notch with Say No to Notch or BetterDisplay ([HN](https://news.ycombinator.com/item?id=45260500)).

Both tools are plain overlay windows with established App Store precedent ([Desktop Icon Hider](https://apps.apple.com/us/app/desktop-icon-hider/id1559439869?mt=12), [Hidesktop](https://apps.apple.com/us/app/hidesktop/id6756816613), [Hide My Notch](https://apps.apple.com/us/app/id1591442999)). MaxCandela already builds overlay windows for its EDR triggers.

One trap: to make the curtain look like the wallpaper, draw the file from `NSWorkspace.desktopImageURL(for:)`. Capturing the wallpaper window now requires Screen Recording on macOS 27 ([Apple forums 849969](https://developer.apple.com/forums/thread/849969)). Keep both overlays free of glows and gradients, which would bloom under the boost. Make both free, since rivals give the same toggles away.

### 7. Bluetooth quick-connect sells, but battery data is uncertain

Bluetooth device tools have paid users: AirBuddy has **1,579 Setapp ratings** ([Setapp](https://setapp.com/apps/airbuddy)), and ToothFairy sells for $6.99 on the App Store with 422 Setapp ratings ([Setapp](https://setapp.com/apps/toothfairy)). One Switch features an AirPods switch, and its reviewers ask for broader Bluetooth device support ([Setapp reviews](https://setapp.com/apps/one-switch/customer-reviews)).

Connecting to paired devices takes the `com.apple.security.device.bluetooth` entitlement plus a Bluetooth prompt. In one rejection, App Review also asked for `network.client`, which MaxCandela already has ([Apple forums 769362](https://developer.apple.com/forums/thread/769362)).

Battery levels are the uncertain part. No documented public property exposes per-earbud battery. ToothFairy's own manual says: "If the macOS Bluetooth menu does not show the battery level, ToothFairy won't, either" ([ToothFairy](https://c-command.com/toothfairy/manual)). Ship quick-connect first and add battery only if a hardware test finds a reliable source. Make it Pro, since it stands in for a $6.99 app. Note that no user-voice evidence for it turned up in the readable sources; see the Reddit section.

### 8. Focus timers and break reminders cost a day

This extends the existing Timer. Session, a focus timer, has **2,100 Setapp ratings at 98%** ([Setapp](https://setapp.com/apps/session)), and focus or pomodoro tools appear in three of nine roundups. SitTall sells posture reminders for $5.99 ([SlashGear](https://www.slashgear.com/2172654/best-mac-apps-improve-apple-experience-2026/)). One Setapp subscriber keeps a Setapp app "mostly for posture reminders" ([HN](https://news.ycombinator.com/item?id=48710091)). The feature needs no permission.

One open question: pausing the timer when the user is away relies on an idle-time call (`CGEventSourceSecondsSinceLastEventType`). Check whether it triggers an Input Monitoring prompt before depending on it. Free toolboxes all ship timers, so this is parity and stays free.

### 9. A scratchpad is the cheapest tool with paid evidence

SideNotes sells for **$12.99 and ranks #11 in US paid Productivity** ([chart](https://apps.apple.com/us/mac/charts/6007?chart=top-paid)). Unclutter, a drawer for notes, files and clipboard, costs $32.99 and has 652 Setapp ratings ([Setapp](https://setapp.com/apps/unclutter)). A Raycast user says its floating notes have "worked for me better than Notion, Obsidian, Reminders, Tick Tick" ([HN](https://news.ycombinator.com/item?id=39433899)). One developer reported more than 150 paid users of a menu-bar sticky-notes app ten weeks after launch; that figure comes from a search summary only ([Indie Hackers](https://www.indiehackers.com/product/noticky)).

It is a text view saved to the app container, with no permission. Keep it local, because syncing with Reminders would add a prompt. Make it free.

### 10. Per-app volume could become an audio boost, if a spike proves it

macOS has no per-app volume control ([DEV](https://dev.to/thalesbmc_75/macos-still-has-no-volume-mixer-so-i-built-one-cmb)), and the free tools that add one draw **19,400 stars** for Background Music and 6,837 for eqMac ([GitHub](https://github.com/kyleneideck/BackgroundMusic)). Boom 3D has 1,791 Setapp ratings ([Setapp](https://setapp.com/apps/boom-3d)).

The project's notes ruled out a volume boost because it needs an audio driver ([CLAUDE.md](/Users/daniel/Codes/maxcandela/CLAUDE.md)). That may no longer be true. A September 2026 developer report says Core Audio process taps can mute a process's own output and re-render it at a new gain. It also says this **works inside the App Sandbox** with the `audio-input` entitlement, a system-audio permission and no microphone usage string ([Apple forums 848578](https://developer.apple.com/forums/thread/848578)). VolumeHub already advertises per-app sliders built on that API on the App Store ([App Store](https://apps.apple.com/us/app/volumehub/id6758415969)).

Setting the gain above 1.0 makes this a **volume boost, the audio twin of the XDR boost**. But the evidence is one developer post with no Apple reply, and that post warns that "Two process taps on the same device from different processes interfere with each other". Spike it on hardware before committing.

### Near-misses that fell just outside the ten

- **Camera mirror.** Hand Mirror is free on the App Store with 683 Setapp ratings ([App Store](https://apps.apple.com/us/app/hand-mirror/id1502839586), [Setapp](https://setapp.com/apps/hand-mirror)). It would need the camera entitlement and prompt, and would only match a free app.
- **Translate on-screen text.** It appears in four of nine toolboxes. Fold it into Copy Text from Screen rather than building a separate tool. The UI-less `TranslationSession` initialiser needs macOS 26.4, so macOS 15.6–26.3 would need a hidden SwiftUI host ([Apple](https://developer.apple.com/documentation/translation/translationsession/init(installedsource:target:preferredstrategy:))).
- **Network throughput, public IP and TCP latency.** These are small additions to System using the existing `network.client` entitlement, but the readable sources had no user-voice evidence for them.
- **Resolution and refresh-rate switcher.** Public `CGDisplaySetDisplayMode` reverts when the app quits, which fits MaxCandela's "quit means back to normal" rule ([Apple archive](https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/QuartzDisplayServicesConceptual/Articles/DisplayModes.html)). But BetterDisplay's real draw, custom HiDPI modes, depends on private calls ([ResolutionMenu](https://www.github.com/robbertkl/ResolutionMenu)).
- **Keyboard-cleaning lock.** KeyBlock passed review recently while asking for Accessibility ([App Store](https://apps.apple.com/hn/app/keyblock-keyboard-protector/id6751187079?l=en-GB)). Whether a blocking event tap counts as an Accessibility-class or Input Monitoring-class API is unresolved.
- **Weather.** WeatherKit's 500,000 free calls a month cover only about 350 daily users polling every 30 minutes before Apple starts billing ([Apple](https://developer.apple.com/weatherkit/get-started/)), so a free weather tool's cost grows with its success.
- **Keyboard sounds.** This is the strongest outlier: Klack is **#7 among all paid Mac apps in the US** ([chart](https://apps.apple.com/us/mac/charts)). Listen-only event taps are sandbox-safe ([Apple forums 780626](https://developer.apple.com/forums/thread/780626)). But one $4.99 app owns the niche, and a toolbox that asks to monitor every keystroke makes a heavy trust request.

## What the sandbox, macOS 26.4 and free apps rule out

| Do not build | Why | Evidence |
|---|---|---|
| Battery charge limiter | Writing charge limits needs root through a privileged helper. macOS 26.4 ships a native 80–100% limit. Offer a battery read-out and a link to Settings instead. | [MacRumors](https://www.macrumors.com/2026/02/16/mac-charge-limit-macos-tahoe-26-4/), [Apple](https://support.apple.com/en-gb/102338) |
| Quit-all / force-quit apps | The sandbox forbids terminating other apps; `terminate()` and `forceTerminate()` both fail in sandboxed builds | [Apple](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox), [forums 768174](https://developer.apple.com/forums/thread/768174) |
| Night Shift / True Tone toggle | Only the private CoreBrightness framework controls it; Warmth is the public substitute | [forums 43356](https://developer.apple.com/forums/thread/43356) |
| One Switch-style system toggles (Dark Mode, Finder's hide-icons, hidden files, empty Trash, lock screen) | The sandbox forbids sending Apple Events to arbitrary apps and changing other apps' preferences. One Switch's Empty Trash repeatedly asks for automation permission. The leaders ship outside the App Store. | [Apple](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox), [Setapp reviews](https://setapp.com/apps/one-switch/customer-reviews) |
| Focus / Do Not Disturb toggle | No public API exists. Ship a ready-made Shortcut for the existing Shortcuts runner instead. | [forums 729475](https://developer.apple.com/forums/thread/729475) |
| Custom HiDPI modes, rotation, external-monitor brightness (DDC), fan control | Private APIs or SMC access | [BetterDisplay wiki](https://github.com/waydabber/BetterDisplay/wiki/Fully-scalable-HiDPI-desktop), [ResolutionMenu](https://www.github.com/robbertkl/ResolutionMenu) |
| Inline text expansion, auto-paste, mouse jiggler, dictation typed into the front app | All post synthetic input, which drew Guideline 2.4.5 rejections in 2026. A copy-only snippet picker is the safe form. | [forums 820594](https://developer.apple.com/forums/thread/820594) |
| More window management (layouts, Alt-Tab switcher) | It depends on the same blocked Accessibility API | [forums 854711](https://developer.apple.com/forums/thread/854711) |
| Wi-Fi network name (SSID); ICMP ping | The SSID needs Location permission and still returns nothing at times. ICMP from a sandbox is unclear, so time a TCP connection instead. | [forums 732431](https://developer.apple.com/forums/thread/732431), [forums 816619](https://developer.apple.com/forums/thread/816619) |
| AI-usage meters, port monitors, keyboard-layout fixers, standalone dictation | Each was launched by many free open-source one-offs. They need credential handling or keystroke monitoring. | [HN](https://news.ycombinator.com/item?id=46544524), [HN](https://news.ycombinator.com/item?id=49073834), [HN](https://news.ycombinator.com/item?id=48575878) |
| Launcher / command palette | Raycast's free tier covers it, and users consolidate on it as "one less app to install" | [HN](https://news.ycombinator.com/item?id=48662872), [Raycast](https://www.raycast.com/pricing) |
| More menu-bar-manager features | Every major macOS release breaks these apps, and macOS 27 now handles overflow natively | [GitHub](https://github.com/jordanbaird/Ice/issues/954), [Badgeify](https://badgeify.app/macos-27-golden-gate-menu-bar-changes/) |

One chart sits awkwardly against this list. **Quit All Apps ranks #10 in Japan's paid Productivity** ([chart](https://apps.apple.com/jp/mac/charts/6007?chart=top-paid)), even though Apple says sandboxed apps cannot terminate others. How it works was not checked. The likeliest explanations are the same as for Magnet: an old unsandboxed listing, or a mechanism a new submission could not reuse. Treat it as unexplained, not as precedent. Mouse fixes follow the same pattern. The ¥150 Mouse Scroll Plus ranks #6 in Japan's paid Utilities, yet the free leader Mos asks people **not** to upload it to the App Store ([Mos](https://github.com/Caldis/Mos)). Leave them deferred until someone confirms how a blocking event tap behaves in the sandbox.

## Reddit's absence weakens the demand ranking, not the feasibility verdicts

The researchers could not open any r/macapps, r/MacOS or r/mac thread. A Medium roundup claiming to summarise Reddit favourites also returned HTTP 403 ([Medium](https://medium.com/@wjzv8192/top-20-mac-menu-bar-apps-2026-every-one-recommended-by-real-users-a0a9244cf1f6)). The user-voice evidence therefore comes from Hacker News, one MacRumors thread and one GitHub issue. Those skew toward developers, and many HN posters were promoting their own apps.

**Four conclusions are weakened:**

- **The middle of the ranking.** Bluetooth quick-connect, focus timers, the scratchpad and the near-misses (network meter, converters, camera mirror, resolution switcher, weather) had no direct user requests in any readable source. Their places rest on Setapp rating counts, chart ranks and how many toolboxes list them. Those measure installs and supply, not unmet wishes. Reddit's "is there an app that…" threads are where such requests usually live, so the missing evidence is not evidence of low demand. Some of those tools could rank above the dimmer or the shelf.
- **The macOS 27 status of menu-bar hiding.** r/MacOS would likely hold first-hand reports on Hidden Bar and the native overflow arrow. Without them, the case rests on two developers' store copy and a vendor blog.
- **Willingness to pay.** The "one-time purchase, no subscription" preference, and the view that simple toggles should be free, come from HN, where users are more technical and more likely to try open-source tools. Mainstream App Store buyers clearly behave differently: Japanese shoppers pay ¥150–¥300 for single toggles.
- **The claimed Reddit favourites.** The assertion that Ice, Stats, Maccy, Amphetamine and Itsycal are Reddit's top picks is unverified.

**What stands on its own sources:**

- Every sandbox verdict, which rests on Apple documentation and DTS posts.
- The chart ranks, Setapp counts, prices and GitHub stars.
- The two findings about existing tools.

Three other gaps limit every demand number in this report:

- Mac App Store rating counts are no longer publicly readable; Apple's own pages return zero even for Magnet.
- The charts are a single-day snapshot of the top 25.
- Setapp counts accumulate over each app's whole time on Setapp.

A human pass over the last year of r/macapps posts containing "menu bar", "wish" and "looking for an app that" would close the largest of these gaps cheaply.

## Conclusion

The pattern behind both the risks and the shortlist is that **the App Store incumbents MaxCandela's Pro tier imitates cannot be copied the way they were built**. Magnet and HazeOver predate the sandbox, and Hidden Bar's own App Store build has just conceded macOS 27. The paid categories a new sandboxed app can still win run through ScreenCaptureKit, EventKit, drag and drop, and plain overlay windows, and MaxCandela already holds the first two permissions. Treat permissions as a budget. Every new entitlement is another App Review question, another privacy-label line and another prompt a user can refuse. That is why the top three tools need nothing new, and why tools that need Accessibility belong in a separate Developer ID build. DTS recommends that route for window control, and the project's notes already sketch such a build for fan control.

The economics point the same way. MaxCandela's $9.99 lifetime price buys one copy of Maccy. If Window Snapping and icon hiding drop out, the Pro tier needs new tools that each replace a paid app no free App Store toolbox gives away. Screen capture replaces a $35 app, a month calendar an $18 one, and background-window dimming a $4.99 one. Together with the XDR boost, they would give MaxCandela a display-and-capture core that none of the nine competitor toolboxes has, and a credible "replaces $50 of apps" pitch.
