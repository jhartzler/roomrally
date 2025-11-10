# Real-Time Communication Layer

This layer is responsible for managing WebSocket connections and message traffic between the server and clients (Stages and Hands).

## Core Component: `GameChannel`
A single, generic `GameChannel` handles all real-time communication for all game types. This avoids channel proliferation and code duplication.

### Responsibilities
- **Authentication**: Identifies the connecting client (player or Stage) via the Rails session.
- **Subscription**: Subscribes the client to the correct Turbo Streams for receiving UI updates.
- **Routing**: Receives incoming messages (e.g., `submit_data`, `start_game`) and routes them to the appropriate Game Logic module based on the game's `game_type`.
- **Authorization**: Performs basic checks to ensure the player is part of the game they are trying to interact with.

The `GameChannel` itself contains **no game-specific logic**. It is purely a router.

## Game Type Registry
To securely route messages, the channel uses a registry (a simple Hash) that maps `game_type` strings (e.g., `"WriteAndVote"`) to the corresponding game logic class (e.g., `WriteAndVote::Logic`). This avoids unsafe `constantize` calls on user-provided data.

## Turbo Streams
The server communicates UI changes to clients almost exclusively through Turbo Streams.

### Stream Naming Convention
- **Game-wide broadcasts**: Target the `Game` model itself. The Stage client subscribes to this stream.
  - `stream_for @game`
- **Player-specific broadcasts**: Target a unique stream combining the game and player. Hand clients subscribe to this in addition to the game-wide stream.
  - `stream_for [@game, @player]`

### Message Flow
1. Client sends a message via WebSocket (e.g., a form submission handled by Stimulus).
2. `GameChannel` receives the action.
3. Channel identifies the game and player, finds the correct game logic module from the registry.
4. Channel delegates the message to the game logic module (e.g., `WriteAndVote::Logic.handle_submission(player, data)`).
5. Game logic processes the action and publishes an event (e.g., `:answer_submitted`).
6. A `BroadcastListener` catches the event, renders the appropriate Rails partial into a Turbo Stream message.
7. The listener broadcasts the Turbo Stream to the relevant stream(s).
8. Clients receive the broadcast and automatically update the DOM.
