# Real-Time Communication

This document describes how real-time updates flow from server to clients.

## Technology

The application uses **Turbo Streams** over Action Cable via the built-in `Turbo::StreamsChannel`. There are no custom Action Cable channels.

## How It Works

1. Clients subscribe to Turbo Streams on page load (handled automatically by Turbo)
2. Server broadcasts updates via `Turbo::StreamsChannel.broadcast_*` methods
3. Clients receive the stream and Turbo automatically updates the DOM

All broadcasting logic is centralized in `GameBroadcaster` (`app/broadcasters/game_broadcaster.rb`).

## Stream Subscriptions

- **Room stream**: Stage clients subscribe to receive game-wide updates
- **Player stream**: Hand clients subscribe to receive player-specific updates

The views use `turbo_stream_from` helpers to establish subscriptions.

## Broadcast Patterns

`GameBroadcaster` provides methods for common broadcast scenarios:
- `broadcast_stage(room:)` - Update the main stage display
- `broadcast_hand(room:)` - Update all players' hand displays
- `broadcast_player_joined/left` - Update player lists
- `broadcast_response_submitted` - Update moderation queue

## View Conventions

Stage partials follow the naming convention: `games/[game_type]/stage_[status]`

For example, when a WriteAndVote game is in the `voting` state, the broadcaster renders `games/write_and_vote/stage_voting`.

## Why Not Custom Channels?

Turbo Streams provides everything needed for this use case. Custom Action Cable channels would add complexity without benefit. The server pushes HTML updates; clients don't need to send messages over WebSocket (they use regular HTTP POST for actions).
