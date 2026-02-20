# Dev Playtest Co-location — Design (Approach B)

**Date:** 2026-02-18

## Problem

Two issues with the current `/dev/testing` auto-play feature:

1. **Bug:** When auto-playing SpeedTrivia, scores are never shown between rounds. The
   `auto_play_step` method advances immediately from `reviewing` to the next question, skipping
   the score-podium step (`reviewing_step == 2`). Manual testing works because the human waits
   long enough for the 5-second `GameTimerJob` to fire and advance to step 2 first.

2. **Friction:** Each game requires a separate `DevPlaytest::GameName` module
   (`app/services/dev_playtest/`) that duplicates game-lifecycle knowledge. The separation makes
   it easy to miss sub-states (exactly how the bug was introduced). Registering a new game
   requires writing ~50 lines across two files.

## Solution (Approach B — Co-locate, Plain Methods)

Move each `DevPlaytest::GameName` module into a nested `Playtest` module inside the corresponding
game service (`Games::GameName::Playtest`). Fix the SpeedTrivia bug during the migration. No new
abstractions in this pass; a DSL/base-module refactor (Approach A) follows later when the code is
in one place.

## Bug Fix Detail

In `DevPlaytest::SpeedTrivia#auto_play_step`, the `"reviewing"` branch must check `reviewing_step`:

```ruby
when "reviewing"
  if game.reviewing_step == 1
    Games::SpeedTrivia.show_scores(game:)   # step 1 → 2: broadcast score podium
  else
    Games::SpeedTrivia.next_question(game:) # step 2 → next question
  end
```

The manual `advance` method does **not** need the same change — when a human clicks "Next
Question", the 5-second timer has already fired and advanced `reviewing_step` to 2 naturally.

## File Changes

| Action | File |
|--------|------|
| Modify | `app/services/games/speed_trivia.rb` — add nested `Playtest` module with bug fix |
| Modify | `app/services/games/write_and_vote.rb` — add nested `Playtest` module |
| Modify | `app/services/games/category_list.rb` — add nested `Playtest` module |
| Modify | `config/initializers/game_registry.rb` — point registry at new nested modules |
| Delete | `app/services/dev_playtest/speed_trivia.rb` |
| Delete | `app/services/dev_playtest/write_and_vote.rb` |
| Delete | `app/services/dev_playtest/category_list.rb` |
| Keep   | `app/services/dev_playtest/registry.rb` — unchanged |

## Out of Scope

- No changes to `DevTestingController`, views, Stimulus controllers, or routes
- No changes to existing game logic methods
- No new `DevPlaytest::GameHandler` base module (Approach A, future pass)
