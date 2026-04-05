---
name: new-game
description: Use when adding a new game type, creating a game mode, or building a new game for RoomRally. Trigger on mentions of new games, game scaffolding, or game type creation.
---

# New Game Type Scaffold & Guide

Interactive walkthrough for adding a new game type to RoomRally. Follows the checklist in CLAUDE.md and enforces all conventions that have caused bugs in past game implementations.

## Arguments

- **No arguments**: Ask for game name, key mechanics, AASM states, and timer strategy
- **`<game name>`**: Start the walkthrough with that game name

## Before You Start

1. Ask the user for:
   - **Game name** (internal, e.g., "Scavenger Hunt") and **display name** (player-facing, e.g., "Photo Dash")
   - **Key mechanics** (what players do each round)
   - **AASM states** (must include `instructions` -> playing states -> `finished`)
   - **Timer strategy**: global timer (one per round) or per-phase timers (different durations per state)
   - **Capacity check**: does this game require 3+ players? (`requires_capacity_check?`)

2. Create a feature branch: `feature/<game-name-kebab>`

## Walkthrough Steps

Work through each step sequentially. Run system specs at each checkpoint marked with `[CHECKPOINT]`.

### Step 1: Model

Create `app/models/<snake_case>_game.rb`:

```ruby
class SnakeCaseGame < ApplicationRecord
  include AASM
  include HasRoundTimer

  belongs_to :room

  aasm column: :status, whiny_transitions: false do
    state :instructions, initial: true
    # ... playing states ...
    state :finished

    # Every event needs transitions defined
  end

  def process_timeout(round_number, step_number)
    # Guard: return unless current state matches expected round/step
    # Delegate to Games::YourGame.handle_timeout(game: self)
  end
end
```

Create migration with `bin/rails generate model`.

**Conventions:**
- AASM column is `status` (string), not `state`
- Always include `whiny_transitions: false`
- `process_timeout` guards against stale timer jobs before delegating

### Step 2: Service Module

Create `app/services/games/<snake_case>.rb`:

```ruby
module Games
  module YourGame
    def self.requires_capacity_check? = false

    def self.game_started(room:, timer_enabled:, timer_increment:, show_instructions:, **_extra)
      game = YourGameGame.create!(room:, ...)
      room.update!(current_game: game)
      GameEvent.log(game, "game_created", ...)
      GameBroadcaster.broadcast_game_start(room:)
      GameBroadcaster.broadcast_stage(room:)
      GameBroadcaster.broadcast_hand(room:)
    end

    def self.start_from_instructions(game:)
      game.with_lock { game.start_game! }
      broadcast_all(game)
    end

    def self.handle_timeout(game:)
      # Handle timer expiration for the current phase
    end

    # === Private ===

    def self.broadcast_all(game)
      room = game.room
      GameBroadcaster.broadcast_stage(room:)
      GameBroadcaster.broadcast_hand(room:)
      GameBroadcaster.broadcast_host_controls(room:)
    end
    private_class_method :broadcast_all

    # --- Playtest module (MUST be nested here, not a separate file) ---
    module Playtest
      def self.start(room:)
        Games::YourGame.game_started(room:, show_instructions: true, timer_enabled: false)
      end

      def self.advance(game:)
        case game.status
        when "instructions" then Games::YourGame.start_from_instructions(game:)
        # ... other states
        end
      end

      def self.bot_act(game:, exclude_player:)
        # Submit bot actions for current state
      end

      def self.auto_play_step(game:)
        # Combine advance + bot_act for auto-play
      end

      def self.progress_label(game:)
        # Return progress text for dev dashboard
      end

      def self.dashboard_actions(status)
        # Return array of { label:, action:, style: } hashes
      end
    end
  end
end
```

**Critical conventions:**
- `broadcast_all` is the SINGLE exit point for broadcasts. Never scatter `GameBroadcaster` calls.
- `with_lock` wraps state-modifying operations. Broadcasts happen OUTSIDE the lock.
- Accept `**_extra` in `game_started` to absorb params meant for other game types.
- Playtest module is nested inside the service file, not a separate file.

### Step 3: Controller

Create `app/controllers/<snake_case>/game_starts_controller.rb`:

```ruby
module YourGame
  class GameStartsController < ApplicationController
    include GameHostAuthorization
    include RendersHand

    before_action :set_game
    before_action :authorize_host

    def create
      Games::YourGame.start_from_instructions(game: @game)
      render_hand
    end

    private

    def set_game
      @game = YourGameGame.find(params[:<snake_case>_game_id])
    end
  end
end
```

**Conventions:**
- Always include `GameHostAuthorization` (never reimplement auth)
- Always include `RendersHand` and call `render_hand` (never `head :no_content`)
- Any additional game action controllers follow the same pattern

### Step 4: Routes

Add to `config/routes.rb`:

```ruby
resources :<snake_case>_games, only: [] do
  resource :game_start, only: [:create], module: :<snake_case>
  # ... other nested resources for game actions
end
```

### Step 5: Registry

Update `config/initializers/game_registry.rb`:

```ruby
GameEventRouter.register_game("Your Game Name", Games::YourGame)
DevPlaytest::Registry.register(YourGameGame, Games::YourGame::Playtest)
```

### Step 6: Room Constants

Update `app/models/room.rb`:

```ruby
YOUR_GAME = "Your Game Name".freeze
# Add to GAME_TYPES array
GAME_TYPES = [ WRITE_AND_VOTE, SPEED_TRIVIA, CATEGORY_LIST, YOUR_GAME ].freeze
# Add display name
GAME_DISPLAY_NAMES = {
  # ... existing ...
  YOUR_GAME => "Display Name"
}.freeze
```

### Step 7: Stage Partials `[CHECKPOINT]`

Create `app/views/games/<snake_case>/` with `_stage_<status>.html.erb` for every AASM state.

**CRITICAL - invoke `/stage-view` skill for stage partial conventions.** Key rules:
- First child element: `<div id="stage_<status>">` (NOT `<link>` tags)
- All sizing in vh units: `text-vh-*`, `p-[2vh]`, `gap-[1vh]`
- No scrolling on stage root
- No inline animations (use `stage-transition` controller via the `id="stage_*"` convention)

Run specs after creating all stage partials.

### Step 8: Hand Partials `[CHECKPOINT]`

Create hand partials:
- `_hand.html.erb` — router partial that switches on `game.status`
- `_game_over.html.erb` — end-of-game screen
- Phase-specific partials (e.g., `_answer_form.html.erb`, `_waiting.html.erb`)

**Conventions:**
- Router uses `<%= render "games/<snake_case>/..." %>` for each phase
- Instructions phase renders shared partial: `render "games/shared/hand_instructions"`
- All forms inside `#hand_screen` turbo-frame
- Pass `code: room.code` in all host-action form params (defense-in-depth)

### Step 9: System Specs `[CHECKPOINT]`

**Invoke `/multiplayer-spec` skill** to generate a multiplayer system spec skeleton.

At minimum, test:
- Host creates room, players join, host starts game
- Full game flow through all AASM states
- Game over / finished state displays correctly

### Step 10: Final Verification

- [ ] `bin/rspec` passes
- [ ] `rubocop -A` passes
- [ ] `brakeman -q` passes
- [ ] All AASM states have stage partials
- [ ] All hand routes render correctly
- [ ] Registry entries are correct
- [ ] Room constants are updated
- [ ] Playtest module works in dev dashboard

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Scattered `GameBroadcaster` calls | Route all through `broadcast_all` private method |
| Broadcasts inside `with_lock` | Move broadcasts outside the lock block |
| Missing `code: room.code` in forms | Add to all host-action form params |
| Stage partial starts with `<link>` | First child must be `<div id="stage_*">` |
| Playtest in separate file | Must be nested module inside the service file |
| `head :no_content` in controllers | Use `render_hand` from `RendersHand` concern |
| Fixed pixel sizing in stage views | Use `text-vh-*` and `p-[Xvh]` |
| Missing `whiny_transitions: false` | Always include in AASM block |
| `start_from_instructions` without lock | Wrap in `game.with_lock { }` |
