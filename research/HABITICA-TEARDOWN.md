# Habitica: reverse-engineering teardown (from source)

Date: 2026-10-16. Habitica is open source (github.com/HabitRPG/habitica, shallow clone at
`D:/research/habitica`). Unlike Monke, its real game code can be read. The code is **GPL-3** and the art
is **CC-BY-SA 3.0**: we study formulas and mechanics, which are ideas and not copyrightable, and
write our own implementation. Nothing is copied into Conor Mastery.

Files read: `website/common/script/ops/scoreTask.js` (rewards and penalties),
`website/server/libs/cron.js` (the nightly reckoning), `common/script/fns/crit.js`, `fns/randomDrop.js`,
`fns/updateStats.js` and `statHelpers.js` (level curve).

## 1. The core idea: every task has a "value" that drifts (scoreTask.js)

Each habit carries a hidden number, `value`, clamped to [-47.27, 21.27]. Doing the task raises it and
missing it lowers it. The reward for doing it is

```
delta = 0.9747 ^ value
```

- A **neglected task (value very negative) pays far more**. At value -20, delta ≈ 1.67, and at -47 it is ≈ 3.4.
- A **strong, automatic habit pays less**. At +21 it is ≈ 0.58.
- The UI colours tasks by value, from red (neglected) to blue (strong). You can see which habits are weak.

The game automatically pushes you toward your weakest habits without a coach telling you to.
Monke has nothing like it. **This is the single best idea to take.**

## 2. What you gain (scoreTask.js `_addPoints`)

```
XP   += round(delta × difficulty × 6 × intBonus × crit)
Gold += delta × difficulty × perBonus × crit × streakBonus
streakBonus = 1 + streak/100   (1% per day of that habit's own streak, min +1 gold)
difficulty  = trivial 0.1 | easy 1 | medium 1.5 | hard 2
```

- **Critical hits** (crit.js): a base 3% chance, scaled by STR, multiplies the reward by 1.5 to about 5.5.
  This is a *variable reward*: you never know exactly what a tick will pay.
- **Per-habit streaks**: each daily habit keeps its own streak, separate from the global Perfect Day streak.

## 3. What you lose: health (cron.js + `_subtractPoints`)

Every night the server runs "cron" over the day that just ended:
- Each **due daily left undone deals damage**: `hp -= ceil(delta × conBonus × difficulty × 2)`, with a minimum of 1.
  A **partially done checklist reduces the damage** in proportion to the steps finished.
- Missing also pushes the task's value down. A neglected task then hurts *more* when missed and pays
  *more* when done.
- At **HP 0 you die**: you lose a level, your gold and one piece of gear. This is real loss aversion.
- **Rest in the Inn** (vacation) pauses all damage. **Stealth** (a rogue skill) lets one missed daily be dodged.
- **Perfect Day** (every due daily done) gives a buff to all stats of ceil(level/2) for the next day,
  plus an achievement.

## 4. Level curve (statHelpers.js `toNextLevel`)

```
lvl < 5  : 25 × lvl          (25, 50, 75, 100)
lvl == 5 : 150
lvl > 5  : round((lvl² × 0.25 + 10 × lvl + 139.75) / 10) × 10
```

Early levels come quickly to hook a new player, then they need steadily more XP. On level-up, HP refills to
full, which turns a level-up into a recovery moment.

## 5. Collection and drops (randomDrop.js)

- Completing a task can drop an egg, a hatching potion or food.
  `chance = min(|value − 21.27|, 37.5)/150 + 0.02`, × difficulty, with diminishing returns capped at 75%.
  Neglected tasks drop more often, which is the same value idea again.
- Egg + potion hatches a **pet**, and feeding a pet grows it into a **mount**. This is long-term collection.
- The daily drop count is capped, so it can't be farmed.

## 6. Social pressure

- **Parties and boss quests**: your completed tasks damage the boss, and **your missed dailies make the boss hit
  your whole party**. Letting yourself down costs your friends something.
- Guilds and challenges exist as well. This is out of scope for a single-user app.

## 7. Task types

**Habits** can be tapped + and/or − any number of times a day (e.g. "+ drank water", "− snacked").
**Dailies** are scheduled and missing one hurts. **To-dos** are one-offs, and an old to-do turns red and pays more.
**Rewards** are custom real-life treats you buy with your own gold ("1 episode of a show = 20 gold").

## 8. What Habitica gets wrong (inferred from design plus common user complaints)

- Death and damage can trigger an **abandonment spiral**: one bad week, low HP, shame, the user quits.
- The 8-bit RPG overlay is deep but cluttered. There is no world you build that *shows* your progress
  the way Monke's island does.
- There's no enforcement. Habitica can't block your apps, so the penalty is only in the game.

## 9. Translation table for Conor Mastery

| Habitica mechanic | Adopt? | Our version |
|---|---|---|
| Task value drift (0.9747^value) | **Yes, core** | Each habit has a "strength" score. Weak habits pay more grit and show red, strong ones show blue. |
| Crits (variable reward) | **Yes** | A small chance of a "Focused Strike" for 2x grit on any completion, seeded so it can't be re-rolled. |
| Per-habit streak bonus | **Yes** | +1% grit per day of that habit's own streak, capped. |
| HP / damage for missed habits | **Softened** | "Energy" drains on missed habits and refills on a Perfect Day or level-up. At zero you don't die: the garden wilts until you recover. |
| Death (lose level and gold) | **No** | Abandonment-spiral risk. We use the garden wilting plus "never miss twice". |
| Inn / rest mode | **Yes** | Rest days (sick, travel) pause damage and streaks, limited per month. |
| Perfect Day buff | **Yes** | The next day's grit is boosted 1.25x. |
| Drops → pets → mounts | **Yes, our theme** | Drops of seeds and koi eggs grow into garden plants and koi, a collection living in the dojo garden. |
| Custom real-life rewards | **Yes** | You define treats ("cheat meal = 150 grit") and buy them with grit. |
| Party boss damage | **Later** | An optional accountability partner sees your missed habits. |
| Level curve | **Compare** | Ours is 50·L·(L+1). Habitica's is gentler early; consider its fast first 5 levels. |
