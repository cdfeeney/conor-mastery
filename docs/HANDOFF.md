# Conor Mastery — handoff (2026-10-16)

## State

| Area | Status | Evidence |
|---|---|---|
| Monke reverse-engineering | done | `research/MONKE-TEARDOWN.md`. REA run on the shipped web app (`ev_2f36d483…`). 7 screenshots, 26 release notes, 86 reviews |
| PRD v0.1 | done | `docs/PRD.md` |
| MasteryCore (logic) | **54/54 tests pass on Windows** (Swift 6.4.1 at `D:/tools/swift`) | `source scripts/swift-env.sh && cd MasteryCore && swift test` |
| Coach KB | 15 YouTube notes + 5 public-domain book notes (Gutenberg-scraped, `fetch_books.py`); 312 note citations + 51 habit citations verified; seed plan exported | `python coach/tools/check_kb.py`, `export_plan.py` |
| SwiftUI app + monitor extension | **Compiles and passes on the macOS runner (2026-10-16, run 38985953616)**: MasteryCore 75/75, app + MasteryMonitor extension + tests build, StoreTests 6/6 on the iPhone 16 simulator. Fixes needed on the way: Sendable statics, a missing import, notification APIs, and a test that freed its ModelContainer. Repo cdfeeney/conor-mastery is PRIVATE; it was public only for the run (~28 min). | `.github/workflows/ios.yml`, `project.yml` |
| TestFlight | not started; needs owner items A1–A3 | PRD section 9 |

## Gaps (honest)

- **Compiled, not yet used on a device**: the simulator build and store tests pass. Screen Time blocking needs a real iPhone plus Apple's Family Controls entitlement (A1). There are no UI tests yet.
- **Transcripts**: 6 videos still failed with HTTP 429 (STAffeSFBVk, dXC38rZMrTU, D34KyceGhPE, 652y-f1YFjU, 8e3RC1L5V_Y, xcPX3VkQjAY). Every habit already has citations. Re-run `fetch_youtube.py` later to deepen the notes.
- **Re-enabling an archived habit** counts it from today only (one date range per habit), which slightly inflates the history before it was archived. This is an accepted limitation.
- **Art**: world items are emoji placeholders. Original illustrations are a v0.2 item. No Monke assets are used.
- **Family Controls**: works in development builds only until Apple grants the distribution entitlement (A1).
- **No widgets / Live Activity** yet (v0.2).

## Rules for the next session

- The coach-kb repo is read-only. Mastery's contract lives in `contracts/` and writes only to `to-apps/conormastery/`.
- Raw transcripts and Monke's screenshots/code stay local (git-ignored). Commit only notes we wrote ourselves, with citations.
- Don't dispatch the `ios` workflow without the owner's go (macOS minutes; see memory `macos-runner-burns-actions-minutes`).
