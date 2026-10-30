# Response to Game Architecture Refactor Plan

**Date:** 2026-05-09  
**Context:** Review of `docs/game-architecture-refactor-plan.md` after pushback from the author.

---

## Author's Pushback

> *"I have built 4 games and want to move on to more, but want to accelerate as I do. I eventually do want to have 40 games, why wait until then to start realizing gains I have learned from the first 4?"*

This is valid. The critique in the original report — *"you are designing a plugin API for hypothetical future games"* — was overstated. Four games is not zero games. Four games with ~60% mechanical duplication is real pain, not imagined pain. The question is not whether to extract, but **how much to extract, and at what depth.**

The revised position is: **extract only what is provably identical across all four games today.** Do not build structural plugins (`QuestionLoop`, `SubmissionLoop`) that impose deep abstractions. Build **shallow, composable helpers** that remove duplication without constraining future games.

---

## What Still Holds From the Original Review

1. **The interface already exists.** `GameEventRouter` defines a shallow, stable contract: `game_started`, `start_from_instructions`, `handle_timeout`. The game modules are the deep implementations. This is good. Don't replace it with deeper abstractions.

2. **The service layer is not the main bottleneck.** Views, controllers, and pack models account for most of the new-game file count. Extracting `Games::Base` shrinks 90 files to ~85 files, not 5. Be honest about ROI.

3. **The plugin architecture (`QuestionLoop`, `SubmissionLoop`) is still premature.** Two games per plugin is not enough to justify a framework. Wait for three concrete examples that genuinely share the same shape, then extract from the concrete code.

4. **The 37signals perspective still applies.** "Extraction over abstraction" means: copy from your closest existing game, feel the pain, then extract the duplication. Don't design the extraction up front.

---

## What Changed

### Acknowledgment: 4 games is enough to start extracting

The safe extractions identified below are **derived from all 4 existing games.** They are not speculative. They remove duplication that is *already proven* to be identical.

### The path forward is smaller extractions, not a plugin framework

Instead of:
- `Games::Base` (300-line universal plumbing)
- `Games::Plugins::QuestionLoop` (deep abstraction)
- `Games::Plugins::SubmissionLoop` (deep abstraction)

Do:
- `Games::Broadcastable` (30 lines, identical in 3 of 4 games, harmless to the 4th)
- `Games::Startable` (10 lines, identical in all 4 games)
- Keep `Games::Finishable` as-is (it already exists)

These are **shallow concerns** — opt-in helpers, not architectural slots. A new game can ignore them entirely if it doesn't fit.

### Security debt has remote branches in flight

**Correction:** The author correctly pointed out that security fixes exist on remote branches:
- `origin/security/fix-response-idor` — 11 commits, rewrites `VotesController`, deletes `PollAnswersController`, `CategoryList::SubmissionsController`, `GameFinishesController`
- `origin/security/fix-vote-idor` — 1 commit, also rewrites `VotesController`

These branches appear to be doing more radical restructuring than just scoped lookups. They are **not merged** and will need to land separately. The safe abstractions in this PR touch only the service layer and should not conflict with controller restructuring.

---

## Recommended Sequencing (Revised)

### This PR: Safe extractions only
- Create `Games::Broadcastable` — identical in 3 of 4 games, harmless to the 4th (Poll)
- Create `Games::Startable` — identical in **only 2 of 4 games** (SpeedTrivia and Poll). WriteAndVote assigns prompts inside the lock; CategoryList starts the timer inside the lock.
- Apply to all 4 existing games where safe
- Remove local duplicated methods
- Run full test suite
- **Goal:** ~50 lines of framework, ~80 lines removed from services. No behavior change.

**Discovery during implementation:** `start_from_instructions` is *not* identical across all 4 games as the original plan claimed. Only SpeedTrivia and Poll share the exact same shape. WriteAndVote and CategoryList have extra logic inside the lock. This validates the shallow-extraction approach: if we had forced all 4 into a `Games::Base` template, we would have introduced hooks and conditionals for the outliers.

### Next 1–2 sessions: Security sweep
- Apply scoped lookups to all remaining controllers
- Add regression request specs using `host_only_actions.rb` pattern adapted for player actions
- **Goal:** Close the security debt while the test harness is warm.

### After game 5 or 6: Extract from concrete pain
- Build game 5 by copying the closest existing game
- If the same 40 lines are duplicated again, extract a third concern
- **Never** extract `QuestionLoop` or `SubmissionLoop` until you have 3+ games that genuinely fit the same shape

---

## The 40-Game Vision

The author's eventual goal of 40 games is legitimate. The question is: what architecture best serves a solo dev with 1–2 hours/week?

A plugin framework built at game 4 must be maintained through games 5–40. If it is wrong, the cost compounds. A generator (`rails generate game --from=speed_trivia`) plus shallow concerns produces the same speed of assembly without the maintenance liability.

When you have 10+ games and clear patterns emerge, **then** invest in deeper extraction. By then you will have 10 concrete data points, not 4.

---

## Conclusion

The original plan identified real duplication and real pain. The error was in the depth of the proposed abstractions. Extract shallow, composable helpers now. Build the next few games concretely. Let the deep abstractions emerge from repeated patterns, not from architectural imagination.
