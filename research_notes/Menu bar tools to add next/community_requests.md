# Menu bar tools to add next: what Mac users ask for, complain about and wish existed (2024–2026)

> **Source access caveat, read first.** Reddit was not reachable from this research session. `old.reddit.com` fetches were refused, and web search restricted to `reddit.com` returned "domain not accessible to our user agent". A Medium roundup that claims to summarise Reddit returned HTTP 403. So **no r/macapps, r/MacOS, r/mac, r/macbookpro or r/apple thread was read directly**. The evidence below comes from Hacker News (Algolia API: stories, full comment trees and comment searches), one 2026 MacRumors forum thread, a GitHub issue, and press and vendor pages. The HN comment-search counts come from the first page of results only. Several pages were truncated, so treat every count as a **floor, not a total**. Each quote is under 15 words and links to its comment.
>
> Date context: today is 2026-11-22. macOS 26 Tahoe shipped in fall 2025. macOS 27 "Golden Gate" was announced on 2026-06-08 and has shipped (27.2 is referenced in the comments).

## Q1: What do Mac communities request most in menu-bar utilities (Reddit, HN, forums)?

### Takeaway
Across HN's 2024 and 2026 "new Mac setup" threads, the same core recurs: **window snapping (Rectangle/Magnet), a system monitor (Stats/iStat Menus), a menu-bar icon manager (Ice/Bartender/Hidden Bar), a launcher (Raycast/Alfred), a firewall (Little Snitch/LuLu) and a clipboard manager**. The market leaders for most of these are free or open source. The 2026 "Show HN" wave adds categories that did not exist before: **AI-usage meters, on-device dictation and developer port monitors**. Most of those are free and open source too.

### Cited Findings

**2026 baseline: "Ask HN: New clean macOS install. Must-have apps? Best browser?"** (June 2026; 19 points, 23 comments, 21 distinct commenters) — [HN 48643848](https://news.ycombinator.com/item?id=48643848)
- Number of distinct commenters recommending each app: Rectangle 4, Stats 3, Little Snitch 3, Raycast 2, Magnet 2, Ice 2, Karabiner 2. One each for Alfred, AltTab, BetterTouchTool, Hammerspoon, Shottr, MonitorControl, theBoringNotch, iStat Menus and ClipBook. — [HN 48643848](https://news.ycombinator.com/item?id=48643848)
- No commenter named Bartender, Hidden Bar, Maccy, Paste, Amphetamine, KeepingYouAwake, AlDente, Itsycal, MeetingBar, Dropover, Yoink, CleanShot or SoundSource. — [HN 48643848](https://news.ycombinator.com/item?id=48643848)
- Consolidation was preferred over adding another clipboard app: "for my needs, raycast suffices, and it is one less app to install." — [slipwalker, HN 48662872](https://news.ycombinator.com/item?id=48662872)
- One wish was to "block the constant communication with apple servers". — [unmanageduck, HN 48645694](https://news.ycombinator.com/item?id=48645694)

**2024 baseline: "Ask HN: How do you setup a new Mac?"** (Jan 2024; 33 points, 38 comments) — [HN 39163708](https://news.ycombinator.com/item?id=39163708)
- Tally: Little Snitch 5, Bartender 2, and one each for Rectangle, Amphetamine, Alfred, Moom, AlDente, Hammerspoon, Caffeine and BetterTouchTool. — [HN 39163708](https://news.ycombinator.com/item?id=39163708)
- Wishes:
  - "How do people usually deal with the lack of middle click?" — [trws, HN 39168360](https://news.ycombinator.com/item?id=39168360)
  - "the built in acceleration curve is absolutely maddening" — [n42, HN 39169052](https://news.ycombinator.com/item?id=39169052)
  - "I would like a better calendar app with a nicer UX" — [kingkongjaffa, HN 39164210](https://news.ycombinator.com/item?id=39164210)

**What builders launched on HN, 2024–2026** (337 "menu bar app mac" story matches since 2024; points and comments shown)
- Novelty: pISSStream, the ISS urine-tank menu bar app, 1139 pts / 253 comments (Dec 2024). — [HN 42505454](https://news.ycombinator.com/item?id=42505454)
- **AI-usage meters** are a 2026 menu-bar category. The leader is a Claude usage tracker at 161 pts / 49 comments (Jan 2026) — [HN 46544524](https://news.ycombinator.com/item?id=46544524). It was followed by at least five clones:
  - Claude Meter, 9 pts — [HN 46956460](https://news.ycombinator.com/item?id=46956460)
  - claudewatch, 5 pts — [HN 47781940](https://news.ycombinator.com/item?id=47781940)
  - ClaudeUsage, 5 pts — [HN 47101805](https://news.ycombinator.com/item?id=47101805)
  - Trackr Bar, 4 pts — [HN 48425401](https://news.ycombinator.com/item?id=48425401)
  - agentmuster, 3 pts — [HN 50078086](https://news.ycombinator.com/item?id=50078086)
- **On-device dictation**: Yap (open source), 104 pts / 44 comments (Jul 2026) — [HN 49073834](https://news.ycombinator.com/item?id=49073834). Also Looped Whisper [48711840](https://news.ycombinator.com/item?id=48711840), Pindrop [46828586](https://news.ycombinator.com/item?id=46828586), SpeechDock [47073859](https://news.ycombinator.com/item?id=47073859), Lautli [50443955](https://news.ycombinator.com/item?id=50443955), and an offline Whisper app at "One-time purchase - $29, no recurring fees" — [Othrya, HN 46777457](https://news.ycombinator.com/item?id=46777457).
- **Wrong-keyboard-layout fixer** (free): 74 pts / 46 comments (Jun 2026). — [HN 48575878](https://news.ycombinator.com/item?id=48575878)
- **HomeKit control from the menu bar** (Itsyhome, open source): 57 pts / 49 comments (Feb 2026). — [HN 46967898](https://news.ycombinator.com/item?id=46967898)
- **"Is tonight clear" astronomy weather** (Nightwatch): 89 pts / 28 comments (Oct 2026). — [HN 49952148](https://news.ycombinator.com/item?id=49952148)
- **Developer localhost port viewers and killers**, four separate launches at 3–4 pts each:
  - OpenPorts — [47301337](https://news.ycombinator.com/item?id=47301337)
  - Switchboard — [50183092](https://news.ycombinator.com/item?id=50183092)
  - LeftOpen — [49853806](https://news.ycombinator.com/item?id=49853806)
  - PortPilot — [45399906](https://news.ycombinator.com/item?id=45399906)
- Small native builds are pitched as a feature:
  - "Gauge, a 900 KB macOS menu bar app" for RAM and disk — [HN 50443654](https://news.ycombinator.com/item?id=50443654)
  - a menu bar to-do app in a "single Swift file" — [HN 47101847](https://news.ycombinator.com/item?id=47101847)
- Other niche launches:
  - SpinWin, rotates windows; 37 pts — [49049638](https://news.ycombinator.com/item?id=49049638)
  - Furwall, blocks keys when a cat sits on the keyboard; 8 pts — [48021665](https://news.ycombinator.com/item?id=48021665)
  - Offline Translate, menu bar; 6 pts, 2024 — [41636859](https://news.ycombinator.com/item?id=41636859)
  - USB Connection Info, on the App Store; 4 pts — [44400873](https://news.ycombinator.com/item?id=44400873)
  - Noject, stops drive-ejection warnings; 3 pts — [48569320](https://news.ycombinator.com/item?id=48569320)
  - Watts 3, battery health; 1 pt, 2024 — [40271965](https://news.ycombinator.com/item?id=40271965)
- Non-menu-bar Ask HN with real engagement: "How are most people converting HEIC to jpg?" (Dec 2025), 19 pts / 47 comments. — [HN 46326261](https://news.ycombinator.com/item?id=46326261)

**"I wish macOS had…" comments** (HN, 2024+, first page of results, 19 relevant comments)
- Window management was the most frequent wish (3), then touch Macs (3) and Finder (2): "I wish macOS had maximise buttons and window snapping." — [YPPH, HN 40935557](https://news.ycombinator.com/item?id=40935557)
- "separate apps needed for basic things like direction of scrolling" — [varispeed, HN 43204302](https://news.ycombinator.com/item?id=43204302)
- Clipboard: "I wish Ditto had copycats on linux and macos." (2024) — [onehair, HN 39880689](https://news.ycombinator.com/item?id=39880689)
- Built-in per-app network blocking: "I do wish macOS had some way you could enforce that" — [lathiat, HN 50081052](https://news.ycombinator.com/item?id=50081052)

**Secondary claim about Reddit (unverified)**
- A Medium post titled "Top 20 Mac Menu Bar Apps (2026): Every One Recommended by Real Users" reportedly lists the apps Reddit recommends most as Ice, Stats, Maccy, Amphetamine and Itsycal. It also reportedly says Maccy beats Paste ($4/month) "in almost every clipboard thread" and that Ice replaced Bartender for most Reddit users. **Only a search-engine summary was seen; the page returned 403.** — [Medium](https://medium.com/@wjzv8192/top-20-mac-menu-bar-apps-2026-every-one-recommended-by-real-users-a0a9244cf1f6)

### Inferences
- MaxCandela already covers most of the perennial "must-have" jobs: window snapping, system read-out, menu-bar hiding, clipboard and keep-awake. The leaders in each of those are free (Rectangle, Stats, Ice/Hidden Bar, Maccy, Amphetamine/KeepingYouAwake), so those tools are table stakes, not reasons to pay.
- Firewalls (Little Snitch) and launchers (Raycast/Alfred) are recommended as often as anything, but neither fits a sandboxed menu-bar toolbox.
- The fastest-growing 2026 categories (AI-usage meters, local dictation, port monitors) are developer-skewed and dominated by free open-source one-offs. They are low-points launches, so supply exceeds demonstrated demand.
- The HEIC→JPG Ask HN (47 comments) points to a "convert this file" job: image format, resize, compress. It suits a sandboxed app, because the user drags the file in.

### Gaps
- **No Reddit thread was read** (access blocked), so upvote counts from r/macapps and the other subreddits are missing. A human should check r/macapps's top posts from the past year ("menu bar", "wish", "looking for an app that").
- The Medium roundup could not be read (403).
- HN comment-search counts are from page 1 of each query only; totals are higher.
- Product Hunt comments, Apple Community and Mastodon/X were not searched (out of tool-call budget).

## Q2: What problems do users have with the macOS 26 Tahoe / macOS 27 menu bar and with notch MacBooks?

### Takeaway
**Icons silently disappearing behind the notch is the single most persistent menu-bar complaint.** It has been raised by many different people from 2025 through Oct 2026, and Apple has fixed it only in stages:
- **Tahoe:** per-icon show/hide toggles in System Settings, plus third-party Control Center controls.
- **macOS 27:** a native overflow arrow, according to a vendor source.

Each OS release has broken the third-party managers:
- Ice broke on Tahoe 26.2 and again on 27.
- Bartender broke on Tahoe.
- Hidden Bar reportedly broke on 27 beta 1.

The leading options also carry trust baggage: Bartender's 2024 sale, a screen-recording indicator, and Ice looking unmaintained.

### Cited Findings

**The notch and overflow problem: at least 22 distinct HN comments in 2025–2026 on the first results page**
- "when you run out of menu space things just disappear." — [wlesieutre, HN 46143684](https://news.ycombinator.com/item?id=46143684) (Dec 2025)
- "The notch hiding menubar icons is such a stupid problem to have." This commenter also says Bartender broke on Tahoe because of API changes. — [alin23, HN 47619626](https://news.ycombinator.com/item?id=47619626) (Apr 2026)
- "Apple hasn't provided a simple UI indicator that some icons are hidden." — [fogzen, HN 47623299](https://news.ycombinator.com/item?id=47623299)
- Icon spacing has widened since about Sonoma, so fewer icons fit. — [badc0ffee, HN 47619168](https://news.ycombinator.com/item?id=47619168)
- Wide app menus such as Xcode's cover status icons even on notched MacBooks. — [data-ottawa, HN 47619268](https://news.ycombinator.com/item?id=47619268)
- One user can no longer see menu bar apps with 11 third-party icons and bought "notch optimizer" apps. — [ncr100, HN 46447082](https://news.ycombinator.com/item?id=46447082)
- "Lack of menu bar overflow on MacOS is awful." The commenter recommends Ice, with a caveat about an "ownership change". — [SmasherEpilepti, HN 49734278](https://news.ycombinator.com/item?id=49734278) (Sep 2026, macOS 27 review thread). *No evidence was found that Ice changed hands. A search found only Bartender's 2024 sale and the Ice forks (IceMelt, Thaw), so this may be a mix-up.* — [IceMelt](https://github.com/pnikolaidis/icemelt), [Thaw](https://github.com/stonerl/thaw)
- Workarounds:
  - Set a 16:10 resolution so the menu bar sits below the notch — [gommm, HN 44910841](https://news.ycombinator.com/item?id=44910841)
  - BetterDisplay or Say No To Notch to push the menu bar down — [lloeki, HN 45260500](https://news.ycombinator.com/item?id=45260500)
  - theBoringNotch to *use* the notch — [slipwalker, HN 48660567](https://news.ycombinator.com/item?id=48660567)

**What Apple changed**
- Tahoe: System Settings has per-icon show/hide toggles, and Command-drag rearranges icons. — [Badgeify (vendor)](https://badgeify.app/macos-27-golden-gate-menu-bar-changes/). A user called this "Apple has finally provided a half-solution". — [crazygringo, HN 47619394](https://news.ycombinator.com/item?id=47619394)
- Tahoe lets third-party apps offer controls in Control Center, suggested as a way to shrink the menu bar: "Starting with Tahoe, these can be offered by third-party apps". — [PotentPeas, MacRumors, Jan 2026](https://forums.macrumors.com/threads/best-bartender-replacement-fur-2026.2476628/)
- macOS 27 (WWDC 2026-06-08):
  - The menu bar is reportedly "rendered as a single window", which removes the per-item windows that managers relied on.
  - A native expand/collapse arrow handles overflow near the notch.
  - On beta 1 these managers were reported broken: Ice, Thaw, Bartender, Barbee, Sane Bar, Glow and **Hidden Bar**. BetterTouchTool shipped a partial workaround.

  *Source is a vendor blog selling a competing app; it reflects beta 1 as of 2026-06-11.* — [Badgeify](https://badgeify.app/macos-27-golden-gate-menu-bar-changes/). Badgeify points to this BetterTouchTool community thread, which was not read: [folivora.ai](https://community.folivora.ai/t/macos-27-golden-gate-menu-bar-management-broken-solutions-ice-thaw-bartender-barbee-etc/47232)
- A Nov 20 2026 comment under "Show HN: ClearBar – menu bar manager for Mac – alternative to Bartender": "Since switching to version 27.2, that need has gone away for now." *This most likely means macOS 27.2's native handling, but it is ambiguous.* — [alexpua, HN 50573415](https://news.ycombinator.com/item?id=50573415)

**Breakage and trust problems with the existing managers**
- Ice issue #954, "Ice in menu bar not working anymore (MacOS Golden Gate 27)":
  - Opened 2026-06-08, about 55 👍, still open with no maintainer reply.
  - "Ice stopped working for me the day I moved to 27."
  - One commenter claims the last commit was in Sep 2025 (unverified).
  - Users point to forks (Thaw, cavaldos/Ice, amichaelyu/Ice), Brow, Pelmet and a Bartender 27 beta.

  — [GitHub](https://github.com/jordanbaird/Ice/issues/954)
- MacRumors "Best Bartender replacement für 2026" (Jan 25–30 2026, 16 posts) — [MacRumors](https://forums.macrumors.com/threads/best-bartender-replacement-fur-2026.2476628/):
  - Hidden Bar was the most-recommended option (3 explicit), then Bartender 6 (2), Ice (it broke for 2 users) and BetterTouchTool (1).
  - Ice "stopped working in 26.2" (Mike Boreham).
  - Hidden Bar "has worked thru every beta & official version of tahoe" (fisherking).
  - On Bartender's screen-recording indicator: "some app is watching your screen" (PotentPeas).
  - Even with Hidden Bar, items still end up behind the notch: "I sometimes have enough items to have some of the hidden by the notch" (PotentPeas).
  - "Apple hasn't provided a native solution to menu bar crowding" (mansplains).
  - On ownership: "since Bartender was taken over by some strange company" (OP szilske).
- Bartender's quiet 2024 sale:
  - AppleInsider: the new owner "has burnt years of good-will with a lack of transparency" (2024-06-05) — [AppleInsider](https://appleinsider.com/articles/24/06/05/bartender-apps-new-owner-has-burnt-years-of-good-will-with-a-lack-of-transparency)
  - The developer confirmed the sale — [9to5Mac](https://9to5mac.com/2024/06/06/bartenders-developer-confirms-apps-acquisition/)
  - MacRumors PSA thread, 8+ pages — [MacRumors](https://forums.macrumors.com/threads/psa-bartender-mac-app-under-new-ownership-but-lack-of-transparency-raises-concerns.2428159/page-2)
- New entrants keep launching:
  - ClearBar (Nov 2026) — [HN 50573415](https://news.ycombinator.com/item?id=50573415)
  - Lounge, $3.99/yr (self-promotion) — [HN 47815606](https://news.ycombinator.com/item?id=47815606)
  - Badgeify, Pelmet and Brow (sources above)

**Other Tahoe regressions that hit utilities**
- macOS 26 hands dragged files to apps as `com.apple.SwiftUI.Drag-` temporary paths, which breaks "file shelf apps like Yoink, Dropover etc." — [alin23, HN 47442781](https://news.ycombinator.com/item?id=47442781)
- After the Tahoe windowing changes, a CleanShot screenshot "resets the DisplayPort driver". — [michaelbuckbee, HN 47224675](https://news.ycombinator.com/item?id=47224675)

### Inferences
- **Directly relevant to MaxCandela's "Hide Menu Bar Icons" Pro tool.** It uses the Hidden Bar divider technique.
  - On Tahoe, Hidden Bar reportedly kept working, which suggests the technique held.
  - On macOS 27 beta 1, Hidden Bar was reported broken, and macOS 27 adds a native overflow arrow. One Nov 2026 user says the need "has gone away" since 27.2.
  - So on the current OS the tool may be **broken, redundant, or both**. It needs a check on a real macOS 27.x Mac before it is marketed as a paid-app stand-in.
  - The project's CLAUDE.md already lists this tool as "Unseen".
- Menu-bar managers are a treadmill: every major release breaks them, and users distrust the paid leader (Bartender). A small app that depends on undocumented window behaviour takes on the same maintenance risk.
- The notch problem cuts both ways for MaxCandela. Its single ☀️ icon is a selling point ("one icon instead of ten"), but if the icon itself lands behind the notch, the app and its first-run popover are invisible.
- Exposing the boost, Keep Awake or mic mute as **Tahoe Control Center controls** would answer the "shrink the menu bar" request. That needs macOS 26 APIs behind availability checks, because the shipping target is macOS 15.6.

### Gaps
- No primary source (Apple documentation or release notes) was read for the macOS 27 single-window menu bar or the overflow arrow; that claim comes from a vendor blog's beta-1 snapshot. Hidden Bar's status on the shipping 27.x is unconfirmed.
- It was not verified whether Tahoe Control Center controls are available to sandboxed Mac App Store apps on macOS.
- Reddit's r/MacOS Tahoe and notch threads could not be read.

## Q3: All-in-one toolboxes (One Switch, Raycast, BetterTouchTool, iStat Menus, Setapp) versus single-purpose apps

### Takeaway
People consolidate when an app they already have covers the job ("one less app to install"; BetterTouchTool "useful if you've already got the app"). For core jobs, though, they pick best-in-class single apps, and they punish bloat, menu-bar space hogs and battery drain. Setapp's bundle has more defenders than critics on HN, but "you own nothing when you stop" and price rises are the recurring objections. One Switch, the closest analogue to MaxCandela, has almost no community footprint.

### Cited Findings
- Raycast as a consolidator: "for my needs, raycast suffices, and it is one less app to install." — [slipwalker, HN 48662872](https://news.ycombinator.com/item?id=48662872)
- Raycast's floating notes beat dedicated note apps: "Has worked for me better than Notion, Obsidian, Reminders, Tick Tick, etc." — [Gbox4, HN 39433899](https://news.ycombinator.com/item?id=39433899)
- Raycast integration friction: "it is not really possible to use them with AeroSpace." — [wmstack, HN 40604206](https://news.ycombinator.com/item?id=40604206)
- Raycast HN sample from a "Raycast bloat" search (only 9 relevant comments): 4 pro, 3 mixed, 2 con. One commenter wished all Mac apps were AppKit. — [goranmoomin, HN 48729902](https://news.ycombinator.com/item?id=48729902)
- Both kinds side by side: "Raycast and iStat Menus, while different, are awesome in their own way." — [pants2, HN 45451005](https://news.ycombinator.com/item?id=45451005)
- BetterTouchTool as a menu-bar manager is "useful if you've already got the app for other reasons". The same poster says paying for it only for menu bar management isn't worth it. — [Apathist, MacRumors](https://forums.macrumors.com/threads/best-bartender-replacement-fur-2026.2476628/)
- iStat Menus complaints:
  - "it can take a lot of space!" — [corlinp, HN 47621875](https://news.ycombinator.com/item?id=47621875)
  - battery drain and its own daemons: "it made a sizable dent on my battery life" — [bayindirh, HN 38886581](https://news.ycombinator.com/item?id=38886581)
- Stats complaints:
  - "the text in the menu bar is too thin for my eyes" — [msephton, HN 42883937](https://news.ycombinator.com/item?id=42883937)
  - "Stats would use quite a bit more CPU usage compared to" iStat Menus — [SG-, HN 42887264](https://news.ycombinator.com/item?id=42887264)
- Redundancy resistance: "thought buying another status menu app would be redundant" — [yardie, HN 45250232](https://news.ycombinator.com/item?id=45250232)
- Small and native as a value: "no Electron, no RAM bloat." — [aarush-prakash, HN 47081715](https://news.ycombinator.com/item?id=47081715)
- **Setapp** (HN comments 2024–2026, first results page): 18 pro, 4 con, 3 mixed, 7 neutral.
  - Pro: "For $5 more I can have 260+ apps with Setapp." — [fearoffish, HN 45457656](https://news.ycombinator.com/item?id=45457656)
  - Pro: "it's curated and I don't have to worry about filtering" — [TehShrike, HN 45250109](https://news.ycombinator.com/item?id=45250109)
  - Con: "once you stop, you've little to show for it." — [port11, HN 45827516](https://news.ycombinator.com/item?id=45827516)
  - Con: "I used a bunch of tools from Setapp and no longer subscribe." — [bdangubic, HN 47379135](https://news.ycombinator.com/item?id=47379135)
  - Price complaints on 2025-09-15: "What is worth $33 a month there?" — [r0fl, HN 45250156](https://news.ycombinator.com/item?id=45250156). Also "subscription price went from $10 to $30+" — [aegypti, HN 45250291](https://news.ycombinator.com/item?id=45250291). *Which product was repriced is unclear from the snippet.*
  - One user's reason to keep a Setapp app is "mostly for posture reminders". — [murats, HN 48710091](https://news.ycombinator.com/item?id=48710091)
- **One Switch**: a $5 one-time purchase. It toggles hide desktop, Dark Mode, keep awake and screen saver, and connects AirPods. AlternativeTo shows "No comments or reviews". — [AlternativeTo](https://alternativeto.net/software/one-switch/about)

### Inferences
- The all-in-one pitch wins when it removes icons and installs. That ties straight into the notch-crowding pain in Q2, which makes "one menu-bar icon" MaxCandela's strongest framing.
- Each tool inside the toolbox will still be compared with the free single-purpose leader for its job. The tools that a free leader doesn't do well (screenshot annotation, menu-bar calendar, file conversion) are where a bundle can stand out.
- Resource cost (battery, CPU, menu-bar width) is a stated reason people drop monitors, so an always-on System read-out should stay cheap and compact.

### Gaps
- No direct user comparison of One Switch versus Raycast versus BetterTouchTool was found. Reddit would be the likeliest source.
- Raycast-specific complaints about AI features, accounts or the Pro subscription did not show up in the HN sample.

## Q4: What will people pay for versus expect free? Subscription fatigue

### Takeaway
Mac users and indie developers overwhelmingly frame **one-time purchase with no subscription** as the virtue, and many 2024–2026 Show HN posts lead with it. A small minority defends subscriptions as the price of ongoing upkeep. People pay for depth and polish: CleanShot X at $30 one-time and iStat Menus about $12 are cited as fair. Simple toggles and monitors are expected free, because free open-source leaders exist.

### Cited Findings
- Subscription fatigue as an explicit motive: "frustrated with subscription fatigue" — [jantheman, HN 47012943](https://news.ycombinator.com/item?id=47012943)
- Devs leading with no subscription:
  - "There are NO subscriptions, ads, trackers, analytics or other nonsense". This is MenuTimer, a **menu-bar timer** that competes with MaxCandela's Timer. — [busymom0, HN 39072450](https://news.ycombinator.com/item?id=39072450)
  - "Lifetime one-time purchase (for those who hate subscriptions)" — [ismailcarlik, HN 46985602](https://news.ycombinator.com/item?id=46985602)
  - "It's a one time $2.99 purchase, with no account or subscription" — [code_devil, HN 49695017](https://news.ycombinator.com/item?id=49695017)
- Buyer stance: "If app offers one time purchase - I'll buy it if I like it." — [beretguy, HN 40259274](https://news.ycombinator.com/item?id=40259274)
- Counter-view:
  - "The point of a subscription is not to rip you off" — [xp84, HN 46853934](https://news.ycombinator.com/item?id=46853934)
  - "Not a fan of subscriptions too but hard to have ongoing support" — [docstryder, HN 48137064](https://news.ycombinator.com/item?id=48137064)
- "Would you pay $19 for this Mac menubar app?" (Dec 2024, 13 pts / 19 comments; a Stripe/Paddle revenue viewer) — [HN 42482286](https://news.ycombinator.com/item?id=42482286):
  - "$19 forever seems fine" — [fragmede, HN 42485028](https://news.ycombinator.com/item?id=42485028). The same comment cites iStat Menus at $11.99 single and $14.99 family.
  - "if it is worth $19, it is worth $99" — [brudgers, HN 42483291](https://news.ycombinator.com/item?id=42483291)
  - Skeptics: "I wouldn't buy this" — [dimitrisnl, HN 42484960](https://news.ycombinator.com/item?id=42484960)
  - Commenters asked for a trial or refund rather than freemium with ads. — [sgt, HN 42488576](https://news.ycombinator.com/item?id=42488576)
- Screenshots:
  - "I use CleanShot X and it was a one-time $30 payment" — [Shank, HN 46717351](https://news.ycombinator.com/item?id=46717351)
  - "the cloud hosting aspect is overpriced" — [joshstrange, HN 45826010](https://news.ycombinator.com/item?id=45826010)
  - "I got tired of paying for cleanshotx and missing features in shottr" — [razyoudude, HN 49241402](https://news.ycombinator.com/item?id=49241402)
- Battery limiter: AlDente's free tier is often enough: "even the free version works fine." — [sqbic, HN 47263845](https://news.ycombinator.com/item?id=47263845)
- Free open-source leaders cited for MaxCandela's existing jobs:
  - Stats ("a great open source alternative to the iStat Menus") — [barnabee, HN 38884606](https://news.ycombinator.com/item?id=38884606)
  - Thaw (GPL-3.0) — [GitHub](https://github.com/stonerl/thaw)
  - Ice and its forks — [GitHub](https://github.com/jordanbaird/Ice/issues/954)
  - Hidden Bar ("Free, basic") — [MacRumors](https://forums.macrumors.com/threads/best-bartender-replacement-fur-2026.2476628/)
- Paid menu-bar managers are being undercut. Lounge launched at $3.99/yr (self-promotion). — [HN 47815606](https://news.ycombinator.com/item?id=47815606)

### Inferences
- MaxCandela's **$9.99 lifetime** sits in the band people call fair: below CleanShot at $30, near iStat Menus at about $12, and under the $19 that one thread accepted. The "one purchase, no subscription required" message should lead the store page. The $0.99/mo option is acceptable as long as it is clearly optional.
- Free tools such as Keep Awake, the Timer, the System read-out and clipboard history face free open-source rivals and cannot be the reason to buy. Paid value has to come from things free leaders do poorly, plus the convenience of one icon.
- Paid incumbents that switched to subscriptions or recurring cloud fees (CleanShot Cloud, Setapp price rises) leave openings for a one-time-priced alternative.

### Gaps
- No quantified survey data on Mac subscription fatigue was found. The evidence is anecdotal and skewed toward HN developers, many of whom are promoting their own apps.
- No direct evidence was found on prices people accept for a *toolbox* bundle, as opposed to single apps.

## Q5: Needs MaxCandela does NOT yet cover, and how well each is evidenced

### Takeaway
The best-evidenced uncovered needs fall into three groups:
- **Fit for a sandboxed App Store toolbox:** screenshot capture and annotation (CleanShot/Shottr demand, cloud-price complaints), a menu-bar calendar dropdown (extends the existing EventKit tool), file conversion (HEIC→JPG), notch hiding, and Control Center controls.
- **Strong demand but blocked by the sandbox or already built into macOS:** battery charge limit (now native in macOS 26.4), external-monitor brightness (DDC is private API), firewall, and mouse fixes.
- **Crowded with free open-source apps:** dictation and AI-usage meters.

Many items on the brief's checklist had **no evidence** in the sources that could be read.

### Cited Findings

| Need (one line) | Recurrence found | Representative quote | Apps people recommend (price model) | Complaints about existing apps | Fit for MaxCandela (inference) |
|---|---|---|---|---|---|
| **Screenshot capture + annotation** (arrows, blur, scrolling, video) | 6 positive CleanShot mentions and 4 critical/mixed in an HN 2025–26 sample; Shottr recommended; 3 DIY builds | "CleanShot X is extremely good" — [tptacek, HN 45826157](https://news.ycombinator.com/item?id=45826157) | CleanShot X ($30 one-time per [Shank](https://news.ycombinator.com/item?id=46717351); paid cloud), Shottr ([muzani](https://news.ycombinator.com/item?id=44797955)), Bettershot (open source) ([geekybiz](https://news.ycombinator.com/item?id=46691369)) | Cloud "overpriced" ([joshstrange](https://news.ycombinator.com/item?id=45826010)); "tired of paying" and Shottr "missing features" ([razyoudude](https://news.ycombinator.com/item?id=49241402)); Tahoe DisplayPort reset ([michaelbuckbee](https://news.ycombinator.com/item?id=47224675)) | Good. MaxCandela already holds Screen Recording permission for Copy Text from Screen, so capture → annotate → copy is an extension. |
| **Battery charge limit** (stop at 80%, "sailing") | AlDente: 21 genuine HN mentions by 18 authors, 2024–2026 | "Get Al Dente Pro and set your battery to 80%" — [mbesto, HN 44842793](https://news.ycombinator.com/item?id=44842793) | AlDente (free tier "works fine"; Pro paid), [sqbic](https://news.ycombinator.com/item?id=47263845) | Limit overshot overnight, set 80% and reached 87% ([mrheosuper](https://news.ycombinator.com/item?id=44860446)). **macOS 26.4 beta added native charging limits**, and one user uninstalled AlDente after Apple's 80% feature ([sqbic](https://news.ycombinator.com/item?id=47263845), [ffsm8](https://news.ycombinator.com/item?id=42965880)) | Poor. Writing charge limits needs SMC access and a privileged helper, which the sandbox forbids (project CLAUDE.md, Thermal section), and macOS now ships it. The System tool's existing battery health and cycles read-out is the sandbox-safe slice. |
| **Menu-bar overflow / notch** | ~22 HN comments in 2025–26 + a 16-post MacRumors thread + about 55 👍 on GitHub | "when you run out of menu space things just disappear." — [HN 46143684](https://news.ycombinator.com/item?id=46143684) | Ice / Thaw / IceMelt (free, open source), Hidden Bar (free), Bartender 6 (paid), BetterTouchTool (paid) | Breakage on 26.2 and 27; Bartender ownership; screen-recording dot ([MacRumors](https://forums.macrumors.com/threads/best-bartender-replacement-fur-2026.2476628/)) | **Already covered**, but at risk on macOS 27. See Q2. |
| **Notch hider / notch utility** | 4+ HN mentions | BetterDisplay or "Say No To Notch" pushes the menu bar down ([lloeki](https://news.ycombinator.com/item?id=45260500)) | BetterDisplay, Say No To Notch, theBoringNotch ([slipwalker](https://news.ycombinator.com/item?id=48660567); also in the [2026 Ask HN](https://news.ycombinator.com/item?id=48643848)) | "notch optimizer" apps bought out of frustration ([ncr100](https://news.ycombinator.com/item?id=46447082)) | Plausible. A display tool fits the brand. Sandbox feasibility of changing display mode or drawing a black bar was not verified. |
| **Menu-bar calendar dropdown** | 1 explicit wish (2024); Itsycal named in a secondary Reddit roundup; a new calendar Show HN (2026) | "I would like a better calendar app with a nicer UX" — [HN 39164210](https://news.ycombinator.com/item?id=39164210) | Itsycal (free; [Medium, unverified](https://medium.com/@wjzv8192/top-20-mac-menu-bar-apps-2026-every-one-recommended-by-real-users-a0a9244cf1f6)), calendar0 ([HN 50086619](https://news.ycombinator.com/item?id=50086619)) | Not found | Good. Next Meeting already has EventKit and the calendar entitlement, so a month grid is a small step. |
| **On-device dictation / transcription** | Yap 104 pts / 44 comments + at least 6 more Show HNs in 2026 | "One-time purchase - $29, no recurring fees" — [HN 46777457](https://news.ycombinator.com/item?id=46777457) | Yap, Looped Whisper, Pindrop (all open source), paid Whisper apps | Crowded, many free options | Weak. Typing into the front app needs Accessibility, and the category is saturated. |
| **AI usage / rate-limit meter** (Claude, Codex, Cursor) | 161 pts / 49 comments + at least 5 clones | "macOS menu bar app to track Claude usage in real time" — [HN 46544524](https://news.ycombinator.com/item?id=46544524) | All free / open source on GitHub | Not found | Weak. Developer niche, fast-moving APIs and credential handling. |
| **Developer port viewer / killer** | 4 Show HNs, 3–4 pts each | "see and kill listening ports" — [HN 47301337](https://news.ycombinator.com/item?id=47301337) | OpenPorts, Switchboard, LeftOpen, PortPilot (open source) | Not found | Weak. Low demand, and the sandbox likely blocks enumerating or killing other processes' sockets (unverified). |
| **Wrong-keyboard-layout fixer** | 74 pts / 46 comments (2026) | "fixes typing in the wrong keyboard layout" — [HN 48575878](https://news.ycombinator.com/item?id=48575878) | flickey (free) | Not found | Weak. Needs keystroke monitoring, a privacy-heavy permission. |
| **HomeKit control in the menu bar** | 57 pts / 49 comments | "Control HomeKit from your Mac menu bar" — [HN 46967898](https://news.ycombinator.com/item?id=46967898) | Itsyhome (open source) | Not found | Unknown. HomeKit framework availability for a native AppKit Mac app was not verified. |
| **File conversion** (HEIC→JPG, etc.) | Ask HN 19 pts / 47 comments (Dec 2025) | "How are most people converting HEIC to jpg?" — [HN 46326261](https://news.ycombinator.com/item?id=46326261) | Thread not read; recommendations unknown | Not read | Good. Drag-in conversion via ImageIO works with sandbox user-selected files. The thread's answers should be read before building. |
| **Mouse fixes** (middle click, acceleration, scroll direction) | 3 comments (2024–25) | "separate apps needed for basic things like direction of scrolling" — [HN 43204302](https://news.ycombinator.com/item?id=43204302) | LinearMouse (named in the 2024 thread, not tallied), BetterTouchTool | Not found | Weak. Event taps need Accessibility or Input Monitoring. |
| **Per-app network blocking / firewall** | Little Snitch: 5 recommendations (2024) and 3 (2026) | "I do wish macOS had some way you could enforce that" — [HN 50081052](https://news.ycombinator.com/item?id=50081052) | Little Snitch (paid), LuLu (free) | Not found | Out of scope (network extension). |
| **External-monitor brightness** | MonitorControl: 1 in the 2026 Ask HN | (tally only) — [HN 48643848](https://news.ycombinator.com/item?id=48643848) | MonitorControl (open source), BetterDisplay | Not found | Ruled out earlier: DDC is private API (project CLAUDE.md). |
| **File shelf / drag stash** | 1 HN comment, about a macOS 26 breakage | "file shelf apps like Yoink, Dropover etc." — [HN 47442781](https://news.ycombinator.com/item?id=47442781) | Yoink, Dropover (paid) | macOS 26 drag paths break them | Unclear. Little evidence in what could be read. |
| **Break / posture reminders** | 1 HN comment | "mostly for posture reminders" — [HN 48710091](https://news.ycombinator.com/item?id=48710091) | A Setapp app (unnamed in the snippet) | Not found | Feasible (already on the CLAUDE.md "feasible next" list), weak evidence. |
| **Keyboard lock** (cat / cleaning) | 1 Show HN, 8 pts | "blocks keys when your cat sits down" — [HN 48021665](https://news.ycombinator.com/item?id=48021665) | Furwall | Not found | Weak evidence, and it needs input interception. |
| **Offline translation** | 1 Show HN, 6 pts (2024) | "Privacy-Friendly Menu Bar App" — [HN 41636859](https://news.ycombinator.com/item?id=41636859) | Offline Translate (App Store) | Not found | Weak evidence. |
| **Quick notes / to-do in the menu bar** | 1 Show HN (1 pt) + Raycast notes praise | "Has worked for me better than Notion, Obsidian, Reminders" — [HN 39433899](https://news.ycombinator.com/item?id=39433899) | Raycast Notes (free tier), littletodo (open source) | Not found | Feasible (scratchpad is on the CLAUDE.md list), moderate-to-weak evidence. |

**Already-covered MaxCandela jobs and the free incumbents they face** (from the threads above)
- Keep Awake: Amphetamine and Caffeine — [HN 39163708](https://news.ycombinator.com/item?id=39163708)
- Timer: MenuTimer ("NO subscriptions") — [HN 39072450](https://news.ycombinator.com/item?id=39072450)
- Window snapping: Rectangle (the top pick in 2026) and Magnet — [HN 48643848](https://news.ycombinator.com/item?id=48643848)
- System read-out: Stats and iStat Menus — [HN 48643848](https://news.ycombinator.com/item?id=48643848)
- Clipboard: ClipBook, with Raycast "suffices" — [HN 48662872](https://news.ycombinator.com/item?id=48662872)

### Inferences
- **Best candidates to build next**, judged on evidence, sandbox fit and paid potential:
  1. Screenshot capture and annotate. It reuses the existing Screen Recording permission, and the paid incumbents draw complaints.
  2. A menu-bar calendar month view. It reuses the existing EventKit access.
  3. Drag-in file and image conversion (HEIC→JPG, resize, compress).
  4. Control Center controls on Tahoe+, which act on the overflow pain.
  5. A notch-hiding display option, if it is feasible in the sandbox; it fits the brightness and display brand.
- **Avoid:** battery charge limit (sandbox-impossible and now built into macOS 26.4), DDC monitor brightness (private API), firewall, mouse remapping, dictation and AI-usage meters (crowded with free open-source tools, or permission-heavy).
- The strongest "pay for it" signal is wanting **fewer apps and fewer icons**, given notch crowding. That supports MaxCandela's one-icon bundle better than any single new tool does.

### Gaps
- **No evidence was found, in the sources that could be read, for:** Bluetooth/AirPods quick connect, Wi-Fi or network speed, pomodoro/focus timer, unit or currency converter, text expansion/snippets, app quitter, camera mirror, mouse jiggler, cursor highlighter, presentation mode, resolution switcher and weather (beyond the Nightwatch astronomy niche: [HN 49952148](https://news.ycombinator.com/item?id=49952148)). Reddit, which was blocked, is where these "is there an app that…" requests usually live, so their absence here is **not** evidence of low demand.
- The HEIC Ask HN thread's answers were not read, so the tools people actually recommend for conversion are unknown.
- Sandbox feasibility was not verified for notch hiding, HomeKit or Control Center controls on macOS.
- Prices for Magnet, Itsycal, Yoink/Dropover, AlDente Pro and Shottr were not verified in this session.
