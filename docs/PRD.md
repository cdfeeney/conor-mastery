# Conor Mastery — PRD v0.1

Owner: Conor. Date: 2026-10-16. Status: v0.1 build in progress.
Source research: `research/MONKE-TEARDOWN.md` (Monke reverse-engineering).

## 1. What it is

A personal iPhone habit app. It **tracks** the habits Conor is building, **rewards** them with a game
loop learned from Monke, and **enforces** them with iOS Screen Time blocks. A **coach knowledge base**,
built from YouTube transcripts and books, decides which habits matter and how to do them, and explains why.

It sits beside the two existing apps:

| App | Owns | Link to Mastery |
|---|---|---|
| ConorHealth (SwiftUI) | training, weight, recovery | Mastery's **Workout** habit auto-completes when ConorHealth writes a session log for that date (CoachSync `from-apps/conorhealth/session-logs/`). |
| Sunday (Expo) | food, nutrition targets | v0.2: optional "hit protein" habit read from `from-apps/sunday/intake.json`. |
| Coach (Claude + KB on PC) | plans | writes `to-apps/conormastery/plan.json`; reads `from-apps/conormastery/daily-log.json` (habits + sleep). |

Transport is the existing CoachSync iCloud folder and its rules: atomic `.tmp` + rename, readers
ignore unknown fields, and apps never edit `to-apps/`. Mastery has its own schemas in `contracts/schemas/`.
The frozen coach-kb contract is not modified.

## 2. Default habits (from Conor's brief)

| # | Habit | Kind | Full | Min (bad day) | Enforcement |
|---|---|---|---|---|---|
| 1 | Workout | build | ConorHealth session logged | 10 min movement | auto from ConorHealth |
| 2 | No social media | avoid | clean all day | — | social apps blocked on schedule |
| 3 | No nicotine | avoid | clean all day | — | days-clean counter; slip logged honestly |
| 4 | Morning routine | checklist | all steps | wake + water + light | **gate**: social apps locked until done |
| 5 | Meditation | timer | 10 min | 2 min | timer must run |
| 6 | Reset focus | focus | 25 min Locked-In session | 10 min | apps blocked during session |
| 7 | Night routine | checklist | all steps | phone away | starts wind-down block |
| 8 | Deep breathing | timer | 5 min box breathing | 1 min (3 sighs) | timer must run |
| 9 | Sleep | log | in bed ±30 min of target, ≥ 7.5 h asleep | log it | morning prompt |

Habits are editable. Each habit carries an **identity line**, a **why** and **KB citations** from the coach plan.

## 3. Sleep log (manual)

Each night stores bedtime, wake time and actual sleep hours. Actual hours default to the time in bed,
can be edited, and are kept separately because time in bed is not time asleep. An optional 1–5 quality rating is also stored.
Derived values:
- Duration.
- **Consistency**: standard deviation of bed/wake times over 7 days, in minutes.
- **Sleep debt**: target hours × 7 − actual over 7 days.
- Hit or miss against the target.

These are shown in the Sleep screen and exported to the coach.

## 4. Game loop (adapted from Monke)

- **Grit** is the single currency.
  - Habit reward = base by difficulty (easy 5 / medium 10 / hard 15) + streak bonus (+1 per 7-day block, max +5).
  - The minimum version pays 50%.
  - Focus pays 1 grit per 5 min, and Locked-In pays 1.5x. Stopping Locked-In early costs 10 grit.
  - Daily challenge pays +20. A to-do task pays 3.
- **XP and level**:
  - 10 XP per habit (ConorHealth parity), 1 XP per focus minute, +10 for an on-target sleep night.
  - Level L needs 50·L·(L+1) cumulative XP.
- **Belt rank** by level: White 1–4, Yellow 5–9, Orange 10–14, Green 15–19, Blue 20–29, Purple 30–39, Brown 40–49, Black 50+.
- **Perfect Day streak** = every scheduled required habit done (min counts).
  - A **Second Wind** token is earned per 7 perfect days, with at most 2 held.
  - A missed day spends one automatically. Strict mode turns tokens off.
  - Tokens are earned, never bought.
- **World: the Dojo Garden.**
  - An isometric plot grows from bare ground to a full dojo garden.
  - Items are bought with grit: stones, bonsai, lanterns, koi pond, bridge, torii, dojo, pagoda. Land expands from 3x3 to 9x9.
  - Original art only. No Monke assets.
- **Daily challenge**: the coach picks it from the weakest habit of the last 14 days, using KB text, never random filler.
- **Unblock with grit**: a blocked app can be opened early for 15 minutes for 25 grit. This costs real progress.

## 5. Enforcement (Screen Time: FamilyControls, ManagedSettings, DeviceActivity)

1. **Morning gate**: the chosen social/distraction apps are shielded from the wind-down time (default 21:30) until the morning routine habit is done.
2. **No-social schedule**: chosen apps are shielded during set windows. The default is all day, except a 30-minute window at 19:00.
3. **Locked-In focus**: all chosen apps are shielded during the session.
4. **Grit unblock**: 15 minutes for 25 grit, logged as a "slip" against No social media.

Requires the `com.apple.developer.family-controls` entitlement. Development builds work. A
**TestFlight/App Store build needs Apple's distribution approval request**, which is owner action item A1.

## 6. Coach knowledge base

`coach/` in this repo:
- `coach/sources.yaml` lists curated YouTube videos and books.
- `coach/tools/fetch_youtube.py` pulls auto-subtitles with yt-dlp into clean, timestamped transcripts (`coach/raw/youtube/`, git-ignored).
- Claude (the coach) writes **source notes** with timestamp citations (`coach/kb/sources/`), then **habit protocols** (`coach/kb/habits/<id>.md`): what, why, identity, full/min, pitfalls, citations.
- Books: only owned PDFs, through the coach-kb OCR tools. Notes are page-cited, with no bulk copying.
- `coach/tools/export_plan.py` compiles the protocols into `mastery-plan.v1`, validates them and writes atomically to CoachSync. A copy is bundled into the app as the seed plan.

## 7. Screens

1. **Dojo** (home)
   - The world, with a HUD showing `Belt·Lvl | 🔥streak | grit`.
   - Today's progress card: habits done/total, minutes focused, grit earned.
   - Daily challenge. Buttons for CHECK-IN, FOCUS, Build and Shop.
2. **Today**: habit cards in groups (Morning / Day / Night). Each card has its identity line, Min chip, 7-dot week strip, reward and swipe actions. Tasks sit below.
3. **Focus**: timer or stopwatch, Locked-In toggle, note and tag, break reminders.
4. **Sleep**: log sheet (bed, wake, hours, quality), a 14-night chart, consistency and debt.
5. **Coach**: today's challenge, protocol for each habit with citations, coach notes, and a nightly reflection (journal).
6. **Stats**: consistency per habit, weakest habits, level history.
7. **Settings**: habits editor, Screen Time setup, CoachSync folder, strict streak.

## 8. Non-goals for v0.1

Leagues, social, cloud accounts, paywall, Android, widgets/Live Activity (v0.2).

## 9. Owner action items

- **A1**: request the Family Controls distribution entitlement from Apple (developer account) before TestFlight.
- **A2**: register the bundle id `com.conorfee.conormastery` and the App Store Connect app record.
- **A3**: go-ahead for a native build run (macOS runner minutes / public window, same as ConorHealth).
- **A4**: review the YouTube/book source list in `coach/sources.yaml`.
