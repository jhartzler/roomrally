# Ticket 01: Setup Core Game and Player Models

## Description
Create the `Game` and `Player` models which are the core foundation for a game session.

- **Game Model:**
  - `room_code` (string, unique, indexed): A 4-letter code for joining.
  - `status` (string, default: 'lobby'): The current state of the game (e.g., lobby, prompting, etc.).
  - `host_id` (integer, foreign_key to players): The ID of the player who created the game.
  - Associations: `has_many :players`.

- **Player Model:**
  - `name` (string): The player's display name.
  - `score` (integer, default: 0): The player's score.
  - `session_id` (string, indexed): A unique ID stored in the user's session for reconnection.
  - Associations: `belongs_to :game`.

A mechanism to generate a unique, random 4-letter `room_code` must be implemented when a new `Game` is created.

## Acceptance Criteria
- `Game` and `Player` model files and their corresponding migrations are created.
- RSpec tests are written to verify:
  - `Game` model validations (e.g., uniqueness of `room_code`).
  - `Player` model validations.
  - The `Game` and `Player` associations.
  - The automatic generation of a `room_code` on `Game` creation.
- All tests pass.
