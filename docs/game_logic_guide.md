# Game Logic Guide

This guide explains how to implement the logic for a new game.

## The Strategy Pattern
Each game is a "Strategy" module that encapsulates its own rules and state transitions. This module is responsible for a single thing: managing the gameplay for its specific game type.

A game logic module **does**:
- Validate player actions against game rules (e.g., "Can this player vote right now?").
- Create and update game-specific models (e.g., `WriteAndVote::Answer`).
- Determine when to transition the game state (e.g., move from "prompting" to "voting").
- **Publish events** when significant actions occur.

A game logic module **does not**:
- Calculate scores (`ScoreListener` does this).
- Broadcast to clients (`BroadcastListener` does this).
- Manage timers (`TimerService` does this).

## The Game Logic Interface
To be a valid game type, your module must be added to the `GAME_TYPE_REGISTRY` and respond to a common set of messages that the `GameChannel` will send to it.

**Required Methods:**
- `handle_start(player:, data:)`: Called when the host starts the game.
- `handle_submission(player:, data:)`: Called when a player submits data (e.g., an answer, a drawing).
- `handle_vote(player:, data:)`: Called when a player votes.

## Publishing Events
Your game logic must not have side effects. Instead, it publishes events using a pub/sub library like Wisper. This decouples the game from other parts of the system.

**Example Flow:**
1. In `handle_submission`, you determine all players have now submitted their answers.
2. Instead of calling a broadcaster, you publish an event: `publish(:all_answers_in, game: @game)`.
3. A separate `BroadcastListener` is subscribed to this event. It wakes up, sees the event, and handles the work of rendering and broadcasting the "Voting" screen.

**Common Events to Publish:**
- `:round_started`
- `:answer_submitted`
- `:all_answers_in`
- `:voting_started`
- `:vote_cast`
- `:all_votes_in`
- `:round_complete`
- `:game_complete`

## State Management
The `Game` and `Round` models have a `status` column (e.g., `lobby`, `prompting`, `voting`). Your logic module is responsible for updating this status as the game progresses.

For the MVP, this is done with manual checks. If state transitions become complex, we may introduce a state machine gem like `aasm`.

## Example: WriteAndVote Game Flow

- **States**: `lobby` -> `prompting` -> `voting` -> `results` -> `complete`
- **Transitions**:
  - `lobby` -> `prompting`: Triggered by `handle_start`. Logic creates the first `Round`, sets game status to `prompting`, starts a timer, and publishes `:round_started`.
  - `prompting` -> `voting`: Triggered when all players have answered OR the timer expires. Logic sets status to `voting`, starts a new timer, and publishes `:voting_started`.
  - `voting` -> `results`: Triggered when all players have voted OR timer expires. Logic publishes `:round_complete`. The `ScoreListener` will hear this, calculate scores, and then publish `:scores_calculated`. The `BroadcastListener` hears *that* and shows the results screen.
