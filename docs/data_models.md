# Data Models

## Design Principles

- **Generic Core, Specific Games**: Core models (`Room`, `Player`) are game-agnostic. Game-specific models (e.g., `WriteAndVoteGame`, `Response`) handle the specifics.

- **Polymorphic Game Association**: `Room` has a polymorphic `current_game` association, allowing different game types to have different models with different attributes.

- **Start Concrete, Refactor When Needed**: Avoid premature abstraction. If a model works for the first few games, keep it simple.

## Model Relationships

For current attributes and schema details, see `db/schema.rb`. Below describes the conceptual relationships.

### Room
The game session that players join via a 4-letter code.
- Has many `Player` records
- Has one `current_game` (polymorphic - could be `WriteAndVoteGame` or future game types)
- Optionally belongs to a `PromptPack`

### Player
A participant in a game session, identified by browser session for reconnection.
- Belongs to a `Room`
- Has game-specific associations (responses, votes) depending on the game type

### PromptPack / Prompt
The question/prompt system.
- `PromptPack` groups related prompts (can be user-created or default)
- `Prompt` is a single question/prompt text
- `PromptInstance` represents a prompt being used in a specific game round

### Game-Specific Models

Each game type has its own models. For WriteAndVote:
- `WriteAndVoteGame` - The game instance with state machine and timer
- `PromptInstance` - A prompt assigned to a round
- `Response` - A player's answer to a prompt
- `Vote` - A player's vote for a response

## State Machines

Game models use AASM for state management. The state machine defines valid phases and transitions. Look for `include AASM` in model files.

## Session-Based Identity

Players are identified by Rails session ID, not user accounts. This allows reconnection without authentication - if a player's browser reconnects with the same session, they rejoin as the same player.
