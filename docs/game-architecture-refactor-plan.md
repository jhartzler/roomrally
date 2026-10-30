# Game Architecture Refactor Plan

**Status:** In progress — test coverage complete, extraction work ready to start  
**See also:** [Response & Revised Recommendations](game-architecture-refactor-plan-response.md) — pushback addressed, extraction depth revised  
**Last updated:** 2026-05-09  
**Context:** This plan was produced after a code-review-driven session that fixed P0 security bugs and established a request-spec pattern for host-action controllers. The refactor direction emerged from analyzing 4 existing game types (SpeedTrivia, Poll, WriteAndVote, CategoryList) and identifying ~60% mechanical duplication.

---

## Problem

Adding a new game mode today costs **10–21 commits, 50–90 files, and 3,000–6,000+ lines of changes** (see Scavenger Hunt branch: 21 commits, 93 files). ~60% of that work is mechanical duplication of patterns already proven in existing games.

As a solo dev with 1–2 hours/week of agent time, this is not sustainable. The goal is to make new games **assembly** (plug a ruleset into proven machinery) rather than **sculpture** (carving from raw stone).

---

## Guiding Principle: Users Never See the Abstraction

Users pick distinct game tiles: "Think Fast," "Bandwagon," "Comedy Clash," "A-List."
They never configure archetypes, never see "advanced mode," never choose a "game engine."

The abstraction lives **entirely in the service layer and below**. The user-facing layer stays unchanged.

---

## Target Architecture (3 Tiers)

### Tier 1: `Games::Base` — Universal Plumbing

Extracted module that all game services inherit. Handles the ~30 lines that are literally copy-pasted in all 4 existing services:

- `game_started(room:, ...)` — create game, assign pack, link to room, emit analytics
- `start_from_instructions(game:)` — lock + transition + broadcast (already identical everywhere)
- `finish_game!(game:)` — already in `Games::Finishable`, but harmonize
- `broadcast_all(game)` — standard implementation (identical in 3 of 4 games today)
- Analytics + `GameEvent` emission helpers

**Impact per new game:** Service drops from ~300 lines to ~100 lines.

### Tier 2: Structural Plugins (Rails concerns, opt-in)

Common game *patterns* extracted as mixins. New games compose these, not inherit monolithic templates.

| Plugin | What it handles | Used by |
|--------|--------------|---------|
| `Games::Plugins::QuestionLoop` | Discrete question/round flow: `start_question` → `close_round` → `next_question` | SpeedTrivia, Poll, future trivia variants |
| `Games::Plugins::SubmissionLoop` | Player-created content: assign prompts/categories, collect submissions, moderation | WriteAndVote, CategoryList, ScavengerHunt |
| `Games::Plugins::TimerPhase` | Timed phases, auto-timeout, `GameTimerJob` integration | Any timed game |
| `Games::Plugins::ScoringPhase` | Points, podium, leaderboard rendering | Any scoreable game |

**Impact:** "Bride & Groom Trivia" becomes a `QuestionLoop` + custom `score_reveal_for` + a content pack. ~2 hours instead of 21 commits.

### Tier 3: User-Facing Presets

Never changes. Each tile maps to:
- An archetype (which plugins)
- A content pack type (trivia, poll, prompt, category)
- Default settings (timer, round count, scoring mode)
- Custom view partials only for *unique* states

---

## Completed Work

### ✅ P0 Security Fixes (PR #267, merged to main)

| Fix | Where |
|-----|-------|
| Scoped `Response.find` to `Player.session_id` | `ResponsesController` |
| Scoped `CategoryAnswer.find` through room code | `CategoryAnswersController` |
| `with_lock` around `start_from_instructions` in all 4 services | `SpeedTrivia`, `Poll`, `WriteAndVote`, `CategoryList` |
| `with_lock` around `CategoryList.handle_timeout` and `show_scores` | `CategoryList` |
| Regression request specs for both IDOR vectors | `spec/requests/responses_spec.rb`, `spec/requests/category_answers_spec.rb` |

### ✅ Host-Action Request Specs (PR #268, open)

| Game Family | Controllers | Examples |
|-------------|-------------|----------|
| SpeedTrivia | game_starts, questions, round_closures, advancements, question_skips | 21 |
| Poll | game_starts, questions, round_closures, advancements, host_answers | 21 |
| CategoryList | game_starts, reviews, review_navigations, rounds, stage_scores | 21 |
| WriteAndVote | game_starts | 7 |

**Shared example:** `spec/support/shared_examples/host_only_actions.rb`
- Tests host, non-host, and unauthenticated callers
- Asserts game-state immutability for unauthorized requests
- Parameterized for HTTP method and request params
- No HTML-markup coupling (decoupled from Turbo Stream internals)

**Total: 92 request-spec examples, ~3 seconds.**

---

## Remaining Security Debt (Same Bug Class, Separate PR)

Found during code review of PR #267/#268. These are the same unscoped-lookup pattern already fixed in ResponsesController and CategoryAnswersController.

| Controller | Bug | Scope Fix |
|-----------|-----|-----------|
| `VotesController` | `Response.find(params[:vote][:response_id])` unscoped | Join through player's room/game |
| `PollAnswersController` | `PollGame.find(params[:poll_game_id])` unscoped in player action | Validate against `current_player.room.current_game` |
| `CategoryList::SubmissionsController` | `CategoryListGame.find` unscoped in player action | Validate against `current_player.room.current_game` |
| All host controllers (16 total) | `SomeGame.find(params[:id])` unscoped in `set_game` | Scope through `Room.where(code: params[:code])` or validate against `room.current_game` |
| `GameFinishesController` | `params[:game_type].constantize.find(params[:game_id])` unscoped | Scope through `params[:code]` → room → current_game |
| `RejectionsController` | `Response.find(params[:response_id])` unscoped | Scope through facilitator's rooms |

**Recommended approach:** One focused security sweep PR that applies the same `joins + where` pattern everywhere. Use the request spec pattern from PR #268 to add regression coverage for each controller as you go.

---

## Refactor Sequencing (Proposed)

**Constraint:** Do not refactor without tests. The service → controller boundary is the seam that breaks when interfaces change. The request specs in PR #268 are the safety net.

### Phase 1: Extract `Games::Base` (1 session)

Extract the ~30 lines of universal plumbing from the 4 existing services into a `Games::Base` module. Each service `include`s it and overrides only what is different.

**Files touched:** `app/services/games/base.rb` + 4 existing service files.
**Risk:** Low — no behavior change, just deduplication.
**Tests:** Existing service specs (119 examples, ~5s) prove no regressions.

### Phase 2: Extract `Games::Plugins::QuestionLoop` (1–2 sessions)

SpeedTrivia and Poll share a nearly identical question/round flow:
- `start_question` → `answering`
- `close_round` → `reviewing`
- `next_question` → `answering` (or `finished`)

Extract the common structure. Differences (timed scoring vs. majority rules) stay in the individual service.

**Impact:** New question-based games (trivia variants, custom trivia) become ~100-line services.

### Phase 3: Extract `Games::Plugins::SubmissionLoop` (1–2 sessions)

WriteAndVote and CategoryList both:
- Assign content to players (prompts / categories)
- Collect player-created submissions (responses / answers)
- Support moderation (reject / approve / hide)
- Score based on host judgment or automated rules

Extract the common submission/moderation/scoring flow.

**Impact:** New content-creation games (ScavengerHunt-style, future drawing games) become assembly.

### Phase 4: Build a New Game as Proof (1 session)

Use the extracted plugins to build a trivial new game — e.g., "Classic Trivia" (no timer decay, just right/wrong) or "Bride & Groom Trivia" (team-based reveal). This validates that the plugin boundaries are clean and the `/new-game` skill scaffolding works.

**Goal:** If this takes more than 2 hours, the plugins need more work.

---

## How to Add a New Game Type (Post-Refactor)

With `Games::Base` + plugins in place, the checklist shrinks:

1. **Pick an archetype:** `QuestionLoop`, `SubmissionLoop`, or compose both
2. **Create model:** AASM states + `HasRoundTimer` + `process_timeout`
3. **Create service:** `include Games::Base`, `include Games::Plugins::QuestionLoop`, implement custom scoring/behavior (~100 lines)
4. **Create playtest module:** Nested in service file, co-located
5. **Create view partials:** Only for *unique* states (instructions and finished use shared partials)
6. **Register:** Add to `GameEventRouter`, `DevPlaytest::Registry`, `Room::GAME_TYPES`
7. **Add one system spec:** Happy path with multiple Capybara sessions

**Expected scale:** ~5–8 files, 1 commit, 1–2 hours.

---

## Open Questions / Decisions Needed

1. **Should plugins be module `include` or class inheritance?**
   - Current leaning: `include` (Rails concerns) because each game may need multiple plugins and override specific methods. Class inheritance is too rigid.

2. **How much view sharing is too much?**
   - Stage views are where personality lives. Genericize only the boring parts (instructions, leaderboards, waiting states). Unique states (e.g., scavenger hunt's photo gallery) stay bespoke.

3. **Unified Content Pack?**
   - Future idea: `ContentPack` + `ContentItem` with JSONB `data` column, replacing `TriviaPack`/`PollPack`/`PromptPack`/`CategoryPack`. This would eliminate ~40% of new-game file count (no new pack CRUD). But this is a bigger refactor — do it only after plugins are proven.

---

## Related Backlog Items

- `RMRL-42` — ResponsesController IDOR ✅ fixed
- `RMRL-43` — Missing `with_lock` ✅ fixed
- `RMRL-44` — Missing server-side validations (still open)
- `RMRL-45` — N+1 queries in scoring (still open)
- `RMRL-46` — Missing DB-level unique constraints (still open)
- `RMRL-47` — Stimulus memory leaks (still open)
- `RMRL-48` — Duplicate leaderboard markup (would be addressed by `ScoringPhase` plugin)

---

## Files Referenced

- `spec/support/shared_examples/host_only_actions.rb` — Reusable request spec pattern
- `app/services/games/speed_trivia.rb` — Source for `QuestionLoop` extraction
- `app/services/games/poll.rb` — Source for `QuestionLoop` extraction
- `app/services/games/write_and_vote.rb` — Source for `SubmissionLoop` extraction
- `app/services/games/category_list.rb` — Source for `SubmissionLoop` extraction
- `CLAUDE.md` — Project conventions (with_lock, broadcast_all, GameHostAuthorization)
