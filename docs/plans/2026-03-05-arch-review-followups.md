# Architectural Review Follow-ups

**Date:** 2026-03-05
**Context:** Comprehensive architectural review of all game types, services, controllers, views, and broadcasting patterns. Tier 1 and Tier 2 items have been implemented in `refactor/arch-review`.

## Completed (Tier 1 + Tier 2)

- [x] Replace inline `authorize_host` in SpeedTrivia RoundClosuresController & AdvancementsController with `GameHostAuthorization` concern
- [x] Move CategoryList.submit_answers broadcasts outside `with_lock`
- [x] Delete dead ScoreRevealsController and route (calls nonexistent `show_scores`)
- [x] Add `broadcast_host_controls` to WriteAndVote.transition_to_voting
- [x] Add `broadcast_all` to WriteAndVote for centralized broadcasting
- [x] Move broadcasts from CategoryAnswersController into service (`moderate_answer`)
- [x] Make `normalize_answer` public (stop calling via `.send`)

## Deferred: Extensibility (Tier 3)

### 3a. Document the Game Module Contract

Define the required interface for any game service module. Currently each game type invents its own conventions. A documented contract would prevent drift.

**Required class methods:**
```
.requires_capacity_check? → boolean
.game_started(room:, timer_enabled:, timer_increment:, show_instructions:, **game_specific)
.start_from_instructions(game:)
.handle_timeout(game:)
```

**Required conventions:**
- All state transitions go through service methods, never controllers directly
- All broadcasts use a private `broadcast_all(game)` as the single exit point
- Player submissions go through a service method (not directly in controller)
- Controllers include `GameHostAuthorization` (host actions) or are player actions
- Service methods that modify state use `game.with_lock { }`
- Scoring logic lives in service, not scattered across model + service

**Inconsistencies to resolve:**
- `submit_answer` (singular) vs `submit_answers` (plural)
- `next_question` vs `advance_game_state!` vs `next_round`
- `round` means different things: question index (SpeedTrivia) vs actual round (others)
- Timer defaults: SpeedTrivia uses `nil`, others use `GameTemplate::SETTING_DEFAULTS`

### 3b. Game Type Generator / Checklist

See separate section below.

### 3c. Add Model-Level Validations

All three game models have minimal/zero validations. Services catch some edge cases but models should be the last line of defense:

- **SpeedTriviaGame**: Validate question count > 0 before start
- **WriteAndVoteGame**: Validate round bounds (round <= MAX_ROUNDS)
- **CategoryListGame**: Validate round bounds, answer presence/format
- **All games**: AASM transition guards for prerequisites

### 3d. Standardize `game_started` Parameter Handling

Currently `RoomsController.start_game` constructs all possible params and passes them via Wisper `publish`. Each game silently ignores irrelevant params via `**_extra`. A typo in a param name silently falls into `**_extra` and uses the default.

**Options:**
1. Pass a structured config object instead of flat kwargs
2. Add explicit param validation in each game's `game_started`
3. Keep current approach but add logging when `**_extra` is non-empty

## Deferred: Resilience (Tier 4)

### 4a. Reconnect-Aware Stimulus Controller for Hand View

**Status:** User is already implementing this.

When a player's WebSocket disconnects during a broadcast, the message is permanently lost. On reconnect, Turbo re-subscribes but does NOT re-fetch current state. Add a Stimulus controller that detects reconnection and does `Turbo.visit(window.location, { action: 'replace' })`.

### 4b. Profile Broadcast Fan-Out for Large Rooms

`broadcast_hand` iterates `room.players.each` and sends individual WebSocket messages. With 30+ players, that's 30 partial renders + 30 Action Cable pushes per state change, happening synchronously in the request cycle.

**Options:**
1. Move broadcasts to a background job (decouple from HTTP response)
2. Use room-scoped stream for hand content (requires player-aware partial rendering)
3. Add `includes()` to the players query to prevent N+1 in partial rendering

### 4c. Add `with_lock` to SpeedTrivia State Transitions

SpeedTrivia relies on unique constraints for answer deduplication but has no locking around `close_round` or `next_question`. Double-clicking "Close Round" could run `score_current_round` and `calculate_scores!` twice.

### 4d. ResponsesController Should Use Service Layer

`ResponsesController` directly updates the `Response` model, calls `GameBroadcaster` methods, and conditionally calls `check_all_responses_submitted`. Should be extracted to `Games::WriteAndVote.submit_response` for consistency.

**Blocked by:** RendersHand concern (on `fix/start-game-validate-before-transition` branch, not yet on main). Once merged, this controller should also include `RendersHand`.

---

## Game Type Generator Concept

### Problem

Adding a new game type requires creating 10+ files across 6+ directories, registering in 2 initializers, and following undocumented conventions. Missing any piece causes silent failures or inconsistent behavior.

### What It Would Generate

```
rails generate game_type word_scramble
```

Creates:
1. **Model** — `app/models/word_scramble_game.rb` with AASM skeleton, `HasRoundTimer`, `process_timeout`
2. **Service** — `app/services/games/word_scramble.rb` with contract methods:
   - `requires_capacity_check?`, `game_started`, `start_from_instructions`
   - `handle_timeout`, private `broadcast_all`, `start_timer_if_enabled`
   - `Playtest` module with `start`, `advance`, `bot_act`, `auto_play_step`, `progress_label`, `dashboard_actions`
3. **Migration** — Creates game table with standard columns (timer_enabled, timer_duration, round_ends_at, show_instructions, etc.)
4. **Controllers** — `app/controllers/word_scramble/game_starts_controller.rb` with `GameHostAuthorization`
5. **Views** — Stage partials (`_stage_instructions.html.erb`, `_stage_[initial_state]`, `_stage_finished`) and hand partials (`_hand.html.erb` router, `_game_over.html.erb`)
6. **Routes** — Adds route block for `word_scramble_games`
7. **Registry** — Adds to `config/initializers/game_registry.rb`
8. **Room constant** — Adds to `Room::GAME_TYPES` and `Room::GAME_DISPLAY_NAMES`
9. **Specs** — Skeleton specs for service, model, and system test

### Why a Generator vs. Documentation

- Documentation drifts; generators produce working code
- Generators encode the contract — if the contract changes, update the generator
- New developers get a working skeleton in seconds instead of reading docs and copying patterns
- The generator itself serves as documentation of the architecture

### Implementation Approach

Use Rails custom generator (`lib/generators/game_type/`). The templates would be ERB files that interpolate the game type name. Estimated effort: 1-2 sessions to build, with ongoing maintenance as patterns evolve.

### Alternative: Checklist Document

If a generator feels premature, a checklist in CLAUDE.md or docs/ would capture the same knowledge with less maintenance burden:

```markdown
## New Game Type Checklist
- [ ] Model with AASM states (must include instructions → [playing states] → finished)
- [ ] Model includes HasRoundTimer, implements process_timeout(round_number, step_number)
- [ ] Service module in app/services/games/ with required methods
- [ ] Service uses private broadcast_all(game) for all broadcasts
- [ ] Service uses game.with_lock for state-modifying operations
- [ ] Playtest module with all 6 required methods
- [ ] GameStartsController with GameHostAuthorization
- [ ] Stage partials for every AASM state
- [ ] Hand partials with _hand.html.erb router
- [ ] Registered in config/initializers/game_registry.rb (both GameEventRouter and DevPlaytest)
- [ ] Added to Room::GAME_TYPES and Room::GAME_DISPLAY_NAMES
- [ ] Routes added under resources :[game_type]_games
```
