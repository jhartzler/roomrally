# Ticket 03: Implement Player Join Flow

## Description
Create the flow for a player to join a game. This covers both the host joining their own game and other players joining an existing game.

- **Routing & Controller:**
  - A route `GET /games/:room_code/join` should lead to a page (`players#new`) with a form to enter a name.
  - The name form should `POST` to `players#create`.

- **Player Creation (`players#create` action):**
  - This action should find the game by its `room_code`.
  - It should create a new `Player` record associated with the game.
  - It must generate a unique `session_id` (e.g., `SecureRandom.uuid`), store it in the Rails `session`, and save it on the `Player` record for future identification.
  - **Host Assignment:** If the joining player is the first to join the game, they must be assigned as the `host` of the game (by setting `game.host_id`).
  - After the player is created, they should be redirected to the phone's lobby view (`/games/:room_code/phone`).

## Acceptance Criteria
- A user can navigate to a join URL (either by creating a game or entering a room code).
- The user can submit their name to create a `Player` record associated with the correct game.
- A unique `session_id` is created, stored in the session, and saved to the `Player` record.
- The first player to join a game is successfully designated as the host.
- After joining, the user is redirected to their phone lobby screen.
- A system test is written to verify this flow.
