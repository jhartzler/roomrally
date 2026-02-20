# Speed Trivia Single Review Screen Design

**Goal:** Collapse the two-step reviewing flow into a single combined screen showing vote distribution and scores simultaneously, eliminating the 5-second inter-step delay.

**Architecture:** `close_round` absorbs score calculation immediately. A single stage partial replaces two. The `reviewing_step` state machine sub-step is retired.

**Tech Stack:** Ruby on Rails 8, AASM, Hotwire Turbo Streams, Stimulus, Tailwind CSS

---

## Backend

### `Games::SpeedTrivia#close_round`
Absorbs the work previously split across `close_round` + `show_scores`:
1. `game.close_round!`
2. Capture `game.previous_top_player_ids` (top-4 player IDs before recalculation)
3. Call `game.calculate_scores!`
4. `broadcast_all(game)`

### Deleted methods
- `Games::SpeedTrivia#show_scores` — no longer needed
- `Games::SpeedTrivia#schedule_score_reveal` — no longer needed

### `SpeedTriviaGame` model
- Remove `reset_reviewing_step` AASM `after` callback from `close_round` event — `reviewing_step` no longer toggles
- Remove `"score_reveal"` branch from `process_timeout` — only round-timer expiry remains
- `reviewing_step` column stays in DB unused (no migration)

### `next_question`
Remove the redundant `game.calculate_scores!` safety-net call — `close_round` always calculates now.

### `GameBroadcaster#broadcast_stage`
Remove the `reviewing_step == 2 → "reviewing_scores"` special-casing. All reviewing states use a single partial name.

### `stages/show.html.erb`
Remove the `reviewing_step == 2` partial-selection logic added this session — now dead code.

### `Games::SpeedTrivia::Playtest#auto_play_step`
Simplify `when "reviewing"` to call `Games::SpeedTrivia.next_question(game:)` directly — no `reviewing_step` branch.

---

## Stage View

### `_stage_reviewing.html.erb` (redesigned)
Single combined partial replacing both `_stage_reviewing.html.erb` and `_stage_reviewing_scores.html.erb`.

Layout (two halves, full-viewport, no scroll):
- **Top half — vote distribution row:** 4 answer options displayed horizontally in a single row. Each shows its letter badge, option text, and vote count. Correct answer(s) highlighted green, wrong options muted. Uses `question.vote_counts` (same data source as current `_vote_summary`).
- **Bottom half — score podium:** Existing `_score_podium.html.erb` partial, unchanged. `previous_top_player_ids` still passed in so bonk/enter animations work.

### `_vote_summary.html.erb` (redesigned)
Changed from 2×2 grid to 4-column horizontal row to fit the top strip.

### `_stage_reviewing_scores.html.erb` (deleted)
No longer referenced anywhere.

---

## Hand View

### `_waiting.html.erb` (simplified)
All `reviewing_step` branching removed. Since `calculate_scores!` runs before broadcast, `player.score` is already the new total when the hand renders.

Score animation always uses:
- `score_from = player.score - round_points` (old total)
- `score_to = player.score` (new total)

Count-up fires immediately when the reviewing screen appears. If `round_points == 0`, `from == to` → no animation (correct behavior).

Rank always uses actual post-round standings. `sorted_prev` / `sorted_now` comparison still works via `round_points_by_id`.

---

## Tests to Update

- `spec/requests/stage_view_spec.rb` — remove `reviewing_step == 2` test case (now dead)
- `spec/requests/hand_view_spec.rb` — remove `reviewing_step == 1` test case, update `reviewing_step == 2` test to reflect that `reviewing_step` is no longer set (or that the single reviewing state always animates)
- `spec/services/games/speed_trivia/playtest_spec.rb` — update `auto_play_step` reviewing tests
- Any spec testing `show_scores` or `schedule_score_reveal` — delete or repurpose
