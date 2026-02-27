# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Room Rally is a real-time multiplayer party game engine inspired by Jackbox Games, designed for **in-person play** (classrooms, youth groups, living rooms, parties). A host projects the Stage client on a shared screen while players join on their phones via 4-letter room codes. This is NOT an online/remote multiplayer platform — the shared physical space is core to the experience. The system uses HTML-Over-The-Wire architecture with Rails backend and Hotwire frontend.

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
- **Never run `git diff` on `config/credentials.yml.enc`** — the master key is present locally, so git decrypts and displays secrets in plain text. Always exclude it: `git diff -- . ':!config/credentials.yml.enc'`

## Development Commands

```bash
bin/setup              # Initial setup: install dependencies, setup database
bin/dev                # Start Rails server, Sidekiq, and Tailwind CSS watcher

# Testing
bin/rspec                                           # Run all tests
bin/rspec spec/path/to/specific_spec.rb             # Run a specific test file
bin/rspec spec/path/to/specific_spec.rb:42          # Run a specific test by line number
bin/rspec spec/system                               # Run system tests (most important)

# Code quality (run both before every commit)
rubocop                # Check code style
rubocop -A             # Auto-fix code style issues
brakeman -q            # Check for security vulnerabilities

# Worktrees
# After creating a new worktree, rebuild Tailwind CSS for tests:
RAILS_ENV=test bin/rails tailwindcss:build

# Visual regression testing (screenshots)
# When making UI changes, use screenshot checkpoints to verify visual changes are intentional:
rake screenshots:capture  # Before coding: generate baseline screenshots
rake screenshots:approve  # Move new screenshots to baseline directory
# ... make your code changes ...
rake screenshots:capture  # After coding: capture new screenshots
rake screenshots:report   # Compare and open side-by-side diff in browser
rake screenshots:clean    # Clean up after review (baselines are not committed)
```

## Visual Regression Testing (Screenshots)

When making UI changes, use screenshot checkpoints to verify visual changes are intentional:

1. **Before coding:** Generate baseline screenshots from current state:
   ```bash
   rake screenshots:capture
   rake screenshots:approve  # Moves new → baseline
   ```

2. **After coding:** Capture new screenshots and compare:
   ```bash
   rake screenshots:capture
   rake screenshots:report   # Opens side-by-side diff in browser
   ```

3. **Review the report** to ensure visual changes match your intentions

4. **Clean up** after review (baselines are not committed):
   ```bash
   rake screenshots:clean
   ```

**Note:** Baseline screenshots are ephemeral and not committed to git. They exist only during active development for comparison purposes.

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

### Viewport-Relative Units (vh)

Stage views are projected on shared screens (typically 1920x1080) and **must never scroll**. Use viewport-relative units (`vh`) instead of fixed pixel sizes (`px`, `rem`) for all spacing and text in stage views. Favor `vh` over `px` in other views when updating existing code.

**Custom Tailwind text utilities** are defined in `app/assets/tailwind/application.css` using `clamp()` for responsive scaling with min/max bounds:

| Class | Use for |
|-------|---------|
| `text-vh-xs` / `text-vh-sm` | Labels, metadata |
| `text-vh-base` / `text-vh-lg` | Body text |
| `text-vh-xl` / `text-vh-2xl` | Player names, answers |
| `text-vh-3xl` / `text-vh-4xl` | Headings, questions |
| `text-vh-5xl` | Large titles |

**Spacing** uses Tailwind arbitrary values: `p-[2vh]`, `mb-[3vh]`, `gap-[1vh]`, `h-[6vh]`, `w-[8vh]`, etc.

**Stage layout** (`app/views/stages/show.html.erb`): Fixed full-viewport flex container. Header is `shrink-0` (~12vh), content area is `flex-1` (~88vh). Do not add scrolling to the stage root.

```erb
<%# ✅ DO — vh-based sizing %>
<div class="bg-black/40 rounded-xl p-[2vh]">
  <h2 class="text-vh-4xl font-black"><%= question.body %></h2>
</div>

<%# ❌ DON'T — fixed pixel sizing in stage views %>
<div class="bg-black/40 rounded-xl p-6">
  <h2 class="text-4xl font-black"><%= question.body %></h2>
</div>
```

### Use Ruby/Rails Built-in Helpers

**Always prefer Ruby and Rails built-in methods over handrolling solutions.** Rails provides extensive helper methods that are tested, optimized, and idiomatic.

**Example - Ordinal Numbers:**
```ruby
# ❌ DON'T handroll a custom ordinal helper
def ordinal(number)
  suffix = case number % 100
  when 11, 12, 13 then "th"
  else
    case number % 10
    when 1 then "st"
    when 2 then "nd"
    when 3 then "rd"
    else "th"
    end
  end
  "#{number}#{suffix}"
end

# ✅ DO use Rails built-in
<%= rank.ordinalize %>  # "1st", "2nd", "3rd", etc.
```

**Other common built-ins to remember:**
- `pluralize(count, 'item')` - "1 item", "2 items"
- `truncate(text, length: 30)` - Smart text truncation
- `time_ago_in_words(time)` - "3 minutes ago"
- `number_to_currency(price)` - "$12.50"
- `number_with_delimiter(1000)` - "1,000"
- `titleize`, `humanize`, `parameterize` - String transformations

Before writing a helper, check if Rails already provides it in ActiveSupport or ActionView helpers.

## Important Notes

- **No Channels Directory**: Uses Turbo Streams directly, no custom Action Cable channels
- **Session-Based Auth**: Players identified by Rails session for reconnection, no accounts required
- **System Tests Are Critical**: Multiplayer flows must be tested with multiple Capybara sessions

### `GameHostAuthorization` — room-scoped player lookup

`authorize_host` in `app/controllers/concerns/game_host_authorization.rb` looks up the player directly via `@game.room.players.find_by(session_id:)`, **not** via `current_player`. This is intentional: `set_current_player` in `ApplicationController` requires `params[:code]` to scope its lookup; without it, it returns the first player with that `session_id` across all rooms, causing false authorization failures for players who joined via room code.

**When adding new game controllers** that include `GameHostAuthorization`: no extra work needed — the concern handles scoping itself.

**When adding host-action buttons in views**: still pass `params: { code: room.code }` as defense-in-depth (it keeps `set_current_player` correct for other before_actions that may rely on `current_player`).

## Pull Request Descriptions

Focus on what matters to a human reviewer. GitHub already shows file changes, so don't list them.

**Include:**
- **Why**: What problem does this solve? What's the context?
- **Decisions**: Non-obvious choices, tradeoffs, or things done intentionally
- **Reviewer notes**: What should they pay attention to? Any risks?
- **Configuration**: Environment variables or setup needed
- Attribution: "Co-authored with Claude" or similar necessary attribution

**Avoid:**
- Listing files added/modified (GitHub shows this)
- Restating the commit message
- Obvious observations ("added tests for new code")

## Documentation

See `docs/` directory for detailed guides on architecture, game logic, data models, and client architecture.

## In-Game Copy

All UI text (waiting states, success states, instructions, hints, button labels) should follow the copy voice guide:

> **[docs/copy-voice.md](docs/copy-voice.md)**

**Short version:** Warm + cheeky. Game show host who's rooting for the players. Not dry, not corporate, not trying to be Jackbox. Short sentences, active voice, affectionate but not overbearing.

## Self-Improvement Protocol

**When you receive a correction from the user, ask yourself: is this generalizable?**

A correction is generalizable if it reflects a recurring pattern — a preference, a project convention, an architectural rule, or a common mistake — that would apply to future work, not just the current task.

### If the correction IS generalizable:

1. **Update this file** (`CLAUDE.md`) — this is the primary durable store. It's in git, loaded in every session, and survives worktree creation/deletion.
2. **Commit it immediately** so future sessions inherit it:

```bash
git add CLAUDE.md
git commit -m "docs: add [topic] convention based on user correction"
```

**Generalizable** = a preference, convention, or recurring pattern that applies beyond the current task (architecture rules, style preferences, workflow habits). **Not generalizable** = task-specific mistakes (wrong variable name, missing test case, misread requirement) — skip those.

**Goal: low miss rate.** If you're corrected on something twice, the first correction should have been captured. A slightly redundant note is better than repeating an error.
