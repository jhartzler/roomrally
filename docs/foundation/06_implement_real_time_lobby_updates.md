# Ticket 06: Implement Real-Time Lobby Updates

## Description
Use Action Cable and Turbo Streams to update the lobby in real-time as players join, and to manage the host's UI.

- **Broadcasting on Player Join:**
  - When a new `Player` is successfully created (in `players#create`), a broadcast must be sent to the corresponding room channel.
  - This broadcast should be a Turbo Stream that appends the new player's name to the `#player-list` element on all connected clients (Stage and Hands).
  - A partial (e.g., `players/_player.html.erb`) should be used for rendering the player.

- **Host "Start Game" Button:**
  - After a player joins, the application should check if the minimum number of players (2) has been reached.
  - If the minimum is met, a separate, targeted Turbo Stream broadcast should be sent *only to the host*.
  - This stream should replace the disabled "Start Game" button with an enabled version, allowing the host to start the game.

## Acceptance Criteria
- When a new player joins a game, their name instantly appears on the Stage screen and all other connected hand screens without a page refresh.
- The host's "Start Game" button becomes enabled automatically when the second player joins the game.
- The "Start Game" button remains disabled if there is only one player.
- A system test is written to verify these real-time updates.
