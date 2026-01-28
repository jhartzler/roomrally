# System Architecture

## Core Principles

- **Server-Authoritative**: The server is the single source of truth for all game state and timing. Clients are "dumb terminals" that send input and display the state they are given. This simplifies synchronization and prevents cheating.

- **HTML-Over-The-Wire**: The server renders all UI as HTML, sent to clients via Turbo Streams. This keeps all rendering logic in Rails views, eliminates the need for a separate frontend framework, and simplifies testing.

- **Pragmatic Simplicity**: Build the simplest thing that works. Add complexity only when forced by real problems discovered during playtesting.

## Request Flow

The application follows a straightforward request/response pattern:

```
HTTP POST → Controller → Game Service Module → GameBroadcaster → Turbo Streams → Clients
```

1. Player action (submit answer, cast vote) sent as HTTP POST
2. Controller validates request, finds game/player
3. Controller calls appropriate game service method (e.g., `Games::WriteAndVote.process_vote`)
4. Game service updates state, then calls `GameBroadcaster` methods
5. `GameBroadcaster` renders partials and broadcasts via `Turbo::StreamsChannel`
6. Clients receive Turbo Stream updates and DOM is automatically updated

This is intentionally simple. There is no custom Action Cable channel or event bus between components.

## Actor Model

The system involves three main actors:

- **Server (Rails)**: The authoritative director. Manages state, enforces rules, and orchestrates the game flow.
- **Stage (Main Screen)**: A display-only subscriber. Receives game-wide broadcasts and shows the public game state.
- **Hand (Player Controller)**: An input device. Sends player actions (joining, submitting, voting) and receives both game-wide and player-specific UI updates.

## Key Design Decisions

### Why No Custom Action Cable Channels?

Turbo Streams with `Turbo::StreamsChannel` provides everything needed. Custom channels would add complexity without benefit for this use case.

### Why No Event Bus / Pub-Sub for Game Logic?

Direct method calls are easier to trace, debug, and test. An event-driven architecture (Wisper listeners, etc.) was considered but deemed unnecessary for a small number of game types maintained by one team. This could be revisited if the platform grows to support many game types or third-party games.

### Why Game Logic in Service Modules?

The Strategy Pattern allows different game types without modifying controllers or broadcasters. Each game type is a module in `app/services/games/` that implements the game-specific rules. See `game_logic_guide.md` for details.

## Concurrency

Game state transitions that check-then-modify (e.g., "have all players voted?") use database-level locking (`with_lock`) to prevent race conditions. This is critical for correct behavior when multiple players act simultaneously.

## Where to Find Things

- **Game logic**: `app/services/games/`
- **Broadcasting**: `app/broadcasters/game_broadcaster.rb`
- **Game models with state machines**: `app/models/` (look for `include AASM`)
- **Timer handling**: `app/jobs/game_timer_job.rb` and `HasRoundTimer` concern
- **Client-side controllers**: `app/javascript/controllers/`
