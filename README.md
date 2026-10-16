# Conor Mastery

A personal iPhone habit app. It **tracks** habits (workout, no social media, no nicotine, morning
routine, meditation, reset focus, night routine, deep breathing, sleep) and **rewards** them with a
game loop reverse-engineered from Monke: grit currency, XP and belt ranks, Perfect Day streaks, and
a dojo garden you build. It **enforces** habits with Screen Time blocks, and it is **coached** by a
knowledge base built from YouTube transcripts and books.

It is a companion to ConorHealth (a logged workout ticks the Workout habit) and Sunday. All three
share the CoachSync iCloud folder.

| Path | What |
|---|---|
| `research/MONKE-TEARDOWN.md` | Monke reverse-engineering: evidence, mechanics, translation table |
| `docs/PRD.md` | product spec v0.1 + owner action items |
| `MasteryCore/` | pure-Swift game/habit logic (economy, streaks, sleep, gate, world, contract) + tests |
| `App/ConorMastery/` | SwiftUI + SwiftData app |
| `Extensions/MasteryMonitor/` | DeviceActivity monitor (enforces the schedule while the app is closed) |
| `Shared/` | shield code compiled into the app and the extension |
| `coach/` | KB pipeline: `sources.yaml` → transcripts → `kb/sources` notes → `kb/habits` protocols → plan |
| `contracts/` | CoachSync plan/log contract |

## Commands

```bash
# Core logic tests (Windows: toolchain on D:)
source scripts/swift-env.sh && (cd MasteryCore && swift test)

# Coach KB
python coach/tools/fetch_youtube.py            # transcripts -> coach/raw/youtube (git-ignored)
python coach/tools/export_plan.py              # kb/habits -> App/Resources/seed-plan.json
python coach/tools/export_plan.py --coachsync  # + publish to iCloud CoachSync

# iOS build: GitHub Actions `ios` workflow (manual dispatch, macOS runner), via XcodeGen project.yml
```
