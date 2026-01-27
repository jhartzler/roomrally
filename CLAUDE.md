# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Room Rally is an open-source, real-time multiplayer party game engine inspired by Jackbox Games. Players connect via 4-letter room codes using their phones (Hand clients) while viewing a shared screen (Stage client). The system uses HTML-Over-The-Wire architecture with Rails backend and Hotwire frontend.

## Technology Stack

- **Backend**: Ruby on Rails 8+ (Ruby 3.4.7)
- **Real-time Communication**: Action Cable (WebSockets) + Turbo Streams
- **Frontend**: Hotwire (Turbo + Stimulus), Tailwind CSS
- **Background Jobs**: Sidekiq
- **Event Bus**: Wisper
- **State Machine**: AASM
- **Database**: PostgreSQL
- **Testing**: RSpec, Capybara with Playwright driver

## Development Commands

### Setup
```bash
bin/setup              # Initial setup: install dependencies, setup database
```

### Running the Application
```bash
bin/dev                # Start Rails server, Sidekiq, and Tailwind CSS watcher
```

### Testing
```bash
bin/rspec              # Run all tests
bin/rspec spec/path/to/specific_spec.rb           # Run a specific test file
bin/rspec spec/path/to/specific_spec.rb:42        # Run a specific test by line number
bin/rspec spec/system  # Run only system tests (most important for multiplayer flows)
bin/rspec spec/models  # Run only model tests
```

### Code Quality
```bash
rubocop               # Check code style
rubocop -A            # Auto-fix code style issues (run before committing)
```

## Architecture Principles

### Three-Layer Design

1. **Communication Layer** (Action Cable)
   - Generic, game-agnostic WebSocket handling
   - Routes messages to appropriate game logic based on `game_type`
   - Uses Turbo Streams for all UI updates

2. **Application Core** (Game Logic)
   - Strategy Pattern: Each game type is a separate module in `app/services/games/`
   - Game logic modules publish events but perform no side effects directly
   - State managed via AASM in game model classes

3. **Event System** (Wisper + Listeners)
   - Game logic publishes events (`:round_started`, `:vote_cast`, etc.)
   - Separate listeners handle broadcasting, scoring, timers
   - Decouples concerns for testability

### Core Design Principles

- **Server-Authoritative**: Server is single source of truth; clients are "dumb terminals"
- **HTML-Over-The-Wire**: Server renders all UI as HTML sent via Turbo Streams over Action Cable
- **Pragmatic Simplicity**: Build the simplest thing that works; add complexity only when forced by real problems
- **Composition Over Inheritance**: Use concerns/modules instead of deep inheritance
- **Tell, Don't Ask**: Follow Law of Demeter (call `game.complete_round!` not `game.status = "complete"`)

## Code Organization

### Key Directories

- `app/services/games/` - Game logic modules (Strategy Pattern implementations)
- `app/broadcasters/` - Turbo Stream broadcasting logic (e.g., `GameBroadcaster`)
- `app/models/concerns/` - Shared model behaviors (e.g., `HasRoundTimer`)
- `app/jobs/` - Background jobs (e.g., `GameTimerJob`)
- `spec/system/` - End-to-end multiplayer flow tests (most critical tests)

### Models

**Core Models** (game-agnostic):
- `Room` - Game session with 4-letter code, tracks `game_type` and `status`
- `Player` - Participant with session-based reconnection
- `PromptPack` / `Prompt` - Question/prompt system
- `PromptInstance` - Specific prompt assignment in a game
- `Response` - Player submissions
- `Vote` - Player votes on responses

**Game-Specific Models**:
- `WriteAndVoteGame` - Implements the main game type with AASM state machine

### Broadcasting Pattern

All UI updates use Turbo Streams broadcast via `GameBroadcaster`:
```ruby
# Game-wide broadcasts (Stage client)
Turbo::StreamsChannel.broadcast_update_to(room, target: "stage_content", partial: "games/write_and_vote/stage_voting", locals: { room:, game: })

# Player-specific broadcasts (Hand client)
Turbo::StreamsChannel.broadcast_update_to(player, target: "hand_screen", partial: "rooms/hand_screen_content", locals: { room:, player: })
```

### Client Architecture

Two client types:
- **Stage** (`/rooms/:code/stage`) - Display-only main screen
- **Hand** (`/rooms/:code/hand`) - Interactive player controller

Stimulus controllers:
- `game_connection_controller` - WebSocket connection management
- `stage_controller` / `hand_controller` - Client-specific interactions
- `timer_controller` - Visual countdown display

## Development Workflow

### Test-Driven Development (TDD)

Follow Red-Green-Refactor cycle:
1. **Red**: Write failing test describing desired behavior
2. **Green**: Write simplest code to make test pass
3. **Refactor**: Improve implementation with test safety net

### Testing Layers

- **Model Tests**: Validations, associations, scopes
- **Service Tests**: Game logic in isolation with stubbed dependencies
- **System Tests**: Full end-to-end multiplayer flows (MOST IMPORTANT)
  - Use multiple Capybara sessions to simulate Stage and multiple Hand clients
  - Verify real-time updates via Action Cable

### Adding a New Game Type

1. Create game model in `app/models/` with AASM state machine
2. Create game logic module in `app/services/games/[game_name].rb`
3. Create view partials for each game state in `app/views/games/[game_name]/`
4. Add game type to room model's `game_type` enum
5. Implement required methods: `game_started`, `process_vote`, `check_all_responses_submitted`, `handle_timeout`
6. Write system tests first for multiplayer flows

### Git Workflow

- Commit after each Red-Green-Refactor cycle
- Use conventional commit messages (e.g., `feat: Add voting phase to WriteAndVote`)
- Run `rubocop -A` before committing
- Develop on feature branches, merge to `main` when all tests pass

## Key Patterns & Conventions

### Game State Flow Example (WriteAndVote)

States: `writing` → `voting` → `finished`

- Players submit responses → check if all done → transition to `voting`
- Players vote on responses → advance through prompts → calculate scores
- Complete all rounds → transition to `finished`

### Timer System

Games using timers must include `HasRoundTimer` concern:
```ruby
class WriteAndVoteGame < ApplicationRecord
  include HasRoundTimer

  def process_timeout(job_round_number, job_step_number)
    # Verify we're still in the expected state
    # Then handle timeout (e.g., fill empty responses, advance state)
  end
end
```

Timers are scheduled via `GameTimerJob` and publish timeout events back to game logic.

### Namespacing

- Game-specific code namespaced under game module (e.g., `Games::WriteAndVote`)
- Keep game logic isolated from generic infrastructure

## Important Notes

- **No Channels Directory**: This app uses direct Turbo Stream broadcasting instead of custom Action Cable channels
- **Session-Based Auth**: Players identified by Rails session `session_id` for reconnection, no user accounts required
- **Concurrent Safety**: Use `with_lock` for state transitions that check-then-modify game state
- **RuboCop Config**: System specs excluded from `ExampleLength` and `MultipleExpectations` limits
- **Playwright for System Tests**: JavaScript-heavy real-time features require proper browser automation

## Documentation

Comprehensive docs in `docs/` directory:
- `architecture.md` - Detailed system architecture
- `game_logic_guide.md` - How to implement new games
- `data_models.md` - Database schema and model relationships
- `real_time_communication.md` - WebSocket and Turbo Streams
- `client_guide.md` - Frontend architecture
- `development_guide.md` - Development practices
