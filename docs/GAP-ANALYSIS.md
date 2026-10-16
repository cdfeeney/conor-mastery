# Conor Mastery — what's built, what's missing (2026-10-16)

## Built and verified

| Piece | Proof |
|---|---|
| Game logic: grit, XP, levels and belts, Perfect Day streak, Second Winds, sleep stats, gate policy, garden, coach contract | 54 tests pass on Windows |
| Coach knowledge base: 15 YouTube notes, 5 public-domain books, 9 habit protocols | `check_kb.py`: 312 note citations + 51 habit citations, 0 bad |
| Monke and Habitica teardowns | `research/` |

## Built but never run

The SwiftUI screens, Screen Time blocking, the monitor extension, CoachSync and SwiftData storage are written
but have never been compiled. The first Mac build is owner-approved and pending.

## Programming gaps (ranked)

| # | Gap | Why it matters | Size |
|---|---|---|---|
| P1 | **Art is emoji** | The owner rejected it. The world is the main reward, so it has to look earned. | L (see ART-DIRECTION.md) |
| P2 | **No notifications** | Monke's #2 enforcement tool. Without them there's no morning nudge, no wind-down warning and no "streak at risk". | S |
| P3 | **Rewards are flat** | No habit-strength drift, no crits, no drops (Habitica). Every tick pays the same, so it gets boring by week 3. | M (core logic) |
| P4 | **No real loss** | Only the streak can be lost. Nothing wilts, so missing costs little in the game. | M |
| P5 | **No when/where per habit** | The KB's strongest finding: a written time and place roughly doubles follow-through (Clear, mNeXuCYiE0U @ 06:44). | S |
| P6 | **No habit editor** | Habits come only from the coach plan, so you can't add your own or change times on the phone. | M |
| P7 | **No onboarding** | Monke's survey becomes a plan. Ours opens straight into 9 habits. | M |
| P8 | **Coach doesn't adapt** | The app writes daily-log.json, but nothing on the PC reads it to change the plan or challenges. | M (Python) |
| P9 | **No custom real-life rewards** | Habitica's strongest motivator for some users: you choose the treat and pay grit for it. | S |
| P10 | **No rest/vacation mode** | Being sick or travelling breaks the streak unfairly, and unfair loss leads to quitting. | S |
| P11 | **No widgets / Live Activity / lock-screen timer** | Monke has them, and they keep the habit visible. | M |
| P12 | **No sound or haptics** | Feedback "juice". Rewards feel weaker without it. | S |
| P13 | **Sunday not linked** | Only ConorHealth workouts flow in. A protein-target habit could come from Sunday's intake. | S |

## Knowledge-base gaps (ranked)

| # | Gap | Fix |
|---|---|---|
| K1 | **No modern habit-science books**: Atomic Habits, Tiny Habits, Dopamine Nation, Why We Sleep, Deep Work, Allen Carr's Easy Way to Stop Smoking | They're copyrighted, so they need owned copies (Kindle/PDF). Drop them in `coach/inbox-pdfs/`; OCR them, then write page-cited notes. |
| K2 | **No research layer**: no peer-reviewed sources. Most YouTube claims are the speaker's own word. | Add open-access studies: Lally 2010 (habit formation takes a median ~66 days), Gollwitzer & Sheeran 2006 (implementation intentions meta-analysis), sleep-regularity studies, clinical nicotine-cessation guidance (CDC/USPSTF). |
| K3 | **6 videos still blocked** by YouTube rate limits (Huberman light, Lembke social media, Huberman focus, vaping withdrawal, two monke videos) | Re-run `fetch_youtube.py` later. |
| K4 | **Nicotine is thin**: one Huberman clip, one book chapter | Add the clinical guidance (K2) plus a withdrawal timeline. Medication stays with a doctor. |
| K5 | **No evidence grade on claims** | Tag each claim as research / expert opinion / anecdote so the coach weights them. |
| K6 | **Gamification itself has no KB** | Add sources on self-determination theory, variable rewards, loss aversion and the overjustification effect (when points crowd out the real reason). |
