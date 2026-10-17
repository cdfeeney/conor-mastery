# Conor Mastery — what's built, what's missing (updated 2026-10-17)

## Built and verified

| Piece | Proof |
|---|---|
| Game logic: grit, XP, levels and belts, Perfect Day streak, Second Winds, sleep stats, gate policy, garden, coach contract | 54 tests pass on Windows |
| Coach knowledge base: 15 YouTube notes, 5 public-domain books, 10 peer-reviewed studies, 9 habit protocols | `check_kb.py`: 312 note citations + 57 habit citations, 0 bad |
| Monke and Habitica teardowns | `research/` |

## Built but never run

The SwiftUI screens, Screen Time blocking, the monitor extension, CoachSync and SwiftData storage are written
but have never been compiled. The first Mac build is owner-approved and pending.

## Programming gaps (ranked)

| # | Gap | Why it matters | Size |
|---|---|---|---|
| P1 | ~~Art is emoji~~ **Done 10-17**: pixel sprites, top-down garden, footprints, land edge, habit plants (compiled in run 39057329048; plants and edge since then are uncompiled) | | |
| P2 | ~~No notifications~~ **Done (uncompiled)**: ReminderPlanner (tested) + NotificationService: habit cues, wind-down warning, streak at risk | Monke's #2 enforcement tool. Without them there's no morning nudge, no wind-down warning and no "streak at risk". | S |
| P3 | ~~Rewards are flat~~ **Done (v0.2)**: strength, Focused Strike, drops | | |
| P4 | **Partly done**: energy drains and habit plants wilt; nothing in the garden is lost | | |
| P5 | ~~No when/where~~ **Done (uncompiled)**: HabitPlan + plan sheet on every card; drives the cue reminder | The KB's strongest finding: a written time and place roughly doubles follow-through (Clear, mNeXuCYiE0U @ 06:44). | S |
| P6 | **No habit editor** | Habits come only from the coach plan, so you can't add your own or change times on the phone. | M |
| P7 | **Partly done**: the first-launch "Your day" sheet shows the whole plan; no survey yet | | |
| P8 | **Coach doesn't adapt** | The app writes daily-log.json, but nothing on the PC reads it to change the plan or challenges. | M (Python) |
| P9 | ~~No custom rewards~~ **Done (v0.2)**: treats | | |
| P10 | ~~No rest mode~~ **Done (v0.2)**: 3 rest days a month | | |
| P11 | **No widgets / Live Activity / lock-screen timer** | Monke has them, and they keep the habit visible. | M |
| P12 | ~~No sound or haptics~~ **Done 10-17**: coin, power-up and level-up sounds (CC0 pack) + success haptic, with a Settings toggle | | |
| P13 | **Sunday not linked** | Only ConorHealth workouts flow in. A protein-target habit could come from Sunday's intake. | S |

| P14 | ~~Coach doesn't teach~~ **Done 10-17**: daily lesson, tonight's check, pinned rules, tip library (107 tips) | | |

## Knowledge-base gaps (ranked)

| # | Gap | Fix |
|---|---|---|
| K1 | **No modern habit-science books**: Atomic Habits, Tiny Habits, Dopamine Nation, Why We Sleep, Deep Work, Allen Carr's Easy Way to Stop Smoking | They're copyrighted, so they need owned copies (Kindle/PDF). Drop them in `coach/inbox-pdfs/`; OCR them, then write page-cited notes. |
| K2 | ~~No research layer~~ **Done 2026-10-16**: `coach/kb/research/RESEARCH.md` has 10 verified studies (habit formation, implementation intentions, sleep regularity, cyclic sighing, social-media limits, abrupt quitting, loss-framed incentives, overjustification, gamification MA, light exposure). | Next: clinical cessation guidance (CDC/USPSTF) for K4. |
| K3 | **6 videos still blocked** (monke channel itself: all 64 done 10-17; 6 shorts have no speech, maybe on-screen text) by YouTube rate limits (Huberman light, Lembke social media, Huberman focus, vaping withdrawal, two monke videos) | Re-run `fetch_youtube.py` later. |
| K4 | ~~Nicotine is thin~~ **Done**: USPSTF grade-A guidance, the Cochrane combination-NRT review and a withdrawal timeline were added to research and to the habit. | Medication stays with a doctor. |
| K5 | ~~No evidence grade~~ **Done (per source)**: every source note now carries an `evidence:` grade (research / expert-opinion / anecdote / historical-opinion). | Per-claim grading is optional later. |
| K6 | **Gamification itself has no KB** | Add sources on self-determination theory, variable rewards, loss aversion and the overjustification effect (when points crowd out the real reason). |
