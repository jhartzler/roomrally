# Bandwagon Game Design Spec

**Date:** 2026-04-04  
**Display name:** Bandwagon  
**Internal name:** `PollGame` / `Games::Poll`  
**Branch:** `fix/democracy` (worktree: `democracy`)

---

## Overview

Bandwagon is a polling game mode where players answer multiple-choice questions and score points based on how their answer relates to the crowd. The core tension: commit early for a bigger speed bonus, but you don't know which answer is "correct" until voting closes.

Similar to Speed Trivia in structure (packs, timed rounds, host-paced), but no answer is pre-marked correct — the crowd (or host) determines who wins each round.

Free-response questions (answers grouped by majority) are explicitly deferred to a fast-follow release.

---

## Scoring Modes

Set once at room creation (per-question toggling is a future improvement). Three modes:

| Mode | Internal value | Description |
|---|---|---|
| Majority | `:majority` | Score if you pick the most popular answer. Perfect tie = no points for anyone. |
| Minority | `:minority` | Score if you do *not* pick the most popular answer. With 3–4 options, all non-majority answers are winners (2nd, 3rd, 4th place all score). |
| Host Choose | `:host_choose` | Host inputs the correct answer during the review phase. Designed for wedding/shower "who knows the couple best" style questions. |

**Scoring formula:**
- Flat base points (1000) for being on the winning side
- Speed bonus on top — same tapering approach as Speed Trivia (first to submit gets maximum bonus, trailing off). Being fast is risky: you commit before knowing which way the crowd goes.
- Perfect tie in majority mode (two or more options tied for first): no points for anyone on that question. In minority mode, a perfect tie means everyone tied for first — nobody is in a true minority, so no points either.

**Future extension:** Eventually the "special person" in host_choose mode could submit from their own phone rather than having the host input the answer via backstage.

---

## Data Model

### Pack & Questions

- **`PollPack`** — belongs to a user, has many `PollQuestion`s
- **`PollQuestion`** — body text, 2–4 multiple choice options (A/B/C/D). No `correct_answer` field — unlike `TriviaQuestion`.

### Game

**`PollGame`** — belongs to room

| Column | Type | Notes |
|---|---|---|
| `status` | string | AASM state column |
| `scoring_mode` | string | enum: `majority`, `minority`, `host_choose` |
| `current_question_index` | integer | |
| `question_count` | integer | |
| `timer_enabled` | boolean | |
| `time_limit` | integer | seconds per question |
| `timer_increment` | integer | timer job interval |
| `host_chosen_answer` | string | nullable; set by host during reviewing in host_choose mode, cleared on next question |

### Answers

**`PollAnswer`** — belongs to poll_game, player, poll_question

| Column | Type | Notes |
|---|---|---|
| `selected_option` | string | `a`, `b`, `c`, or `d` |
| `submitted_at` | datetime | for speed bonus calculation |
| `points_awarded` | integer | set when round closes |

---

## State Machine

```
instructions → waiting → answering → reviewing → (loop back to waiting) → finished
```

| State | Description |
|---|---|
| `instructions` | Intro screen. Host starts when ready. |
| `waiting` | Between questions. Host triggers next question. |
| `answering` | Timer running (if enabled). Players submit answers. Stage hides vote distribution to preserve tension. |
| `reviewing` | Voting closed. Results shown. Majority/minority: scores auto-calculated on transition. Host choose: host picks answer first, then scores calculate. Loops back to `waiting` until all questions done. |
| `finished` | Game over. Final leaderboard shown. |

---

## Controllers

Following the `/new-game` skill conventions:

- `PollGames::GameStartsController` — `include GameHostAuthorization`, `include RendersHand`
- `PollGames::AnswersController` — player submits answer
- `PollGames::RoundsController` — host closes voting, advances to next question, finishes game
- `PollGames::HostAnswersController` — host submits chosen answer in `host_choose` reviewing phase

All controllers:
- Include `GameHostAuthorization` (never reimplement auth inline)
- Include `RendersHand` and call `render_hand` (never `head :no_content`)
- Pass `code: room.code` in all host-action form params (defense-in-depth)

---

## Service Module (`Games::Poll`)

Implements the full game module contract:

```ruby
module Games
  module Poll
    def self.requires_capacity_check? = false
    def self.game_started(room:, scoring_mode:, question_count:, time_limit:, timer_enabled:, timer_increment:, show_instructions:, **_extra)
    def self.start_from_instructions(game:)
    def self.start_question(game:)
    def self.submit_answer(game:, player:, selected_option:)
    def self.close_round(game:)           # majority/minority: calculates scores immediately
    def self.set_host_answer(game:, answer:)  # host_choose only: sets host_chosen_answer, calculates scores
    def self.next_question(game:)
    def self.handle_timeout(game:)

    # Single broadcast exit point
    def self.broadcast_all(game)          # private
    
    module Playtest
      # start, advance, bot_act, auto_play_step, progress_label, dashboard_actions
    end
  end
end
```

**Concurrency conventions:**
- All state-modifying operations wrapped in `game.with_lock { }`
- `broadcast_all` called **outside** the lock
- `broadcast_all` is the single exit point — no scattered `GameBroadcaster` calls

---

## Views

### Stage Partials (projected screen)

One partial per AASM state. All follow `/stage-view` skill constraints:
- First child: `<div id="stage_<status>">`
- All sizing in `text-vh-*` and `[Xvh]` — never `px` or `rem`
- No inline `animate-*` classes (use `stage-transition` Stimulus controller)
- No scrolling on stage root

| Partial | Content |
|---|---|
| `_stage_instructions` | Game title, scoring mode description, player count |
| `_stage_waiting` | Question number badge, "Get Ready", player count |
| `_stage_answering` | Question + options grid, submission count, countdown timer. Vote distribution hidden. |
| `_stage_reviewing` | Question + `_vote_summary` sub-partial (bars per option, majority highlighted) + `_score_podium`. For `host_choose`: vote breakdown shows immediately, scores hold until host picks. |
| `_stage_finished` | Final podium — reuses `_score_podium` pattern |

### Hand Partials (player phones)

| Partial | When shown |
|---|---|
| `games/shared/hand_instructions` | `instructions` state (shared partial, already exists) |
| `_answer_form` | `answering` — tap A/B/C/D, submit. Locks after submission. Button disable deferred via `setTimeout` (not synchronous — avoids known Stimulus click handler bug). |
| `_waiting` | `waiting` state ("Get Ready") AND `reviewing` state ("Here's how you did" — result inline). Same pattern as Speed Trivia's `_waiting`. |
| `_game_over` | `finished` state |

Host controls rendered conditionally inside `_hand` when `player == room.host`.

### Host Controls by State

| State | Controls |
|---|---|
| `instructions` | "Start Game" |
| `waiting` | "Start Question" |
| `answering` | Answer count, timer display, "Close Voting" |
| `reviewing` (majority/minority) | "Next Question" / "Finish Game" |
| `reviewing` (host_choose) | Option buttons "Set Answer: A / B / C / D" → scores calculate → "Next Question" / "Finish Game" |
| `finished` | Success message, link to host page |

---

## Pack Editor (Backstage)

Same backstage pattern as `TriviaPack`. No correct answer field — just question body + 2–4 options.

### Prerequisite: Stimulus Controller Extraction

**Must be done before building the poll editor.** The `trivia_editor_controller.js` (717 lines) has ~80% reusable logic. Approach from the backlog:

1. **Audit** `trivia_editor_controller.js` to identify shared seams
2. **Extract** `question_list_editor_controller.js` — pure JS, no Turbo Streams. Covers: drag/drop reorder, template clone lifecycle, position tracking, collapse/expand, count display
3. **Slim** `trivia_editor_controller.js` to trivia-only concerns (correct answer sync, image management). Verify existing trivia tests pass.
4. **Build** `poll_editor_controller.js` as a thin wrapper. Include a stub hook for the future free-response toggle (deferred to fast-follow release).
5. **Surgical Turbo Stream option**: options add/remove may use a Turbo Stream endpoint for shared ERB partials — shared markup rendered server-side, JS still handles interactivity. Not a full rewrite.

---

## Registry & Room Constants

```ruby
# config/initializers/game_registry.rb
GameEventRouter.register_game("Poll Game", Games::Poll)
DevPlaytest::Registry.register(PollGame, Games::Poll::Playtest)

# app/models/room.rb
POLL_GAME = "Poll Game".freeze
GAME_TYPES = [ WRITE_AND_VOTE, SPEED_TRIVIA, CATEGORY_LIST, POLL_GAME ].freeze
GAME_DISPLAY_NAMES = {
  # ... existing ...
  POLL_GAME => "Bandwagon"
}.freeze
```

---

## Testing

Following the `/multiplayer-spec` and `/new-game` skill checkpoints.

### System Spec — Majority Mode (happy path)
- Host creates room with Bandwagon, scoring mode: majority
- 3+ players join and answer a question
- Voting closes (both manual and timer-expiry paths)
- Stage shows vote breakdown, majority answer highlighted
- Only majority players receive points
- Faster answerer in majority gets more points than slower answerer
- Perfect tie → no points awarded
- Full game completes, finished screen shown

### System Spec — Host Choose Mode
- Same setup, scoring mode: host_choose
- Voting closes, stage shows vote breakdown (no scores yet)
- Host clicks "Set Answer: B" in host controls
- Only players who picked B receive points
- Stage updates with scores after host picks

### JS Behavior (requires real browser clicks — not covered by playtest bots)
- Answer button locks after submission (cannot re-submit)
- Answer button disable uses `setTimeout` deferral, not synchronous (avoids known Stimulus bug)
- Optimistic UI (if any) paired with server response listener

### Checkpoints (from `/new-game` skill)
- `[CHECKPOINT]` after stage partials: run `bin/rspec`
- `[CHECKPOINT]` after hand partials: run `bin/rspec`
- Final: `bin/rspec`, `rubocop -A`, `brakeman -q`

---

## Out of Scope (v1)

- Free-response questions (fast-follow)
- Per-question scoring mode toggle (future)
- Mix-and-match questions across game types (future — requires shared base abstraction)
- Special participant submitting oracle answer from their phone (future)
- Minority mode system spec (covered by majority spec; modes share scoring infrastructure)
