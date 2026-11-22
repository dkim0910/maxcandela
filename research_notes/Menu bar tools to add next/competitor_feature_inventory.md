# Competitor feature inventory: Mac menu-bar toolboxes and the single-purpose apps they replace (2025–2026)

Research date: 2026-11-22. Scope: macOS only. "MaxCandela" below means the feature list given in the brief (Keep Awake, Timer, Clipboard text tools + history, Color Picker, generators (UUID/password/timestamp/lorem), World Clock, Sound device switching + mic mute, System read-out, Extra Dim, Hide Menu Bar Icons, Clipboard Manager, Window Snapping, Copy Text from Screen (OCR), Shortcuts runner, Next Meeting, XDR brightness boost, Warmth). MaxCandela's code was not re-read for these notes.

Method caveat that applies to every Mac App Store (MAS) rating below: the apps.apple.com pages fetched for this research showed "hasn't received enough ratings or reviews to display an overview" even for **Amphetamine**, **Lungo** and **Dato**, which are long-established, widely used apps. The fetcher is evidently not seeing the ratings block, so a missing rating in these notes does **not** mean the app has no ratings. The only MAS rating figures recorded here came from search results that indexed the "Ratings & Reviews" sub-page (iBar, iBar Pro, Toolbox).

---

## 1. One Switch: full switch list, price, distribution, ratings

### Takeaway
One Switch is by **Fireball Studio** (no product or developer called "FireStack" turned up in any search). It is a one-time-purchase toggle hub sold directly (about $4.99) and via Setapp, where it rates 98% positive across about 2,000 ratings. It is **not** on the Mac App Store. Its switches are system toggles (Dark Mode, hide desktop icons, Night Shift/True Tone, show hidden files, resolution, screen-clean, lock, empty trash, AirPods connect, DND). It has almost none of the "mini-tool" features MaxCandela has.

### Cited Findings
**Identity and distribution**
- Searches for "FireStack" returned nothing. Every result was One Switch by Fireball Studio — [WebSearch summary of setapp.com / producthunt.com results](https://setapp.com/apps/one-switch/customer-reviews); [Product Hunt: Fireball Studio](https://www.producthunt.com/products/fireball-studio/launches/one-switch)
- Official page offers "Free Download", "Buy Now", a "Get One Switch with Setapp" link and Chinese resellers (数码荔枝 / 少数派 sspai). It does **not** mention the Mac App Store. It says the license is "lifetime available" with free updates and offers a 7-day free trial "without any prepayments" — [fireball.studio/oneswitch](https://fireball.studio/oneswitch)
- No apps.apple.com listing for One Switch was found. Search results say it is sold directly and through third-party channels — [WebSearch for apps.apple.com listing](https://alternativeto.net/software/one-switch/about)
- Requirements: the official page states both macOS 12 Monterey+ and Big Sur 11+ in different places. Setapp lists macOS 12.0+ — [fireball.studio/oneswitch](https://fireball.studio/oneswitch); [Setapp](https://setapp.com/apps/one-switch)
- Current version on Setapp: **1.35.4** — [Setapp](https://setapp.com/apps/one-switch)
- Last update: **28 Dec 2025** per SourceForge (search-result summary) — [SourceForge](https://sourceforge.net/app/one-switch/mac/)

**Price**
- $4.99 for a license after a 7-day trial (Feb 2020) — [The Sweet Setup, 26 Feb 2020](https://thesweetsetup.com/one-switch-is-the-menu-bar-app-for-quickly-toggling-tedious-settings/)
- "One time purchase (perpetual license) that costs $5" (2022, from a search snippet; the page itself returned 403) — [Podfeet, Jul 2022](https://www.podfeet.com/blog/2022/07/one-switch/)
- A deal site sold a single-Mac license at $1.99, down from $4.99 — [Shacknews deals](https://deals.shacknews.com/sales/one-switch-1-device)
- Setapp: included in the Setapp subscription (search summary cites "from $9.99/month") — [Setapp](https://setapp.com/apps/one-switch)

**Ratings and reviews**
- Setapp: **98%** positive from **2,029** ratings — [Setapp](https://setapp.com/apps/one-switch)
- Review themes (search summary of the Setapp review pages): praised as easy to use and "indispensable". Complaints: a **May 2026** review reports bugs and errors with the lock-screen feature; a **Jan 2026** review says Empty Trash "cannot be enabled because it keeps asking me to enable automation"; one user asked for a way to show Bluetooth devices; one suspected a conflict with Bartender; a late-2025 review requested a toggle to hide the menu bar — [Setapp customer reviews](https://setapp.com/apps/one-switch/customer-reviews)

**Switch list (assembled from several sources; no single current, complete list was found)**
- The official page features five: **Hide Desktop Icons, Dark Mode, Keep Awake, Screen Saver, AirPods** — [fireball.studio/oneswitch](https://fireball.studio/oneswitch)
- The 2020 list of 14 switches: **Hide Desktop Icons, Dark Mode, Keep Awake, Screen Saver, Headphones Connect (Bluetooth), Do Not Disturb, Night Shift, True Tone, Show Hidden Files, Display Sleep, Screen Resolution, Screen Clean (black backdrop + keyboard locked), Lock Keyboard, Lock Screen**, plus a "Play Music" switch mentioned in passing — [The Sweet Setup, 2020](https://thesweetsetup.com/one-switch-is-the-menu-bar-app-for-quickly-toggling-tedious-settings/)
- Changelog dates (search summary of the Softpedia changelog): Night Shift was an original switch in v1.2 (Apr 2019); Lock Screen was added in v1.9 (16 Dec 2019); Empty Trash in v1.11 (Apr 2020) — [Softpedia changelog](https://mac.softpedia.com/progChangelog/One-Switch-Changelog-142874.html)
- The current Setapp description adds Dark/Light mode **auto-switching sunrise→sunset**, **DND with scheduling**, a "customizable Control Center" and "customizable quick actions". It says the app "covers seven toggles at the time", which is stale marketing copy — [Setapp](https://setapp.com/apps/one-switch)
- One blogger counted "up to 23 switches in total" (2022, search snippet only) — [Podfeet](https://www.podfeet.com/blog/2022/07/one-switch/)

**Open-source equivalent: OnlySwitch** (to show how far the "switch" model has been pushed)
- **41 built-in switches**: Hide desktop, Dark mode, Screen Saver, Night Shift, Autohide Dock, AirPods, Bluetooth, Xcode cache, Autohide Menu Bar, Show hidden files, Radio Station, Keep awake, Spotify, Screen Test & Clean, FKey, Dim Screen, Hide Windows, Top Sticker, Only Agent, Show desktop pet, Dock Preview, Hide notch, Low power mode, Show Finder Path Bar, Mute mic, Small launchpad icon, Pomodoro timer, Show extension name, Show user library folder, Mute, Empty pasteboard, Empty trash, Show Recent Apps on Dock, Apple Music, Hide Menu Bar Icons, Back Noises, Eject Discs, True Tone, Key Light, Natural Scrolling, Tailscale — [GitHub jacklandrin/OnlySwitch](https://github.com/jacklandrin/OnlySwitch)
- Optional tabs: **Authenticator, Sound Mixer (per-app EQ/routing), Brightness, Browser, Screenshots & Record, System Monitor, Codex Usage, Claude Usage, Aphrodite (AI mini-apps), Xcode Cleaner, App Uninstaller**. Also schedules, a Shortcuts gallery, custom Shell/AppleScript buttons ("Evolution") and a desktop pet — [GitHub OnlySwitch](https://github.com/jacklandrin/OnlySwitch)
- MIT, 6.1k stars, Homebrew + DMG, not on the MAS. The README says its macOS 27 Hide Menu Bar Icons uses a **private API "not suitable for Mac App Store distribution"** — [GitHub OnlySwitch](https://github.com/jacklandrin/OnlySwitch)
- A separate MAS app, **AnySwitch – Powerful switches** (JP store id6444313776), appeared in search results but was not examined — [App Store JP](https://apps.apple.com/jp/app/id6444313776)

### Inferences
- One Switch's value is *system toggles*. MaxCandela overlaps only on Keep Awake (and loosely on Night Shift via its own Warmth). The One Switch switches MaxCandela lacks are: Dark Mode, Hide Desktop Icons, Screen Saver, Display Sleep, Lock Screen, Lock Keyboard / Screen Clean, Show Hidden Files, Screen Resolution, Night Shift/True Tone system toggles, DND, AirPods/Bluetooth headphone connect, Empty Trash.
- Several of those likely need Apple Events automation, `defaults` writes plus a Finder relaunch, or private API. The Jan 2026 "keeps asking me to enable automation" review for Empty Trash points that way, and so does OnlySwitch's private-API note. That is consistent with One Switch being **off the MAS** while selling direct and on Setapp. MaxCandela's own `CLAUDE.md` records dark-mode toggling, hide-desktop-icons "the usual way", lock screen and display-sleep-now as ruled out for the sandboxed build (a repo note, not re-verified here).
- The 98% / 2k rating on Setapp shows demand for a cheap (~$5) one-click toggle hub. Its weak spots per reviews (permission prompts, lock-screen bugs, Bartender conflicts) are the fragility of non-public mechanisms.

### Gaps
- No authoritative, current (v1.35.x) list of every One Switch switch was retrievable. The official page and Setapp list only subsets, and the Podfeet count of 23 could not be opened (HTTP 403).
- The current direct price could not be read from fireball.studio (no price on the page). $4.99 is from 2020 and $5 from 2022.
- No Mac App Store rating exists because it isn't on the MAS. Product Hunt ratings were not retrieved.
- Whether Setapp's One Switch differs in features from the direct version was not established.

---

## 2. Other toolboxes and multi-tool / single-purpose apps: what, price/model, MAS, free/OSS

### Takeaway
Two kinds of competitor exist. (a) **Broad toolboxes**: Raycast (free core plus a $10/mo Pro), Supercharge ($20, direct/Setapp only), BetterTouchTool ($15/$25), iStat Menus (paid, also on the MAS), MacTools and OnlySwitch (free OSS), and a crop of **new 2025–26 MAS menu-bar toolboxes** (Barista, UtilsBar, BarBox Tools, SuperMenuBar). (b) **Single-purpose leaders**, many free or open source (Stats, Ice/Thaw, Rectangle, Maccy, Loop, MeetingBar, Mos, DockDoor, Itsycal, Amphetamine), with paid ones mostly at $4–$35 one-time. Subscriptions are spreading at the top end: Raycast's AI credits (Sept 2026), Bartender Pro ($15/yr, 2026), CleanShot Pro, AlDente Pro yearly.

### Cited Findings

#### 2a. Broad toolboxes / multi-tool apps

**Raycast** (launcher + built-ins)
- Built-in core features: Snippets, Quicklinks, Clipboard History, Notes, Focus, File Search, Applications, Extensions, Translate, Emoji & Symbols, Calendar, Calculator, Screenshots, Window Management, Navigation. Power features: Hyper Key, Cloud Sync, Dynamic Placeholders, System Commands, Script Commands, Themes, Auto Quit, Run, Games — [Raycast Manual](https://manual.raycast.com/)
- Pricing: **Free** $0 (core features incl. Clipboard History, Quicklinks, Calculator, Snippets, Window Management, Notes, extensions; clipboard history kept 3 months). **Pro** $10/mo or $96/yr (unlimited clipboard history, AI with 500 credits, Cloud Sync, Dictation, Custom Themes, Translator, Custom Window Management Commands, BYOK, MCP). **Plus** $20/mo ($192/yr, 3,000 credits). **Max** $50/mo ($480/yr, 7,500 credits). Teams Pro $15/user/mo — [raycast.com/pricing](https://www.raycast.com/pricing)
- **Pricing-model change, 10 Sept 2026:** AI moved from rate limits to **usage-based credits**, "subscription prices stay the same". The $20 tier is the renamed "Advanced AI", called **Pro+** by Raycast/AlternativeTo (the pricing page fetched shows "Plus"). **Max ($50)** is new, and the flat $8/mo Advanced AI add-on was removed — [Raycast blog](https://www.raycast.com/blog/changing-how-raycast-ai-is-priced); [AlternativeTo news, Sept 2026](https://alternativeto.net/news/2026/9/raycast-shifts-ai-plans-to-credits-and-adds-max-for-heavy-use/); [PricingSaaS](https://pricingsaas.com/companies/raycast/diffs/2026W38)
- Raycast's billing manual says credits later rose: Pro 500→750, Pro+ 3,000→4,500 — [manual.raycast.com/billing](https://manual.raycast.com/billing)
- German press reported user annoyance at the new AI pricing model — [ifun.de](https://www.ifun.de/raycast-veraergert-nutzer-mit-neuem-ki-preismodell-288857/)

**Supercharge** (Sindre Sorhus; "enhancements for your Mac")
- **$20 one-time** with free updates. Sold direct (Gumroad) and on **Setapp**. **Not on the Mac App Store**: the developer says much of it "wouldn't be possible there because of sandboxing". Requires **macOS 27**; older builds for 26/15 are free but won't run on newer systems — [sindresorhus.com/supercharge](https://sindresorhus.com/supercharge)
- Feature set relevant to a toolbox (abridged from a very long list): Finder cut/paste and context actions; Mission Control window close/quit; green button fills; auto-quit/hide inactive apps; **Hyper key**; finer volume/brightness steps; **OCR copy text from screen**; **capture and translate on-screen text**; **QR/barcode scan**; **screen colour picker (Hex/RGB/OKLCH)**; screenshot auto-copy/archiving; **toggle mute for sound + mic, mute mic while typing, cycle output/input devices**; **clipboard auto-clear**; **Cleaning Mode / Cat Mode (input lock)**; **run Shortcuts from menu**; **keep awake**; **change default browser**; **toggles for Dark mode, Night Shift, True Tone, Low Power Mode, grayscale, desktop icons/widgets, hot corners, menu-bar auto-hide, fn keys**; **sleep displays, start screen saver**; eject all disks; empty Trash; flush DNS; AirDrop automation; notification clearing — [sindresorhus.com/supercharge](https://sindresorhus.com/supercharge)

**BetterTouchTool** (folivora.ai)
- **Standard $15** (2 years of updates, keep last version) / **Lifetime $25** (updates for as long as BTT exists). One license covers all personal Macs and unlocks BTT Mobile. On **Setapp**. MAS not mentioned. Areas: Window Management, Trackpad Gestures, Keyboard Shortcuts, Stream Deck & Macro Pads, Clipboard Manager, "All actions" — [folivora.ai/buy](https://folivora.ai/buy)

**iStat Menus** (Bjango)
- v**7.5** (macOS 13.5+). Modules: CPU, GPU, Memory, Disks (incl. S.M.A.R.T.), Network (per-app bandwidth, public/private IP), Battery & power (incl. **Bluetooth device battery**), Sensors (temps, **fan control**), **Weather** (hourly/weekly), **Date & time with calendar + world clocks**, **Astronomy** (new in 7.5), Rules/notifications, Combined mode. 14-day trial; direct + Setapp — [bjango.com/mac/istatmenus](https://bjango.com/mac/istatmenus/)
- Price: $11.99 single / $14.99 family (5 users) for new users — [MacSales blog](https://eshop.macsales.com/blog/95542-istat-menus-7-is-the-latest-in-a-long-line-of-delightful-mac-monitoring-apps-from-bjango/). The upgrade from v6 is $9.99 / $14.99 family — [TidBITS](https://tidbits.com/watchlist/istat-menus-7-0-2/). v7 (Jul 2024) was a **paid upgrade** — [Bjango help](https://bjango.com/help/istatmenus7/update/); [MacRumors](https://www.macrumors.com/2024/07/31/istat-menus-7-0-brings-new-features)
- MAS listing exists, "$11.99 with in-app purchases" per search summary — [App Store: iStat Menus 7](https://apps.apple.com/app/id6499559693)

**MacTools** (open source)
- GPL-3.0, 1.4k stars, macOS 14+, Homebrew/GitHub, not MAS. Command palette; window switcher; clipboard history with snippets and paste queues; screenshots with annotation, **OCR, QR recognition, pinning, scrolling capture, region recording**; automation workflows with triggers; keyboard/mouse/trackpad remapping; **displays: brightness, resolution, Sidecar, True Tone, Night Shift, notch hiding**; **audio: volume, per-app volume; power: keep-awake, fan and charging management**; system monitoring, battery, network; calendar; **cleanup: disk usage, large files, Homebrew, login items, app quitting**; **translation**, AI prompt templates, Cloudflare R2 upload — [GitHub mactools-app/MacTools](https://github.com/mactools-app/MacTools)

**OnlySwitch**: see §1 (MIT, 41 switches plus tabs).

**OneMenu**
- Described as an all-in-one utility: window management (an Alt-Tab-style switcher), system monitoring (CPU/memory/disk), clipboard history, keyboard-cleaning mode. Bundle id com.withmarko.OneMenu — [appcatalog.cloud](https://appcatalog.cloud/apps/onemenu); [Medium review](https://medium.com/p/1c22861a6403). The MacStories Club page returned 403 — [MacStories](https://www.macstories.net/club/onemenu/)

**New MAS menu-bar toolboxes (2025–26)** — details in §4.
- **Barista: 35+ Menu Bar Widgets**: $14.99 one-time unlock after a 14-day trial — [App Store](https://apps.apple.com/us/app/id6773448655)
- **UtilsBar**: free, $9.99 lifetime Premium — [App Store](https://apps.apple.com/app/utilsbar/id6761060716)
- **BarBox Tools**: free, no IAP — [App Store](https://apps.apple.com/app/id6802093315)
- **SuperMenuBar**: on the MAS (id6759054080); no price on its site — [macsuperapp.com](https://macsuperapp.com/)
- **xMenuBarTools**: $0.99; web apps/online tools in the menu bar — [App Store](https://apps.apple.com/bs/app/xmenubartools/id6469338732?mt=12)
- **Beaconly: Menu Bar Hub**: free; "400+ extensions" (Jira, GitHub PRs, Linear, cloud status pages) — [App Store](https://apps.apple.com/app/id1520138793)

**"Toolbox for Mac" / "Mac Toolbox"**
- No Mac menu-bar product by either name was found. MAS search surfaced "Toolbox – All Tools One App" (3.3★ from 4 ratings, "not verified for macOS"), "Toolbox™ (iMetalBox)" (4.7★, 4,326 ratings, **an iPad app**), and "Toolbox (By Koizeay)" — [App Store: Toolbox – All Tools One App](https://apps.apple.com/us/app/toolbox-all-tools-one-app/id6740595408); [App Store: Toolbox](https://apps.apple.com/us/app/toolbox/id615380696); [App Store: Toolbox (By Koizeay)](https://apps.apple.com/us/app/toolbox-by-koizeay/id6466197390)
- The nearest "100+ tools in one app" on the Mac is a media/file toolbox, **MediaKit: Compress & Convert**: its listing claims 133 Mac tools (video compression, background removal, PDF signing, offline). Search summary only — [App Store: MediaKit](https://apps.apple.com/app/id6761451361)

#### 2b. Menu-bar managers ("menu bar controller"-style)

**Bartender** (owned by Applause since 2024; acquisition not re-sourced here)
- **Bartender 6: $20 one-time** after a 4-week trial; free upgrade for 2025 buyers of Bartender 5 — [Six Colors, 12 May 2026](https://sixcolors.com/post/2026/05/bartender-6s-new-pro-feature-turns-the-macbook-notch-into-a-dynamic-peninsula/)
- **New in 2026: Bartender Pro, $15/year subscription**. It adds **Top Shelf** (the notch becomes a "Dynamic Island" with Calendar/Weather/Music widgets, a **Files shelf**, a **clipboard manager**, volume/brightness/battery HUDs, now-playing art) — [Six Colors](https://sixcolors.com/post/2026/05/bartender-6s-new-pro-feature-turns-the-macbook-notch-into-a-dynamic-peninsula/)
- **Bartender 7** targets **macOS 27 "Golden Gate"** (Bartender 6 for Tahoe). It is a one-time purchase including all v7 updates. Pro is billed yearly with a 14-day trial; a "Mega Supporter" lifetime purchase now includes Pro. Features: Command Bar (search menu items + **clipboard history**), Bartender Bar, triggers/widgets, works without Screen Recording permission, notch handling, profiles, Shortcuts/AppleScript/agents automation, styling — [macbartender.com](https://macbartender.com)
- Bartender 6 lag/issues on macOS 26 were reported by heise — [heise](https://heise.de/-11167978)

**Ice → Thaw**
- Ice: hide/show menu bar items, always-hidden section, hover/click reveal, separate bar for notched Macs, search, profiles, spacers, appearance (tint/shadow/border/shapes). **GPL-3.0, 30.1k stars**, macOS 14+, GitHub/Homebrew, free — [GitHub jordanbaird/Ice](https://github.com/jordanbaird/Ice)
- Reviews say Ice has **compatibility problems with macOS Tahoe and its development is frozen**. **Thaw** is an actively maintained fork (macOS 26+, Thaw 2.0 RC 3) — [Thaw README](https://raw.githubusercontent.com/thaw-app/Thaw/development/README.md); [Softpedia Thaw review](https://www.softpedia.com/reviews/mac/thaw-review-538074.shtml); [Thaw discussion #427](https://github.com/orgs/thaw-app/discussions/427); [MacG, Feb 2026](https://www.macg.co/logiciels/2026/02/thaw-un-nouvel-utilitaire-pour-desencombrer-la-barre-des-menus-de-macos-306843)

**iBar / iBar Pro** (MAS menu-bar managers)
- iBar Pro: **4.6★ from 199 ratings**. iBar (free version): **4.5★ from 834 ratings**. A 2025 review complains the free app "became paid" — [App Store: iBar Pro reviews](https://apps.apple.com/us/app/ibar-pro-menubar-control-tool/id6737150304?mt=12&see-all=reviews&platform=mac); [App Store: iBar reviews](https://apps.apple.com/us/app/ibar-menubar-icon-control-tool/id6443843900?mt=12&see-all=reviews&platform=mac)

#### 2c. Single-purpose leaders (the apps a toolbox "replaces")

| App | What it does | Price / model (2025–26) | MAS? | Free / OSS? | Source |
|---|---|---|---|---|---|
| **Stats** | CPU, GPU, memory, disk, network, battery, sensors, Bluetooth devices, multi-timezone clock; fan control (legacy) | Free | No (DMG, Homebrew) | MIT, 43.6k stars, macOS 12+ | [GitHub exelban/stats](https://github.com/exelban/stats) |
| **MenuBar Stats** | CPU, memory, network, disk, battery, GPU, Bluetooth (connect/disconnect); temps/fans via helper | $4.99 one-time | Yes; v3.9, 11 Apr 2023 | No | [App Store](https://apps.apple.com/us/app/menubar-stats/id714196447) |
| **Amphetamine** | Keep awake with triggers (displays, USB/BT, apps, Wi-Fi, CPU, idle…), closed-display mode, Drive Alive | Free, no IAP | Yes; v5.3.2, **10 Nov 2023** (no update since) | Free (closed) | [App Store](https://apps.apple.com/us/app/amphetamine/id937984704) |
| **Lungo** | Keep awake, durations, shortcut, deactivate on power unplug, Shortcuts | **$4** one-time | Yes; macOS 26+ | No | [App Store](https://apps.apple.com/us/app/lungo/id1263070803) |
| **Dato** | Menu-bar calendar, world clocks, fullscreen meeting alerts with Join button, reminders, hourly chime, date calculator | **$18** one-time, "never subscription" | Yes; macOS 26+ | No | [App Store](https://apps.apple.com/us/app/dato/id1470584107) |
| **Itsycal** | Tiny menu-bar calendar: events, Reminders, join meetings, ISO week numbers, hourly chime | Not stated on page | No (direct ZIP; macOS 27 build + macOS 11 build) | Not stated on page | [mowglii.com/itsycal](https://www.mowglii.com/itsycal/) |
| **MeetingBar** | Next meeting in the menu bar, one-click join for 50+ services, fullscreen reminders | Free, optional tips/IAP | Yes (+ Homebrew) | Apache-2.0, 5.4k stars | [GitHub leits/MeetingBar](https://github.com/leits/MeetingBar) |
| **Hyperduck** | Sends links from iPhone/iPad/Vision Pro to the Mac | Paid | (Sindre Sorhus app; MAS not confirmed) | No | [sindresorhus.com/apps](https://sindresorhus.com/apps) |
| **Velja** | Browser picker / link routing | Paid, free trial; ₩11,000 on KR store; macOS 15.4+ | Yes (KR listing) | No | [sindresorhus.com/apps](https://sindresorhus.com/apps); [App Store KR](https://apps.apple.com/kr/app/id1607635845) |
| **Pandan** | Time awareness: how long you've been active, in the menu bar | Free | (not confirmed) | Free (closed) | [sindresorhus.com/apps](https://sindresorhus.com/apps) |
| Other Sorhus menu-bar apps | Zone Bar (world clocks), Menu Drop (AirDrop), Short Run (Shortcuts), Default Browser, Menu Bar Calendar, Day Progress, Online Check, Week Number, Second Clock, Speediness (speed test), Folder Peek, Battery Indicator, Text Lens (OCR), Camera Preview, Super Menu | Mix of free/paid | Mostly MAS (not confirmed per app) | No | [sindresorhus.com/apps](https://sindresorhus.com/apps) |
| **Hand Mirror** | Camera preview from the menu bar; "Plus" adds Mic Check, snaps, Reactions, always-on-top window, notch trigger | Free base; **Plus = one-time IAP** (price not shown, "cheapest it will ever be") | Yes | No | [handmirror.app](https://handmirror.app/) |
| **Rectangle** | Keyboard/snap-area window management | Free | Direct DMG | **Free & open source**, macOS 14+ | [rectangleapp.com](https://rectangleapp.com/) |
| **Rectangle Pro** | Throw to 16 positions, custom sizes, workspace layouts, edge stash, iCloud sync | Paid one-time (price cut off), 10-day trial, 3 devices, sold via Paddle | Not mentioned | No | [rectangleapp.com/pro](https://rectangleapp.com/pro) |
| **Loop** | Radial-menu window management, preview, stash | Free | No (Homebrew/zip) | GPL-3.0, ~12k stars, macOS 13+ | [GitHub MrKai77/Loop](https://github.com/MrKai77/Loop) |
| **Lasso** | Grid click-and-drag window manager, saved layouts | ~$10.99 one-time (MacUpdate); Setapp | **No**: dev says the sandbox would limit it | No | [MacUpdate](https://lasso.macupdate.com); [AlternativeTo](https://alternativeto.net/software/lasso-window-manager/about); [Setapp](https://setapp.com/apps/lasso) (search summary) |
| **DockDoor** | Dock window previews, Alt-Tab window switching, Dock music controls, calendar previews | Free; **DockDoor Pro $20** one-time (3 Macs) | No (DMG/Homebrew) | GPL-3.0, ~6.6k stars | [GitHub ejbills/DockDoor](https://github.com/ejbills/DockDoor) |
| **HazeOver** | Dims background windows to highlight the front window | Price not shown | **Yes** + Setapp + direct; "compatible with macOS 27" | No | [hazeover.com](https://hazeover.com/) |
| **Maccy** | Keyboard-first clipboard history; clears copied passwords | "is and will always be free" | Yes (MAS link) + direct | MIT, macOS 14+ | [maccy.app](https://maccy.app/) |
| **Dropover** | Shake-to-open file shelf; image resize, text extract, ZIP, cloud upload | Model not stated on site | **MAS only** | No | [dropoverapp.com](https://dropoverapp.com/) |
| **Yoink** | Screen-edge file shelf; clipboard history; Continuity Camera | **$8.99** one-time | Yes + direct (28-day trial) + Setapp | No | [eternalstorms.at/yoink](https://eternalstorms.at/yoink/mac/) |
| **Unclutter** | Pull-down drawer: clipboard history, file dropzone, quick notes, optional sync | Lifetime license, price not shown; 10-day trial | Yes (MAS link) | No | [unclutterapp.com](https://unclutterapp.com/) |
| **CleanShot X** | Screenshots, recording, annotation, video editor (Studio Mode in 5.0), cloud, OCR | **Basic $35 one-time** (1 yr updates, then $19/yr); **Pro $10/user/mo** billed annually | Not mentioned; on **Setapp** | No | [cleanshot.com/pricing](https://cleanshot.com/pricing) |
| **Shottr** | Screenshots with OCR/QR, scrolling capture, pin, colour picker, ruler, annotate, S3 upload | Free to use; "pay what you want" licence | Not mentioned (direct) | No | [shottr.cc](https://shottr.cc/) |
| **TextSniper** | OCR to clipboard, QR/barcode read, text-to-speech | $7.99 (1 Mac) / $9.99 (3) / $11.99 unlimited (also on MAS); page also shows $6.99 | Yes + direct (Gumroad) | No | [textsniper.app](https://textsniper.app/) |
| **AlDente** | Battery charge limiter, heat protection, sailing mode, calibration, scheduling | Free; **Pro €11.49/yr subscription or €23.99 lifetime**; Setapp | Not mentioned | No | [AlDente pricing](https://apphousekitchen.com/aldente-overview/pricing/) |
| **Clop** | Auto-optimises copied images, screen recordings, PDFs, audio; format conversion | Free tier (5 per session); **Pro €15 lifetime** | No (DMG/Homebrew) | No (uses OSS encoders) | [lowtechguys.com/clop](https://lowtechguys.com/clop/) |
| **Boop** | Scriptable developer scratchpad (text transforms via JS scripts) | Free (MAS price not shown) | Yes + GitHub | MIT, ~4.2k stars | [GitHub IvanMathy/Boop](https://github.com/IvanMathy/Boop) |
| **DevUtils** | 47+ offline dev tools: JSON/SQL formatters, JWT, regex, Unix time, cron, UUID/ULID, hash, QR, Base64, URL encode, colour converter, text diff | Price tiers not shown (Pricing/Team/Perpetual pages exist) | **Yes** + Setapp + direct + Homebrew | Not stated | [devutils.com](https://devutils.com/) |
| **Pareto Security** | 30+ security checks (FileVault, updates, firewall, screen lock, sharing) | Desktop app free; Cloud free ≤5 devices; paid team plans | Not stated on page | Free & open source | [paretosecurity.com](https://paretosecurity.com/) |
| **Mos** | Smooth mouse scrolling, per-axis reverse, per-app profiles, button binding | Free | No; README asks people **not to upload it to the App Store** | CC BY-NC 4.0, ~22k stars | [GitHub Caldis/Mos](https://github.com/Caldis/Mos) |

### Inferences
- Many of the strongest single-purpose leaders are **free/OSS** (Stats 43.6k★, Ice 30.1k★, Mos 22k★, Loop 12k★, Rectangle, Maccy, MeetingBar, Amphetamine). A paid toolbox cannot compete on "free" for any one of these. Its pitch has to be *one icon, one install, native MAS trust*.
- The paid leaders cluster at **$4–$20 one-time** (Lungo $4, MenuBar Stats $4.99, TextSniper $7.99, Yoink $8.99, Lasso ~$11, iStat $11.99, Clop €15, BTT $15/$25, Dato $18, Supercharge $20, DockDoor Pro $20, Bartender $20, CleanShot $35). MaxCandela's $9.99 lifetime is priced below a single mid-tier leader.
- Several notable utilities are **deliberately off the MAS because of the sandbox**: Supercharge and Lasso say so explicitly, OnlySwitch flags a private API, and Mos asks not to be uploaded. Those features are where a MAS toolbox cannot follow. Conversely, the feature set of MAS-resident apps (Amphetamine, Lungo, Dato, MeetingBar, Hand Mirror, Yoink, Dropover, HazeOver, Maccy, TextSniper, MenuBar Stats, DevUtils, Boop, iStat Menus 7) shows what is achievable under MAS rules.
- Notable shifts: Bartender's **$15/yr Pro subscription** (2026) and Raycast's **credit-based AI pricing (10 Sept 2026)** show established toolboxes adding subscription layers. CleanShot's one-time tier is **$35 with paid update renewals** ($19/yr).
- **Amphetamine** (free, the classic keep-awake app) shows no update since **Nov 2023** on its MAS listing, and **Ice** is reported frozen with Tahoe problems. Both are leaders that look stale, which is an opening for a maintained alternative.

### Gaps
- Raycast's MAS availability was not checked (believed direct-download only, but not sourced here).
- AlDente, CleanShot, Shottr, Clop and Pareto: MAS availability was "not mentioned" on their sites; not independently confirmed.
- Missing exact prices: HazeOver, Dropover, Unclutter, Hand Mirror Plus, Rectangle Pro, DevUtils, Boop (MAS), Maccy (MAS), Hyperduck, Itsycal (the page does not state price or licence). The Bartender 7 price showed "Loading price".
- CleanShot's prior price (and the date it moved to $35 + $19/yr renewals) was not sourced.
- The Bartender/Applause acquisition (2024) is from background knowledge and was not re-verified in this pass.
- "Menu Bar Controller" did not resolve to one specific product. Menu-bar-manager-style apps (Bartender, Ice/Thaw, iBar, Beaconly "Menu Bar Hub") were covered instead. "MenuBot: Custom Menu Bar" (MAS) appeared in search but was not examined — [App Store](https://apps.apple.com/us/app/menubot-custom-menu-bar/id6444080295?mt=12)
- "Pareto" was interpreted as Pareto Security, the only Mac menu-bar app by that name found.
- Ratings for most MAS apps could not be read (see the method caveat at the top).

---

## 3. Which tools are table stakes vs. unique differentiators? (comparison matrix)

### Takeaway
Across nine multi-tool competitors, the near-universal tools are **Keep Awake (7/9)**, **audio output / mic mute (6/9)** and **clipboard history (5/9)**. Next come **system stats, OCR, QR codes, a calendar view, Night Shift/True Tone toggles, translation, and a launcher/command palette (4/9 each)**. MaxCandela already covers the first three tiers well. Its biggest table-stakes gaps are **QR code generate/scan, a full calendar dropdown (it has only Next Meeting), translation, a calculator/unit converter, quick notes/scratchpad, Bluetooth/AirPods quick-connect, and the One Switch-style system toggles** (Dark Mode, hide desktop icons, screen-clean/keyboard lock, lock screen, empty trash). **No competitor toolbox in these sources advertises above-SDR XDR brightness**, so that remains MaxCandela's clear differentiator.

### Cited Findings
Matrix key: **Y** = listed on the source page; **P** = partial or limited; **–** = not listed on the source page (not proven absent). Competitor columns: OS = One Switch, OnS = OnlySwitch, SC = Supercharge, RC = Raycast (free core unless noted), MT = MacTools, BA = Barista, UB = UtilsBar, BB = BarBox Tools, SMB = SuperMenuBar. The MaxCandela column (MC) is taken from the brief.

Sources per column: OS — [fireball.studio](https://fireball.studio/oneswitch), [Setapp](https://setapp.com/apps/one-switch), [Sweet Setup](https://thesweetsetup.com/one-switch-is-the-menu-bar-app-for-quickly-toggling-tedious-settings/) · OnS — [GitHub](https://github.com/jacklandrin/OnlySwitch) · SC — [sindresorhus.com/supercharge](https://sindresorhus.com/supercharge) · RC — [manual.raycast.com](https://manual.raycast.com/), [pricing](https://www.raycast.com/pricing) · MT — [GitHub](https://github.com/mactools-app/MacTools) · BA — [App Store](https://apps.apple.com/us/app/id6773448655) · UB — [App Store](https://apps.apple.com/app/utilsbar/id6761060716) · BB — [App Store](https://apps.apple.com/app/id6802093315) · SMB — [macsuperapp.com](https://macsuperapp.com/)

| Feature | OS | OnS | SC | RC | MT | BA | UB | BB | SMB | Count /9 | **MC** | Single-purpose leaders |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Keep awake | Y | Y | Y | – | Y | Y | – | Y | Y | **7** | **Y** | Amphetamine, Lungo |
| Audio output switch / mute / mic mute | – | Y | Y | – | Y | Y | – | Y | Y | **6** | **Y** | — |
| Clipboard history | – | P (empty pasteboard) | P (auto-clear only) | Y | Y | Y | Y | Y (20, memory) | – | **5** | **Y** | Maccy, Unclutter, Yoink, Bartender Command Bar/Top Shelf |
| System stats (CPU/mem/disk/net) | – | Y | – | – | Y | Y | – | Y | – | **4** | **Y** | Stats, iStat Menus, MenuBar Stats, OneMenu |
| OCR copy text from screen | – | – | Y | – | Y | – | Y | Y (from image) | – | **4** | **Y** (Pro) | TextSniper, CleanShot, Shottr |
| **QR code (generate or scan)** | – | – | Y (scan) | – | Y (recognise) | Y (generate) | – | Y (generate) | – | **4** | **–** | Shottr, TextSniper, DevUtils |
| **Calendar dropdown (month view)** | – | – | – | Y | Y | Y | – | – | Y | **4** | **P** (Next Meeting only) | Dato, Itsycal, iStat Menus, MeetingBar |
| **Night Shift / True Tone toggle** | Y | Y | Y | – | Y | – | – | – | – | **4** | **P** (own Warmth, not the system toggle) | — |
| **Translate** | – | – | Y (on-screen) | Y (Pro "Translator") | Y | Y | – | – | – | **4** | **–** | — |
| **Command palette / launcher / app search** | – | – | – | Y | Y | Y | – | Y ("My apps") | – | **4** | **–** | Raycast, Alfred |
| Timer / Pomodoro | – | Y (Pomodoro) | – | – | – | P (event countdowns) | – | Y | Y (Pomodoro) | **3–4** | **Y** | — |
| **Calculator / unit & currency conversion** | – | – | – | Y | – | Y | Y | P (CHF FX only) | – | **3–4** | **–** | — |
| **Quick notes / scratchpad** | – | – | – | Y (Notes) | – | Y | Y (markdown) | – | – | **3** | **–** | Unclutter, Boop, Sorhus Scratchpad |
| **Bluetooth / AirPods connect or battery** | Y | Y | – | – | – | – | – | Y (status + battery) | – | **3** | **–** | iStat, Stats, MenuBar Stats |
| **Dark Mode toggle** | Y | Y | Y | – | – | – | – | – | – | **3** | **–** | — |
| **Hide desktop icons** | Y | Y | Y | – | – | – | – | – | – | **3** | **–** | — |
| **Screen-clean / keyboard lock** | Y | Y | Y (Cleaning/Cat Mode) | – | – | – | – | – | – | **3** | **–** | OneMenu |
| **Lock screen / display sleep / screen saver** | Y | Y (screen saver) | Y | – | – | – | – | – | – | **3** | **–** | Amphetamine (screen lock) |
| **Empty Trash / eject disks** | Y | Y | Y | – | – | – | – | – | – | **3** | **–** | — |
| **Now Playing / media controls** | – | Y (Spotify, Music) | – | – | P (lyrics plugin) | Y | – | – | – | **2–3** | **–** | Bartender Top Shelf, DockDoor |
| Network info (IP) | – | – | – | – | Y | Y | – | Y (local+public IP) | – | **3** | **Y** (local IP) | iStat, Stats |
| **Dock / menu-bar autohide & Mac settings** | – | Y | Y | – | – | – | – | – | Y | **3** | **–** | — |
| **Screenshot / annotate / record** | – | Y (tab) | P (screenshot tweaks) | Y (Screenshots) | Y | – | – | – | – | **3** | **–** | CleanShot X, Shottr |
| AI features | – | Y | – | Y (Pro) | Y (prompt templates) | – | – | – | – | **3** | **–** | — |
| Colour picker | – | – | Y | – | – | Y | P (colour readout) | – | coming soon | **2–3** | **Y** | Shottr, Sorhus System Color Picker |
| UUID / password / random generators | – | – | – | – | – | – | Y | Y | – | **2** | **Y** | DevUtils |
| Text transforms (case, JSON, Base64) | – | – | – | – | – | Y ("Text Tools") | Y | – | – | **2** | **Y** | Boop, DevUtils |
| **Weather** | – | – | – | – | – | Y | – | Y | – | **2** | **–** | iStat Menus, Bartender Top Shelf |
| **Image compress / convert, PDF tools** | – | – | – | – | – | – | Y | Y (compress, PDF merge, batch rename) | – | **2** | **–** | Clop, MediaKit |
| **Per-app volume / sound mixer** | – | Y | – | – | Y | – | – | – | – | **2** | **–** | — |
| **Display resolution switch** | Y | – | – | – | Y | – | – | – | – | **2** | **–** | — |
| **Window switcher / Dock previews** | – | Y (Dock Preview) | – | – | Y | – | – | – | – | **2** | **–** | DockDoor, OneMenu |
| Window snapping | – | – | P (green button fills) | Y | P | – | – | – | – | **1–2** | **Y** (Pro) | Rectangle, Loop, Lasso, BTT |
| Brightness / dim | – | Y (Dim Screen, Brightness tab) | P (finer steps) | – | Y (brightness) | – | – | – | – | **2** | **Y** (XDR boost + Extra Dim + Warmth) | HazeOver (background-window dim) |
| Shortcuts runner | – | Y | Y | – | – | – | – | – | – | **2** | **Y** | Sorhus Short Run |
| **Hyper key** | – | – | Y | Y | – | – | – | – | – | **2** | **–** | — |
| **Auto-quit inactive apps** | – | – | Y | Y | – | – | – | – | – | **2** | **–** | — |
| **Cleanup / uninstaller** | – | Y | – | – | Y | – | – | – | – | **2** | **–** | — |
| **Show hidden files** | Y | Y | – | – | – | – | – | – | – | **2** | **–** | — |
| **Keyboard / mouse remap, smooth scroll** | – | Y (natural scrolling) | P | – | Y | – | – | – | – | **2** | **–** | Mos, BTT |
| Hide menu-bar icons | – | P (partial; private API on macOS 27) | P (menu-bar autohide) | – | – | – | – | – | – | **1** | **Y** (Pro) | Bartender, Ice/Thaw, iBar |
| **File shelf / drop zone** | – | – | – | – | – | – | Y | – | – | **1** | **–** | Dropover, Yoink, Unclutter, Bartender Top Shelf |
| **Camera preview / mic test** | – | – | – | – | – | – | – | – | Y | **1** | **–** | Hand Mirror, Sorhus Camera Preview |
| **Do Not Disturb / Focus toggle** | Y | – | – | – | – | – | – | – | – | **1** | **–** | — |
| **Temperatures / fan control** | – | – | – | – | Y (fan) | – | – | – | – | **1** | **–** (sandbox) | iStat Menus, Stats |
| **Battery charge limit** | – | – | – | – | Y | – | – | – | – | **1** | **–** (sandbox) | AlDente |
| World clock | – | – | – | – | – | Y | – | – | – | **1** | **Y** | Dato, iStat, Stats, Zone Bar |
| Next meeting / join | – | – | – | – | – | P (Calendar, Email) | – | – | Y (upcoming events) | **1–2** | **Y** (Pro) | MeetingBar, Dato |

**Unique differentiators seen only once (or in one class of app)**
- MaxCandela: **XDR/EDR brightness above the SDR ceiling**. None of the nine toolboxes advertises it. OnlySwitch's "Brightness" tab and MacTools' "brightness" control are not described as above-SDR — [OnlySwitch](https://github.com/jacklandrin/OnlySwitch); [MacTools](https://github.com/mactools-app/MacTools)
- Bartender Pro: **notch "Top Shelf"** (widgets + file shelf + clipboard in the notch), $15/yr — [Six Colors](https://sixcolors.com/post/2026/05/bartender-6s-new-pro-feature-turns-the-macbook-notch-into-a-dynamic-peninsula/)
- OnlySwitch: **Authenticator (TOTP)**, **Codex/Claude usage meters**, desktop pet, Tailscale toggle, Xcode cache cleaner — [OnlySwitch](https://github.com/jacklandrin/OnlySwitch)
- Barista: **stocks/crypto, RSS ticker, custom webpage widget, mini games (Minefield, 2048, Snake)**, email widget — [App Store](https://apps.apple.com/us/app/id6773448655)
- BarBox Tools: **batch rename, PDF merge**, Swiss finance rates, **mic-in-use indicator** — [App Store](https://apps.apple.com/app/id6802093315)
- Beaconly: **400+ service integrations** (Jira, GitHub PRs, Linear, cloud status) — [App Store](https://apps.apple.com/app/id1520138793)
- Pareto Security: **security posture checks** — [paretosecurity.com](https://paretosecurity.com/)
- HazeOver: **dim background windows** (per-window focus, unlike whole-screen dim) — [hazeover.com](https://hazeover.com/)
- Velja: **browser routing** — [sindresorhus.com/apps](https://sindresorhus.com/apps)
- Pandan: **time-awareness/activity timer** — [sindresorhus.com/apps](https://sindresorhus.com/apps)
- Clop: **auto-optimise images on copy** — [lowtechguys.com/clop](https://lowtechguys.com/clop/)
- Dato: **date/time calculator, floating clock, hourly chime** (Itsycal also has the chime) — [App Store](https://apps.apple.com/us/app/dato/id1470584107); [Itsycal](https://www.mowglii.com/itsycal/)
- Amphetamine: **trigger-based keep-awake** (by app, display, Wi-Fi, USB, CPU) — [App Store](https://apps.apple.com/us/app/amphetamine/id937984704)

### Inferences
- **Highest-value additions for MaxCandela** (table stakes it lacks, likely buildable with public API in the sandbox, though unverified):
  1. **QR code generate + scan from screen.** 4/9 toolboxes have it, and it reuses MaxCandela's existing OCR capture path (Vision detects barcodes alongside text).
  2. **Full calendar dropdown** (month grid + agenda). 4/9 toolboxes, plus Dato at $18 and Itsycal. MaxCandela already holds the EventKit entitlement for Next Meeting, so the marginal permission cost is zero.
  3. **Quick notes / scratchpad.** 3/9, plus Unclutter and Boop. No permission needed.
  4. **Calculator / unit and currency converter.** 3–4/9. Currency needs network; units don't.
  5. **Translate.** 4/9. Apple's on-device Translation framework may be usable; not checked here.
  6. **Bluetooth device battery / AirPods connect.** 3/9, plus iStat/Stats/MenuBar Stats. The repo notes say Bluetooth needs an entitlement; not re-verified.
  7. **Weather.** 2/9 toolboxes, plus iStat and Bartender Top Shelf. It needs location (prompt plus privacy label) or a typed city.
  8. **File shelf.** A whole paid category (Dropover, Yoink, Unclutter) and now in Bartender Pro. Drag-and-drop works in the sandbox, but this was not examined.
  9. **Camera preview + mic check** (Hand Mirror, SuperMenuBar). Camera entitlement and prompt.
  10. **Image compress/convert** (Clop, UtilsBar, BarBox).
- **System toggles (the One Switch class)**: Dark Mode, hide desktop icons, lock screen, display sleep, screen saver, empty trash, show hidden files, DND, resolution. They are common (3/9), but they cluster in **non-MAS** apps (One Switch, OnlySwitch, Supercharge). The repo's own notes list several as ruled out for the sandbox. Treat them as likely infeasible or high-review-risk rather than as easy wins. **Screen-clean / keyboard lock** may be the exception if done with a full-screen window plus a local event monitor instead of a system API; this was not researched.
- **Where MaxCandela is already ahead of the MAS toolbox crop**: Window Snapping, Hide Menu Bar Icons, OCR, a 200-item clipboard manager with pins, and the XDR boost. Barista, UtilsBar, BarBox and SuperMenuBar list none of window snapping, menu-bar hiding or brightness boost.
- The "switch hub" positioning (One Switch at ~$5, 98% on Setapp) and the "widget hub" positioning (Barista at $14.99) are both validated. MaxCandela sits between them with a display-tool core neither has.

### Gaps
- The matrix reflects *what each vendor lists*, not hands-on verification. A "–" may be an unlisted feature. Raycast in particular gains almost any tool through its free extension store, which this matrix does not count.
- Whether QR scanning, Translation, a Bluetooth battery read-out, weather or a camera preview are achievable within MaxCandela's existing sandbox/entitlements was not verified. These are inferences for the developer to check.
- iStat Menus and Bartender were not given matrix columns (they are covered in §2). Adding them would raise the counts for weather, calendar, world clock, Bluetooth battery and clipboard by one each.

---

## 4. Is there a Mac App Store app already positioned as a "toolbox of many small utilities"? Rating, price, reviews

### Takeaway
Yes, and it is a **crowded, very young category**. Barista ($14.99 unlock, "35+ menu bar widgets"), UtilsBar (free + $9.99 lifetime), BarBox Tools (free), SuperMenuBar (MAS, price unpublished), xMenuBarTools ($0.99) and Beaconly (free, 400+ integrations) all sell "many tools in one menu-bar app" on the MAS. None has an established rating base that could be verified. Most appear to have launched in 2025–2026, judging by their high app IDs and short version histories. The established, well-rated players doing "many utilities in one" (One Switch, Supercharge, OnlySwitch, MacTools, BetterTouchTool) are **outside the MAS**, which leaves the MAS slot for a *trusted, rated* toolbox open.

### Cited Findings
- **Barista: 35+ Menu Bar Widgets** (Konstantinos Mastorakis): 14-day free trial then **one-time $14.99 IAP** ("no subscription"). macOS 14+, Apple Silicon only. v1.0 dated "Jun 18" → v1.1.6 "Nov 1" (year not shown). Widgets: Calendar, Reminders, Email, Clipboard manager, Scratchpad, World Clocks, Event countdowns, Unit & currency converter, Calculator, Translate, QR code generator, Search; CPU, Memory, Battery, Network, Audio output, Caffeine; Weather, Stocks & crypto, RSS ticker, Webpage widget; Now Playing; games (Minefield, 2048, Snake); later added Command palette, Color Picker, Text Tools. **No ratings displayed** — [App Store](https://apps.apple.com/us/app/id6773448655)
- **UtilsBar** (Ly Hong Phat): **free + $9.99 "Premium LifeTime"**. macOS 13+, 2.5 MB. Clipboard manager (text/images/files, pin, search), OCR, markdown quick notes, file shelf, text utilities (case, trim, JSON, Base64), image conversion + PDF actions, calculator, unit conversion, colour readout, UUID + random strings. Offline, no account. **No ratings displayed** — [App Store](https://apps.apple.com/app/utilsbar/id6761060716)
- **BarBox Tools** (Albert Frick): **free, "no subscription, no in-app purchases, no advertising"**. v2.3 (Oct 29), macOS 14+, Apple Silicon. Live CPU/mem/GPU/disk, battery, Wi-Fi, Bluetooth battery, keep awake, image compression, OCR, PDF merge, QR generator, batch rename, clipboard history (20, memory only), timer, password/UUID generator, local/public IP, CHF FX + Swiss rates, weather, volume/output switcher/mic toggle + mic-in-use indicator, app launcher. **No ratings displayed** — [App Store](https://apps.apple.com/app/id6802093315)
- **SuperMenuBar**: on the MAS (id6759054080). Pomodoro timer, mini calendar (with Reminders/Calendar markers since a "Feb 25" update), Keep Awake (5 min to indefinite), Camera Preview + mic test, Mic mute with level meter, Mac Settings (Dock options, screenshot location/format). "Coming soon": Day Tracker, Color Picker. No price, developer name or rating on the site — [macsuperapp.com](https://macsuperapp.com/)
- **xMenuBarTools**: **$0.99**, v2.2 (11 Jul 2025), web apps/online tools in the menu bar; no ratings displayed — [App Store](https://apps.apple.com/bs/app/xmenubartools/id6469338732?mt=12)
- **Beaconly: Menu Bar Hub** (Martin Picha): **free**, macOS 15+, "400+ extensions" (Jira, Confluence, Asana, Linear, Trello, GitHub/GitLab PRs, cloud status); no ratings displayed — [App Store](https://apps.apple.com/app/id1520138793)
- Other MAS listings surfaced by search but not examined: Toggo – Menu Bar Quick Launch, Menu Bar Hub – Work Bench, Shortcuts in Menu Bar — [App Store: Toggo](https://apps.apple.com/app/6759539943); [App Store: Menu Bar Hub – Work Bench](https://apps.apple.com/py/app/menu-bar-hub-work-bench/id6747436885?mt=12); [App Store: Shortcuts in Menu Bar](https://apps.apple.com/us/app/shortcuts-in-menu-bar/id1471125513)
- **Review signals from adjacent MAS menu-bar apps** (the only ones with visible review data):
  - iBar Pro 4.6★/199: reviewers praise the menu-bar organisation ("replaced Bartender"). One asks for a clearer explanation of why it needs **Screen Recording** access — [App Store: iBar Pro reviews](https://apps.apple.com/us/app/ibar-pro-menubar-control-tool/id6737150304?mt=12&see-all=reviews&platform=mac)
  - iBar 4.5★/834: a 2025 review complains the app **became paid** and restricts use behind a purchase prompt — [App Store: iBar reviews](https://apps.apple.com/us/app/ibar-menubar-icon-control-tool/id6443843900?mt=12&see-all=reviews&platform=mac)
  - Menuist: a reviewer complains **every feature they wanted was greyed out unless they paid** — [App Store: Menuist](https://apps.apple.com/us/app/menuist-right-click-menubar/id6737160756?mt=12) (search summary)
  - One Switch (Setapp, not MAS) 98%/2,029: praise for simplicity; complaints about automation-permission prompts (Empty Trash), lock-screen bugs, a Bartender conflict, and requests for Bluetooth devices and a menu-bar-hide toggle — [Setapp reviews](https://setapp.com/apps/one-switch/customer-reviews)
- Non-MAS open-source toolboxes setting the "free" baseline: MacTools (GPL-3.0, 1.4k★), OnlySwitch (MIT, 6.1k★). Also mentioned in search but not examined: CalmBar (free OSS: fans/temps, charge limits, per-app volume, clipboard, screen recording) and Sidelet (27 utilities, waitlist) — [GitHub MacTools](https://github.com/mactools-app/MacTools); [GitHub OnlySwitch](https://github.com/jacklandrin/OnlySwitch); [search summary incl. menubar.tools / macnative.io](https://menubar.tools/)

### Inferences
- **Price anchors in the MAS toolbox niche**: free (BarBox, Beaconly), $0.99 (xMenuBarTools), $9.99 lifetime (UtilsBar, the same as MaxCandela's lifetime), $14.99 one-time (Barista). Freemium with a lifetime unlock is the dominant model. None of these uses a subscription.
- **Review risks to design against**, from adjacent apps: (1) "features greyed out unless you pay" (Menuist) and "free app became paid" (iBar) draw 1-star reviews. MaxCandela's "free tools, Pro display tools" split avoids the first; a 2.0 update that locks tools existing users had free would trigger the second. (2) Unexplained permission prompts (iBar's Screen Recording question) get called out. MaxCandela's OCR (Screen Recording), Window Snapping (Accessibility) and Calendar prompts need in-context explanations.
- The well-rated "many toggles in one" apps live on **Setapp / direct**, not the MAS, so a MaxCandela toolbox would not face an entrenched, highly rated MAS incumbent. Its rivals there are young apps with no visible rating base.
- Barista's widget list (weather, stocks, RSS, calculator, converter, translate, scratchpad, QR, games) is the clearest map of what a MAS-legal "widget toolbox" ships in 2026, and most of it needs no special entitlement beyond network.

### Gaps
- Real MAS star ratings and counts for Barista, UtilsBar, BarBox Tools, SuperMenuBar, xMenuBarTools and Beaconly could not be read (fetch limitation; see top caveat). They may have ratings in other storefronts.
- Launch dates are inferred from version histories with no year shown and from app-ID ranges. They are not confirmed.
- No editorial reviews (MacStories, 9to5Mac, The Sweet Setup) of Barista, UtilsBar, BarBox or SuperMenuBar were found in this pass. The MacStories OneMenu page returned 403.
- SuperMenuBar's price and developer identity are unpublished on its site.
