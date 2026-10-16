# Monke — Habit Game: reverse-engineering teardown

Date: 2026-10-16. Target: "Monke - Habit Game", App Store id 6755640836 (seller Myles Nicholas Root),
Android `com.kitemasters.monkeandroid`, web focus timer at staymonke.com/focus.

## Evidence and method

| Source | What it gave | Where |
|---|---|---|
| iTunes lookup API | full description, version, ratings (4.84 / 1,960) | `research/monke/lookup.json` |
| 7 App Store screenshots (1242x2688) | every primary screen, HUD, copy | `research/monke/screens/1-7.jpg` |
| Version history 1.2.5 → 1.5.3 (26 releases, Jan–Sep 2026) | the full mechanic list and how it evolved | below |
| 86 App Store reviews (RSS) | what users love / hate | `research/monke/reviews.txt` |
| staymonke.com/focus web app (shipped JS) | backend, sync protocol, deep links, timer defaults | `research/monke/web-focus/` |
| **REA** `analyze-javascript-application` on the web app | evidence `ev_2f36d483…de2c`, graph of the sync module | `research/monke/rea-web-focus.json` |

REA scope note: REA analyses shipped artifacts. The iOS IPA is FairPlay-encrypted and needs a jailbroken
device to decrypt, so it was not analysed. The Android APK (`com.kitemasters.monkeandroid`) was attempted on
2026-10-16 with apkeep for static-only REA `inspect_android_package`: APKPure lists no versions (and returns 403),
and APKMirror has no listing. Google Play download needs the owner's Google account token, which is an owner decision.
The web app is Monke's own shipped code and was analysed directly. REA limitation recorded: the
1 inline script in `index.html` (timer logic) is not in the REA graph; I read it by hand instead.

**Observed** = seen in screenshots, code or release notes. **Inferred** = my reasoning.

## 1. Core loop (observed)

```
do habit / focus / task / daily challenge
        → earn BANANAS (currency) + XP (level) + streak fire
        → spend bananas in SHOP on decorations, land, terrain
        → island visibly grows (empty raft island → village "haven")
        → come back tomorrow (check-in, streak, notifications, league)
```

The world is the reward, and it shows your history at a glance. An empty island means you haven't
shown up, and a lush island is proof you have.

## 2. Currencies and progression (observed, numbers where published)

- **Bananas**: the single soft currency. They used to sit beside coconuts until 1.3.2 converted everything to bananas.
  - To-do task = **5 bananas**. Daily challenge = **+20**.
  - Each habit card shows its own multiplier ("5x", "10x", "15x"). Reward is weighted per habit.
  - Streak bonus is shown on the card ("+2 streak bonus").
  - Hardcore focus = **1.5x** bananas, with a **penalty for stopping early**.
  - Terrain paint = **10 bananas per tile**. Pond = 300. Treehouse = 500. Extra islands (3x3 → 7x7) are bought with bananas.
  - **Bananas also buy screen time**: daily app limits and "bananas to unblock" (1.4.8, 1.5.2). The currency has a real cost.
- **XP / Level**: **1 XP per focus minute** levels the main Monke ("Lvl 45" in the HUD with a progress bar).
- **Streak (fire icon)**: a "Perfect Day" streak.
  - Since 1.3.0, missing one day doesn't break it.
  - A "Strict streak" option exists (1.4.2).
  - **Streak Potions** auto-save a missed day; since 1.4.8 you choose whether to spend one.
- **Characters**: unlockable Monkes of varying rarity. A focus session gives a chance to unlock one. Some items are level-gated.
- **Passive income**: Farmer Monke harvests wheat (1.4.5).
- **Leagues** (1.4.7): weekly Bronze → Silver → Golden with promotion and relegation. Points come from habits and focus.
  Leaderboards run daily, weekly and all-time. Discord guild battles and roles.

## 3. Screens (observed from screenshots)

1. **World (home)**
   - Full-bleed isometric island.
   - HUD pill at the top: `Lvl | 🔥streak | 🍌balance`.
   - "Add tasks" chip, gear, and a sound toggle.
   - Bottom row: pencil (edit/build), big red **CHECK-IN**, blue **FOCUS**, and the shop cart.
2. **Today / Quests**
   - Date header with prev/next arrows and the HUD.
   - Quests | Goals tabs. To-Dos | Done | Skipped filters.
   - Collapsible habit **groups**.
   - Habit card: streak count, streak bonus, title, **"Min:" minimum version**, an **identity statement** ("I'm an athlete", "I have an excellent memory"), banana multiplier, a **7-dot week strip**, and a character illustration. Floating + button.
3. **Today's Progress overlay** (on the world)
   - `0/4 habits · 1m focused · 2 acquired`.
   - **Daily challenge card** with a countdown ("4h 58m 10s"), a description, a reward, Change, and Mark Complete.
   - Inline task list with priority dots.
4. **Focus**
   - Dark scene, the Monke studying by a campfire, the line "Monke is locked in.", a big timer and STOP.
   - Live Activity / Dynamic Island. Pause and resume. Stopwatch mode. Breaks between sessions.
5. **Shop**: dark sheet with category chips (All, Trees, Small Decorations, Bo…). Item tiles show a price or "N variants".
6. **Build palette**: place many items, eraser, undo, move/flip/rotate. Terrain painting. "Re-design Island" refunds the land.
7. **Journal**: opened from the bonfire. A longer journal streak makes the bonfire brighter.
8. **Stats**: level, streak, average focus. Habit consistency over time, "weakest habits". Avatar picker.

## 4. Enforcement mechanics (observed) — the "forcing" Conor asked about

1. **App blocking during focus** (Screen Time API). Hardcore mode cannot be bypassed once started.
2. **Focus blocks**: apps are blocked during scheduled windows, and **bananas pay to unblock**.
3. **Lock apps until habits are completed** (1.4.8). This is the strongest forcing function.
4. **Daily app limits** with bananas buying extra time.
5. **Early-stop penalty** in hardcore focus.
6. **Notifications**: set times, streak-expiry warnings, and motivational alerts.
7. **Daily check-in** on first open with a motivational message.

## 5. Habit-science features (observed)

- **Minimum version** of each habit for bad days ("Min: 10 minutes of movement").
- **Identity statements** on each habit ("I'm an athlete"). A "Help me" button gives identity-based guidance.
- Habit templates with explanations. Onboarding questionnaire → suggested habits.
- Schedules: every N days, or N times per week.
- Goals of 7, 30 or 90 days linked to habits. These were removed in 1.4.9 because of bugs; the idea is good and the execution was fragile.

## 6. Architecture (observed from shipped web code + REA)

- Backend is **Supabase** (`…supabase.co/functions/v1/web-focus` edge function).
- Deep-link scheme is `monke://`, for example `monke://pair-web?id=…&token=…`. The web is paired to the phone by QR code, which expires after 10 minutes.
- Sync uses a **durable completed-session queue** in localStorage (`monke.web-focus.session.v1.<id>`).
  - Each item is removed only after the server accepts it.
  - Sessions completed before pairing are dropped, which is an anti-cheat measure.
- Sessions carry `id, completed_at, note, tag_id`. Tags are managed on the phone.
- Pomodoro defaults are 25 min work, 5 min short break, 15 min long break.
- The focus heatmap has 5 levels, from 25 min (light) to 4 h (darkest).
- Web sessions are rewarded only when the phone app opens ("Open Monke to collect your rewards"). Rewards are computed on the device or server, never in the browser.
- **Inferred**: a single-developer app. SpriteKit/SwiftUI isometric renderer on iOS and a separate Android build. Hand-drawn art is the main brand asset.

## 7. What users say (86 reviews)

- **Love**: gamification makes them "itch to complete tasks for bananas". The world is fun to build. Honest, simple "monke" voice. The widget. A lifetime purchase option.
- **Hate**: a hard paywall after the onboarding survey (the largest group of 1-star reviews). "Left with nothing after the questionnaire". Few prompts or ideas for habits.
- **Ask for**: more music, motivational lines when tapping characters, journaling (since added), widgets, flexible scheduling.

## 8. Translation to Conor Mastery

| Monke | Keep / change for Conor Mastery |
|---|---|
| Bananas | **Keep one currency.** Weight it by habit difficulty. Spend it on the world and on unblocking apps. |
| XP 1/focus-min | **Broaden.** XP from every habit (as ConorHealth's 10 XP/check), focus minutes, and sleep consistency. |
| Perfect-day streak + potions | **Keep, with honest rules.** One grace day per week, earned and not bought. Strict mode optional. |
| Minimum version + identity | **Keep.** Every habit carries an identity line and a "min" version, sourced from the coach KB with citations. |
| Lock apps until habits done | **Core enforcement.** Morning-routine gate on social apps until morning habits are done. "No social media" is a scheduled block. |
| Hardcore focus 1.5x + penalty | **Keep** as "Locked In" mode. |
| Daily challenge | **Coach-generated** from the KB and from the weakest habit, not random. |
| Island world | **Own theme, own art.** No Monke assets copied. The world grows with real history. |
| Leagues / Discord | **Drop for v1.** Single user. Compete against your own last 4 weeks. |
| Journal at bonfire | **Keep** as the nightly reflection, which feeds the coach. |
| Paywall after survey | **Drop.** Personal app. |
| "Left with nothing" | **Fix with the coach KB.** Onboarding produces a full plan with reasons. |
| Supabase sync | **Not needed for v1.** SwiftData on device plus the existing CoachSync iCloud folder (same as ConorHealth and Sunday). |

## Open questions / unknowns

- Exact banana amounts per habit multiplier, potion price and league point formula are not public. APK inspection would answer them; it was skipped (see scope note).
- Whether streak grace is "1 miss per week" or "1 miss in a row" (1.3.0 wording is ambiguous).
