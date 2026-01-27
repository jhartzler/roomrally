# Game Logic Guide

This guide explains how game logic is organized and how to add a new game type.

## The Strategy Pattern

Each game type is a module in `app/services/games/` that encapsulates its rules and state transitions. This allows adding new games without modifying controllers, broadcasters, or other infrastructure.

A game logic module is responsible for:
- Validating player actions against game rules
- Updating game-specific models and state
- Determining when to transition between game phases
- Calling `GameBroadcaster` to push UI updates to clients

## Adding a New Game Type

1. **Create a game model** in `app/models/` with an AASM state machine defining the game phases
2. **Create a game logic module** in `app/services/games/your_game.rb`
3. **Create view partials** in `app/views/games/your_game/` for each game phase (naming convention: `stage_[status].html.erb`)
4. **Update Room model** if needed to support the new game type
5. **Write system tests** that simulate multiple players through the full game flow

## State Management

Games use AASM state machines to manage phases. Look at existing game models for the pattern. The state machine defines:
- Valid states (e.g., `writing`, `voting`, `finished`)
- Transitions between states
- Callbacks that run on transitions

## Concurrency

When checking conditions like "have all players submitted?" before transitioning state, always use `with_lock` to prevent race conditions:

```ruby
game.with_lock do
  if game.all_responses_submitted?
    transition_to_voting(game:)
  end
end
```

## Broadcasting Pattern

Game logic calls `GameBroadcaster` methods directly after state changes. The broadcaster renders the appropriate partial based on game type and status.

Convention for stage partials: `games/[game_type]/stage_[status]`

## Timer Integration

If your game has timed phases, include the `HasRoundTimer` concern in your game model and implement `process_timeout(round_number, step_number)` to handle what happens when time expires.
