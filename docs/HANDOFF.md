# Conor Mastery — handoff (2026-10-16)

## State

| Area | Status | Evidence |
|---|---|---|
| Monke reverse-engineering | done | `research/MONKE-TEARDOWN.md`. REA run on the shipped web app (`ev_2f36d483…`). 7 screenshots, 26 release notes, 86 reviews |
| PRD v0.1 | done | `docs/PRD.md` |
| MasteryCore (logic) | **48/48 tests pass on Windows** (Swift 6.4.1 at `D:/tools/swift`) | `source scripts/swift-env.sh && cd MasteryCore && swift test` |
| Coach KB | 12 source notes (195 timestamps verified), 9 habit protocols (34 citations verified), seed plan exported | `python coach/tools/check_kb.py`, `export_plan.py` |
| SwiftUI app + monitor extension | written, **never compiled**. No Mac; CI workflow `ios` is manual-only | `.github/workflows/ios.yml`, `project.yml` |
| TestFlight | not started; needs owner items A1–A3 | PRD section 9 |

## Gaps (honest)

- **Not compiled**: the iOS app target has not been built. The first native run will likely surface a few compile errors. The core package is compiled and tested.
- **Transcripts**: YouTube returned HTTP 429 for some videos on 2026-10-16. `deep-breathing` has no citation yet. Re-run `python coach/tools/fetch_youtube.py` later, write the missing notes, and cite them.
- **Art**: world items are emoji placeholders. Original illustrations are a v0.2 item. No Monke assets are used.
- **Family Controls**: works in development builds only until Apple grants the distribution entitlement (A1).
- **No widgets / Live Activity** yet (v0.2).

## Rules for the next session

- The coach-kb repo is read-only. Mastery's contract lives in `contracts/` and writes only to `to-apps/conormastery/`.
- Raw transcripts and Monke's screenshots/code stay local (git-ignored). Commit only notes we wrote ourselves, with citations.
- Don't dispatch the `ios` workflow without the owner's go (macOS minutes; see memory `macos-runner-burns-actions-minutes`).
