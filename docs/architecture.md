# System Architecture

## Core Principles

- **Server-Authoritative**: The server is the single source of truth for all game state and timing. Clients are "dumb terminals" that send input and display the state they are given. This simplifies synchronization and prevents cheating.
- **HTML-Over-The-Wire**: The server renders all UI as HTML, sent to clients via Turbo Streams over Action Cable. This keeps all rendering logic in Rails views, eliminates the need for a separate frontend framework, and simplifies testing.
- **Pragmatic Simplicity**: Build the simplest thing that works. Add complexity only when forced by real problems discovered during playtesting.

## Three-Layer Architecture

The system is designed in three distinct layers that communicate through well-defined interfaces.

```
+--------------------------------+
|   Communication Layer          | (Action Cable)
|  (Handles WebSocket traffic)   |
+--------------------------------+
               |
               | (Routes messages)
               v
+--------------------------------+
|   Application Core             | (Game Logic Strategies)
| (Implements game rules)        |
+--------------------------------+
               |
               | (Publishes events)
               v
+--------------------------------+
|   Event System & Listeners     | (Wisper, Sidekiq)
| (Handles side effects)         |
+--------------------------------+
```

### 1. Communication Layer
- **Responsibility**: Manages WebSocket connections and routes incoming messages. It is game-agnostic.
- **Technology**: A single, generic `GameChannel` in Action Cable.
- **Details**: See `real_time_communication.md`.

### 2. Application Core (Game Logic)
- **Responsibility**: Implements the rules and state transitions for a specific game.
- **Pattern**: The **Strategy Pattern** is used to support multiple game types. Each game is a separate module that conforms to a common interface. A central registry maps a game's `game_type` string to its corresponding logic module.
- **Key Benefit**: Adding a new game requires implementing a new strategy module, but **zero changes** to the Communication Layer or other core components.
- **Details**: See `game_logic_guide.md`.

### 3. Event System & Listeners
- **Responsibility**: Decouples game logic from side effects like scoring, broadcasting, and achievements.
- **Pattern**: Game logic **publishes events** (e.g., `:round_complete`) using a pub/sub library (like Wisper). Separate, single-purpose **listeners** subscribe to these events to perform their tasks.
- **Examples**:
    - `ScoreListener` subscribes to `:round_complete` to calculate and update scores.
    - `BroadcastListener` subscribes to various events to render and broadcast UI updates.
    - `TimerService` (via Sidekiq) publishes a `:timer_expired` event.
- **Key Benefit**: Game logic doesn't need to know about scoring or broadcasting. Concerns are isolated, testable, and extensible.

<h2>Actor Model</h2>

The system involves three main actors:

- **Server (Rails)**: The authoritative director. Manages state, enforces rules, and orchestrates the game flow.
- **Stage (Main Screen)**: A display-only subscriber. Receives game-wide broadcasts and shows the public game state.
- **Hand (Player Controller)**: An input device. Sends player actions (joining, submitting, voting) and receives both game-wide and player-specific UI updates.
