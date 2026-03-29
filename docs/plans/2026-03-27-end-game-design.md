# End Game Feature Design

**Date:** 2026-03-27
**Status:** Draft

## Problem

Games that aren't played to completion stay listed as "open" for 24 hours until the `AbandonedGameCleanupJob` picks them up. This is common — test games, groups that lose interest mid-game, accidental starts. There's no way for a host to end a game once it's started.

## Solution

A single "End Game" button available to any host (hand-view or backstage) during any active game state. The button gracefully concludes the game based on whether meaningful play has occurred.

## Behavior

### Two paths based on game state

**Path 1 — Game has scoreable data:**
Calculate scores from whatever submissions exist, transition to `finished`, show the normal final scores screen. Players get the standard game-over experience as if the game completed naturally, just with fewer rounds/questions.

**Path 2 — No scoreable data (instructions screen, no submissions yet):**
Destroy the current game record, reset the room back to `lobby`. Players see the lobby/waiting screen. Host can adjust settings and restart the same game type.

### Confirmation

A confirmation dialog ("Are you sure? This will end the game for all players.") prevents accidental taps. Handled by a Stimulus controller on the button.

## `has_scoreable_data?`

Each game type defines what constitutes scoreable data:

| Game Type | `has_scoreable_data?` returns true when |
|-----------|----------------------------------------|
| **SpeedTrivia** | Any `TriviaAnswer` records exist for the game |
| **WriteAndVote** | Any `Vote` records exist for the game's prompt instances |
| **CategoryList** | Any `CategoryAnswer` records exist for the game |

This is a model-level method on each game model, since it's a simple data query.

## Service Layer

Each game service gets a `finish_game!(game:)` method:

```ruby
def self.finish_game!(game:)
  if game.has_scoreable_data?
    game.with_lock do
      game.calculate_scores!
      game.finish_game!
    end
    GameEvent.log(game, "game_finished", details: "ended early by host")
    game.room.finish!
    broadcast_all(game)
  else
    game_to_destroy = game
    room = game.room
    room.update!(current_game: nil)
    game_to_destroy.destroy!
    room.reset_to_lobby!
    GameBroadcaster.broadcast_stage(room)
    GameBroadcaster.broadcast_hand(room)
    GameBroadcaster.update_all_host_controls(room)
  end
end
```

**Note:** The exact broadcast calls for the lobby-reset path need verification during implementation — the current lobby broadcasts may use different methods.

### Score calculation edge cases

- **SpeedTrivia:** Per-answer points are already calculated on submission. `calculate_scores!` just sums them to `player.score`. Safe to call at any point.
- **WriteAndVote:** `calculate_scores!` counts votes per player's responses. If mid-voting (some prompts voted, some not), scores reflect only completed votes. This is acceptable — partial scores are better than no scores.
- **CategoryList:** Round scores require `calculate_round_scores` before `calculate_total_scores`. If ending mid-review or mid-fill, only previously scored rounds contribute. Current round's answers may not have `points_awarded` set yet. The `finish_game!` method should call `calculate_round_scores` for the current round if in reviewing/scoring state, then `calculate_total_scores`.

## Room Model Changes

New AASM event on Room:

```ruby
event :reset_to_lobby do
  transitions from: :playing, to: :lobby
end
```

This allows the "no data" path to return the room to its initial state.

## Controller

New `GameFinishesController` with a single `create` action:

- Includes `GameHostAuthorization` and `RendersHand`
- Resolves the game type and delegates to the appropriate service via `GameEventRouter`
- Route: `POST /game_finishes` (or nested under each game type if that fits routing conventions better)

## Host Controls UI

An "End Game" button added to each game type's `_host_controls.html.erb`:

- Visible in all active game states (not in `finished`)
- Styled as secondary/destructive (muted color, not the primary action button)
- Uses a `confirm-action` Stimulus controller (or similar) for the confirmation dialog
- Passes `code: room.code` in params (defense-in-depth per project conventions)

## Scope

### In scope (initial implementation)
- `finish_game!` method per game service (SpeedTrivia, WriteAndVote, CategoryList)
- `has_scoreable_data?` method per game model
- `reset_to_lobby!` AASM event on Room
- `GameFinishesController` with host authorization
- "End Game" button in host controls for all three game types
- Confirmation dialog via Stimulus
- System tests for both paths (has data / no data) for each game type

### Follow-up (not in initial scope)
- Extract common `finish_game!` orchestration into a shared `Games::Finishable` concern
- Consider whether existing natural-finish paths should also route through the shared concern
- Backstage-specific UI refinements if needed

## Open Questions

None — ready for implementation planning.
