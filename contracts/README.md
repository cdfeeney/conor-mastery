# Conor Mastery CoachSync contract (v1)

Same transport and rules as the frozen coach-kb contract
(`D:/projects/coach-kb/integrations/schemas/README.md`), which this does not modify:
iCloud Drive `CoachSync/`, atomic `.tmp` + rename, readers ignore unknown fields, the coach never edits
`from-apps/`, apps never edit `to-apps/`, and unknown is not zero.

```
CoachSync/
  to-apps/conormastery/plan.json          coach -> Mastery   mastery-plan.v1   (whole file, rewritten)
  from-apps/conormastery/daily-log.json   Mastery -> coach   mastery-daily-log.v1 (whole file, last 31 days)
  from-apps/conorhealth/session-logs/*    read by Mastery (coach-kb session-log.v1) -> Workout habit
```

## mastery-plan.v1 (`format: conor-mastery-plan`)

| field | type | notes |
|---|---|---|
| `generated_at` | ISO 8601 | |
| `weekly_focus` | string? | shown at the top of Coach |
| `notes` | string[] | optional |
| `habits[]` | object | fields below |
| `.id` | string | stable; the app keys history on it |
| `.title` / `.identity` / `.why` / `.full` / `.min?` | string | `min` = the bad-day version |
| `.kind` | `build|avoid|checklist|timer|focus|sleep` | |
| `.difficulty` | `easy|medium|hard` | grit 5/10/15 |
| `.group` | `morning|day|night` | |
| `.schedule` | `daily` · `weekdays:2,3,4,5,6` (1 = Sunday) · `every:N` · `per-week:N` | unknown means daily |
| `.steps?` | string[] | required for checklist |
| `.target_minutes?` / `.min_minutes?` | int | required for timer/focus |
| `.citations[]` | `{source, locator}` | `yt:<id>` + `mm:ss`, or `book:<slug>` + `p. N` |
| `.challenges[]` | string[] | daily-challenge texts, rotated by day |

Producer: `coach/tools/export_plan.py`, which validates and refuses citations whose source note is missing.
Consumer: `MasteryCore/CoachContract.swift` (`MasteryPlan.validated()`).

## mastery-daily-log.v1 (`format: conor-mastery-daily-log`)

`days[]` holds `date`, `habits[] {id, status: full|minimum|notDone|slipped, source, minutes?}`,
`sleep? {bedtime "HH:mm", wake, hours_in_bed, hours_slept?, quality?, on_target}`, `focus_minutes`,
`outcome? perfect|saved|missed|rest|pending` and `reflection?`.
Days with nothing logged are omitted, never written as zeros.

Producer: `MasteryCore/CoachContract.swift` (`DailyLogBuilder`). Fixture: `MasteryCoreTests/ContractAndChallengeTests`.
