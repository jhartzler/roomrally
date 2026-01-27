# Client Architecture Guide

The client architecture is based on **Hotwire (Turbo + Stimulus)**, following an HTML-Over-the-Wire approach.

## Technology

- **Turbo**: Handles page updates via Turbo Streams (real-time) and Turbo Drive (navigation)
- **Stimulus**: Small client-side controllers for interactions like form handling, timer display, fullscreen mode
- **Importmap**: Manages JavaScript dependencies without a build step

## Client Types

### Stage Client (`/rooms/:code/stage`)

The main screen that all players look at.

- **Purpose**: Display-only, showing the public game state
- **Characteristics**: Large screen format, minimal interaction
- **Receives**: Game-wide broadcasts (room stream)

### Hand Client (`/rooms/:code/hand`)

The personal device each player uses to interact.

- **Purpose**: Input device and personal display
- **Characteristics**: Mobile-first, interactive (forms, buttons)
- **Receives**: Both game-wide broadcasts and player-specific updates

## UI Update Flow

The server drives all UI changes:

1. Game event occurs on the server
2. `GameBroadcaster` renders a Rails partial
3. Broadcasts via `Turbo::StreamsChannel` with target DOM ID
4. Client's browser receives and automatically updates DOM

## Stimulus Controllers

Look in `app/javascript/controllers/` for client-side behavior. Controllers handle things like:
- Form submission interception
- Timer countdown display
- Fullscreen/wake lock for Stage
- WebSocket connection status

## Routing

- `/` - Home page (create or join room)
- `/rooms/:code` - Room entry (choose Stage or Hand)
- `/rooms/:code/stage` - Stage client
- `/rooms/:code/hand` - Hand client
- `/rooms/:code/backstage` - Host moderation interface

## Session Identity

Players are identified by Rails session. No login required. If a player disconnects and reconnects with the same browser session, they rejoin as the same player.
