# Data Models

## Design Principles

- **Generic Core, Specific Extensions**: Core models (`Room`, `Player`, `Round`) are generic. Game-specific models are namespaced (e.g., `WriteAndVote::Answer`) to allow different games to have different data needs.
- **Start Concrete, Refactor When Needed**: Avoid premature abstraction like polymorphic associations. If a model works for the first few games, keep it simple. Refactor only when a new game's requirements force a change.

## Core Models

### Room
Represents an instance of a game session.

- **Key Attributes**:
  - `room_code` (string, unique, indexed): 4-letter join code.
  - `game_type` (string): Maps to a logic module (e.g., "QuipKit").
  - `status` (string): Current game phase (lobby, prompting, voting, results, complete).
  - `current_round_id` (integer): Reference to the active round.
  - `timer_expires_at` (datetime): For timer recovery on reconnect.
  - `timer_event` (string): The event to fire when the timer expires.
- **Responsibilities**: Owns players and rounds, tracks overall game state.

### Player
Represents a participant in a game.

- **Key Attributes**:
  - `room_id` (integer): The room they belong to.
  - `name` (string): Display name.
  - `score` (integer, default: 0): Cumulative points.
  - `session_id` (string, indexed): For reconnection without authentication.
- **Responsibilities**: Owns game-specific data (answers, votes), tracks cumulative score.

### Round
Represents a single turn/question in a game.

- **Key Attributes**:
  - `room_id` (integer): The room this belongs to.
  - `prompt_id` (integer): The question being asked.
  - `round_number` (integer): 1, 2, 3, etc.
  - `status` (string): Phase of this round (prompting, voting, complete).
- **Responsibilities**: Owns game-specific submissions (answers, drawings).

### Prompt
Stores questions/prompts for games.

- **Key Attributes**:
  - `text` (string): The actual prompt.
  - `game_type` (string): Which game type this is for.
  - `game_pack_id` (integer, optional): For grouping themed prompts.
- **Seeding**: Start with 50-100 prompts in `seeds.rb`.

## Game-Specific Models (Example: WriteAndVote)

### WriteAndVote::Answer
Player-submitted text answers.

- **Key Attributes**:
  - `round_id`: Which round this is for.
  - `player_id`: Who submitted it.
  - `text` (string): The answer.
- **Relationships**: Has many `WriteAndVote::Vote`.

### WriteAndVote::Vote
Player votes for favorite answers.

- **Key Attributes**:
  - `round_id`: Which round this is for.
  - `player_id`: The voter.
  - `answer_id`: The answer they voted for.
- **Constraints**:
  - One vote per player per round.
  - Players cannot vote for their own answers (enforced in game logic).
