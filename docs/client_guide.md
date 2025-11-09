# Client Architecture Guide

The client architecture is based on **Hotwire (Turbo + Stimulus)**, following an HTML-Over-the-Wire approach.

## Technology
- **Hotwire**: Eliminates the need for a separate frontend framework. The server sends fully-rendered HTML, which is updated in place by Turbo Streams.
- **Stimulus**: Used for small, client-side interactions like handling form submissions, managing WebSocket connections, or controlling a countdown timer display.
- **Importmap**: Manages JavaScript dependencies without a build step.

## Client Types

There are two distinct types of clients in any game.

### 1. Stage Client (`/rooms/:room_code/stage`)
The main screen that all players look at.
- **Purpose**: Display-only, showing the public game state.
- **Characteristics**: Large screen format, receives game-wide broadcasts, minimal to no interaction.
- **Key Views**: Lobby (room code, player list), Prompting (question), Voting (all answers), Results (scores).
- **Stimulus Controllers**: `stage_controller` (fullscreen, wake lock), `game_connection_controller`, `timer_controller`.

### 2. `Hand Client (`/rooms/:room_code/hand`)
The personal device each player uses to interact with the game.
- **Purpose**: Input device and personal display.
- **Characteristics**: Mobile-first, interactive with forms and buttons, shows player-specific state.
- **Key Views**: Join Room (enter name), Lobby, Prompting (answer form), Waiting, Voting (buttons), Results (your score).
- **Stimulus Controllers**: `hand_controller` (form submission), `game_connection_controller`, `timer_controller`.

## Turbo Streams & UI Updates
The server drives all UI changes. The pattern is:
1. A game event occurs on the server.
2. A listener renders a Rails partial into an HTML string.
3. The listener wraps that HTML in a `<turbo-stream>` tag with an action (e.g., `replace`) and a target DOM ID.
4. This payload is broadcast over Action Cable.
5. The client's browser receives the stream and automatically performs the DOM update.

**Convention**: Broadcast entire screen updates rather than small fragments. This is simpler to reason about. Use consistent DOM IDs for targetable areas.
- `#stage_screen`: Main content area on the TV.
- `#hand_screen`: Main content area on the phone.
- `#player_list`: The list of players, present on both clients.
- `#timer`: The timer display.

## Stimulus Controller Design
- **`game_connection_controller`**: Shared controller responsible for establishing the WebSocket connection and providing an API for other controllers to send messages.
- **`hand_controller` / `stage_controller`**: Handle client-specific interactions (e.g., intercepting a form submission on the phone to send it over the WebSocket).
- **`timer_controller`**: Manages the visual countdown based on data received from the server.

## Routing and Sessions
- `/`: Home page to create or join a room.
- `/rooms/:code`: A splash page to choose between the TV or Phone view.
- `/rooms/:code/stage`: The Stage client.
- `/rooms/:code/hand`: The Hand client.
- A `session_id` stored in the Rails session is used to identify a player's browser. If they disconnect and reconnect, this ID allows them to rejoin the room in progress. No user accounts or passwords are required for the MVP.
