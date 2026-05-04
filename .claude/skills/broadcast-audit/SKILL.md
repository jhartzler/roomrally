---
name: broadcast-audit
description: Use when implementing or modifying game service broadcasting logic, after adding broadcast targets in views, or during architecture review. Trigger on broadcast bugs, missing updates, race conditions in state transitions, or stale UI after game actions.
---

# Broadcasting Consistency Checker

Audits a game service module for concurrency safety, broadcast architecture, and view target placement. These three categories are the top recurring bug sources in RoomRally.

## Arguments

- **`<module name>`**: e.g., `Games::SpeedTrivia` — audit that specific module
- **No arguments**: Audit all game services in `app/services/games/`

## Audit Checklist

### 1. Concurrency Safety

Check every method that modifies game state:

**Rule: All check-then-modify operations must be wrapped in `game.with_lock { }`.**

```ruby
# CORRECT
def self.submit_answer(game:, player:, selected_option:)
  game.with_lock do
    return unless game.answering?
    # ... create answer, check if all submitted ...
    game.close_round! if game.all_answers_submitted?
  end
  broadcast_all(game)
end

# WRONG: No lock — race condition if two players submit simultaneously
def self.submit_answer(game:, player:, selected_option:)
  return unless game.answering?
  # ... create answer ...
  game.close_round! if game.all_answers_submitted?
  broadcast_all(game)
end
```

**What to grep for:**

```bash
# Find state transition calls without surrounding with_lock
grep -n '\.start_game!\|\.close_round!\|\.finish_game!\|\.begin_review!\|\.start_voting!' app/services/games/*.rb

# For each hit, verify it's inside a with_lock block
```

**Known violations (from backlog RMRL-43):**
- `start_from_instructions()` in all three game services — calls `game.start_game!` without lock
- `CategoryList.handle_timeout()` — no lock
- `CategoryList.show_scores()` — no lock

**Rule: No broadcasts inside `with_lock` blocks.**

```ruby
# CORRECT
game.with_lock do
  game.close_round!
  score_current_round(game)
end
broadcast_all(game)  # Outside lock

# WRONG: Broadcast inside lock increases contention
game.with_lock do
  game.close_round!
  broadcast_all(game)  # Holds lock during I/O
end
```

**Rule: Use `find_or_create_by!` with unique index instead of check-then-create.**

```ruby
# CORRECT
CategoryAnswer.find_or_create_by!(player:, category_instance: ci) do |answer|
  answer.body = text
end

# WRONG: Race condition between check and create
unless CategoryAnswer.exists?(player:, category_instance: ci)
  CategoryAnswer.create!(player:, category_instance: ci, body: text)
end
```

### 2. Broadcast Architecture

**Rule: Single `broadcast_all` private method as the only exit point.**

```bash
# Count broadcast calls outside broadcast_all — should be zero (except game_started)
grep -n 'GameBroadcaster\.' app/services/games/<module>.rb
```

Expected pattern:
- `game_started` calls `GameBroadcaster.broadcast_game_start`, `broadcast_stage`, `broadcast_hand` directly (initial setup)
- ALL other methods call only `broadcast_all(game)`
- `broadcast_all` is `private_class_method`

```ruby
# CORRECT
def self.broadcast_all(game)
  room = game.room
  GameBroadcaster.broadcast_stage(room:)
  GameBroadcaster.broadcast_hand(room:)
  GameBroadcaster.broadcast_host_controls(room:)
end
private_class_method :broadcast_all

# WRONG: Scattered broadcasts
def self.close_round(game:)
  game.with_lock { game.close_round! }
  GameBroadcaster.broadcast_stage(room: game.room)  # Forgot hand + host_controls
end
```

**Rule: `broadcast_all` must call all three broadcaster methods.**

Check that every `broadcast_all` includes:
- `GameBroadcaster.broadcast_stage(room:)`
- `GameBroadcaster.broadcast_hand(room:)`
- `GameBroadcaster.broadcast_host_controls(room:)`

Missing any one means that UI won't update for that surface (stage display, player phones, or host controls).

### 3. View Target Placement

**Rule: Broadcast targets must be nested inside the container that gets replaced.**

The broadcaster replaces these targets:
- `stage_content` — replaced by `broadcast_stage` (renders `_stage_<status>.html.erb`)
- `hand_screen` — replaced by `broadcast_hand` (renders game's `_hand.html.erb`)
- `backstage-host-controls` — replaced by `broadcast_host_controls`

**What to check:**

```bash
# Find all turbo stream targets in game views
grep -rn 'id="stage_\|id="hand_\|id="backstage' app/views/games/<module>/

# Verify each target is a CHILD of (not a SIBLING of) the replaced container
```

**Common bug:** A curation panel or extra controls placed as a sibling of `backstage-host-controls` instead of nested inside it. The broadcast replaces the container, so sibling elements never get updated.

## Running the Audit

For a specific module:

```bash
# Step 1: Find all state transitions
grep -n '!$\|_game!\|_round!\|_review!\|_voting!' app/services/games/<module>.rb

# Step 2: Verify each is inside with_lock
grep -B5 -A5 'with_lock' app/services/games/<module>.rb

# Step 3: Verify no broadcasts inside locks
grep -A20 'with_lock' app/services/games/<module>.rb | grep 'GameBroadcaster\|broadcast_all'

# Step 4: Count broadcast exit points (should be 1 private method + game_started)
grep -c 'GameBroadcaster\|broadcast_all' app/services/games/<module>.rb

# Step 5: Check broadcast_all completeness
grep -A5 'def self.broadcast_all' app/services/games/<module>.rb
```

## Output Format

Report findings as a pass/fail checklist:

```
## Audit: Games::SpeedTrivia

### Concurrency
- [x] submit_answer: with_lock wraps state check + transition (line 45)
- [x] close_round: with_lock wraps close_round! + scoring (line 67)
- [ ] start_from_instructions: NO LOCK around start_game! (line 23) ← FIX
- [x] No broadcasts inside lock blocks

### Broadcast Architecture
- [x] broadcast_all is private_class_method
- [x] broadcast_all calls stage, hand, host_controls
- [x] Only game_started has direct GameBroadcaster calls
- [ ] next_question calls GameBroadcaster.broadcast_stage directly (line 89) ← FIX

### View Targets
- [x] _stage_answering: id="stage_answering" is first child
- [x] _stage_reviewing: id="stage_reviewing" is first child
- [ ] _hand_voting: vote form target outside #hand_screen ← FIX
```

## When to Run

- After implementing a new game service
- After modifying any game service method that changes state
- After adding/moving broadcast targets in view partials
- During architecture review or before major releases
- When debugging "UI not updating" bugs
