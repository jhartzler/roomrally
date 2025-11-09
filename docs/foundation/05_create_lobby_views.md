# Ticket 05: Create Lobby Views

## Description
Create the two primary views for the game lobby: the main TV screen and the player's phone controller.

- **Routing:**
  - `GET /rooms/:room_code/stage` should route to `rooms#show_stage`.
  - `GET /rooms/:room_code/hand` should route to `rooms#show_hand`.

- **Stage View (`rooms/show_stage.html.erb`):**
  - This is the main screen for all players to look at.
  - It must prominently display the 4-letter `room_code` so others can join.
  - It needs a designated area, like `<div id="player-list"></div>`, where the list of connected players will be rendered in real-time.
  - It should be visually distinct and designed for a 16:9 display.

- **Hand View (`rooms/show_hand.html.erb`):**
  - This is the screen a player sees after they have joined the game.
  - It should display a "Waiting for players..." message.
  - It should also have a player list area (`<div id="player-list"></div>`) that will be updated in real-time.
  - **Host View:** If the current player is the host, this view must also contain a "Start Game" button. This button should be disabled by default.

## Acceptance Criteria
- Routes and controller actions for the Stage and Hand views are created.
- ERB view templates exist for `show_stage` and `show_hand`.
- The Stage view displays the room's `code`.
- The Hand view for a host contains a disabled "Start Game" button.
- The HTML for both views contains a `<div id="player-list">`.
- The system test is updated to assert the presence of the room code on the Stage view and the disabled "Start Game" button on the host's Hand view.
