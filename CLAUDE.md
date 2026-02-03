# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Room Rally is a real-time multiplayer party game engine inspired by Jackbox Games. Players connect via 4-letter room codes using their phones (Hand clients) while viewing a shared screen (Stage client). The system uses HTML-Over-The-Wire architecture with Rails backend and Hotwire frontend.

## Technology Stack

- **Backend**: Ruby on Rails 8+ (Ruby 3.4.7)
- **Real-time**: Turbo Streams over Action Cable
- **Frontend**: Hotwire (Turbo + Stimulus), Tailwind CSS
- **Background Jobs**: Sidekiq
- **State Machine**: AASM
- **Database**: PostgreSQL
- **Testing**: RSpec, Capybara with Playwright driver

## Git Workflow

- **Never push directly to main** - Always create a feature branch for changes
- Create descriptive branch names (e.g., `feature/game-instructions-screen`, `fix/timer-bug`)
- Commit changes to the feature branch, then create a PR for review

## Development Commands

```bash
bin/setup              # Initial setup: install dependencies, setup database
bin/dev                # Start Rails server, Sidekiq, and Tailwind CSS watcher

# Testing
bin/rspec                                           # Run all tests
bin/rspec spec/path/to/specific_spec.rb             # Run a specific test file
bin/rspec spec/path/to/specific_spec.rb:42          # Run a specific test by line number
bin/rspec spec/system                               # Run system tests (most important)

# Code quality
rubocop                # Check code style
rubocop -A             # Auto-fix code style issues (run before committing)

# Worktrees
# After creating a new worktree, rebuild Tailwind CSS for tests:
RAILS_ENV=test bin/rails tailwindcss:build
```

## Troubleshooting

- **Tailwind changes not showing up?**
  If styles like `mb-24` appear in code but not in the browser, your build cache is likely stale. Run:
  ```bash
  bin/rails tmp:clear
  bin/rails assets:clobber
  ```
  Then restart `bin/dev`.

## Architecture

### Request Flow

```
HTTP POST → Controller → Game Service Module → GameBroadcaster → Turbo Streams → Clients
```

This is intentionally simple. No custom Action Cable channels, no event bus between components. Direct method calls are easier to trace and debug.

### Core Principles

- **Server-Authoritative**: Server is single source of truth; clients are "dumb terminals"
- **HTML-Over-The-Wire**: Server renders all UI as HTML sent via Turbo Streams
- **Pragmatic Simplicity**: Build the simplest thing that works
- **Strategy Pattern**: Game types are modules in `app/services/games/` with no changes needed to controllers/broadcasters

### Key Directories

- `app/services/games/` - Game logic modules (one per game type)
- `app/broadcasters/` - Turbo Stream broadcasting (`GameBroadcaster`)
- `app/models/concerns/` - Shared behaviors (e.g., `HasRoundTimer`)
- `app/jobs/` - Background jobs (`GameTimerJob`)
- `spec/system/` - End-to-end multiplayer tests (most critical)

## Adding a New Game Type

1. Create game model in `app/models/` with AASM state machine
2. Create game logic module in `app/services/games/your_game.rb`
3. Create view partials in `app/views/games/your_game/` (convention: `stage_[status].html.erb`)
4. Write system tests simulating multiple players

## Key Patterns

### Concurrency

Use `with_lock` for state transitions that check-then-modify:

```ruby
game.with_lock do
  if game.all_responses_submitted?
    transition_to_voting(game:)
  end
end
```

### Broadcasting

Game logic calls `GameBroadcaster` methods directly. Convention for stage partials: `games/[game_type]/stage_[status]`

### Timers

Games with timed phases include `HasRoundTimer` concern and implement `process_timeout(round_number, step_number)`.

## Important Notes

- **No Channels Directory**: Uses Turbo Streams directly, no custom Action Cable channels
- **Session-Based Auth**: Players identified by Rails session for reconnection, no accounts required
- **System Tests Are Critical**: Multiplayer flows must be tested with multiple Capybara sessions

## Pull Request Descriptions

Focus on what matters to a human reviewer. GitHub already shows file changes, so don't list them.

**Include:**
- **Why**: What problem does this solve? What's the context?
- **Decisions**: Non-obvious choices, tradeoffs, or things done intentionally
- **Reviewer notes**: What should they pay attention to? Any risks?
- **Configuration**: Environment variables or setup needed

**Avoid:**
- Listing files added/modified (GitHub shows this)
- Restating the commit message
- Obvious observations ("added tests for new code")

## Documentation

See `docs/` directory for detailed guides on architecture, game logic, data models, and client architecture.
