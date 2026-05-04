---
name: multiplayer-spec
description: Use when writing system specs for multiplayer game flows, testing real-time broadcasts, or creating end-to-end game tests with multiple Capybara sessions. Trigger on flaky spec debugging, timing issues, or multi-player test setup.
---

# Multiplayer System Spec Writer

Generates system spec skeletons for RoomRally multiplayer flows with proper timing gates, multi-session patterns, and known gotcha avoidance.

## Arguments

- **`<description>`**: Description of the flow to test (e.g., "host starts Speed Trivia, 3 players answer, scores shown")
- **No arguments**: Ask what game flow to test

## Spec Skeleton

```ruby
RSpec.describe "YourGame Happy Path", :js, type: :system do
  let!(:room) { FactoryBot.create(:room, game_type: "Game Type", user: nil) }

  before do
    # Set up seed data (packs, questions, prompts, etc.)
  end

  it "describes the full flow being tested" do
    # === PHASE 1: Join ===
    Capybara.using_session(:host) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Host"
      click_on "Join Game"
      expect(page).to have_content("Game Lobby")
      click_on "Claim Host"
      expect(page).to have_content("You're the host!")
    end

    Capybara.using_session(:player2) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Alice"
      click_on "Join Game"
      expect(page).to have_content("The crowd is gathering...")
    end

    Capybara.using_session(:player3) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Bob"
      click_on "Join Game"
      expect(page).to have_content("The crowd is gathering...")
    end

    # === PHASE 2: Start Game ===
    Capybara.using_session(:host) do
      expect(page).to have_button("Start Game", wait: 5)
      click_on "Start Game"
      # Wait for instructions screen
      expect(page).to have_selector("#start-from-instructions-btn", wait: 5)
      find("#start-from-instructions-btn").click
    end

    # === TIMING GATE: Wait for all players to reach game state ===
    [:player2, :player3].each do |session|
      Capybara.using_session(session) do
        expect(page).to have_content("Expected game content", wait: 5)
      end
    end

    # === PHASE 3: Game Actions ===
    game = room.reload.current_game

    # Option A: Service method call (faster, bypasses JS)
    Games::YourGame.some_action(game:)

    # Option B: UI interaction (tests JS behavior)
    Capybara.using_session(:player2) do
      click_button "Submit"
      expect(page).to have_content("Submitted!", wait: 5)
    end

    # === PHASE 4: Verify Final State ===
    [:host, :player2, :player3].each do |session|
      Capybara.using_session(session) do
        expect(page).to have_content(/game over/i, wait: 5)
      end
    end
  end
end
```

## Core Patterns

### 1. Timing Gates

**Always confirm host state transition before switching to player sessions.** Broadcasts are asynchronous — if you check player sessions before the host transition completes, the broadcast hasn't fired yet.

```ruby
# CORRECT: Host triggers transition, wait for it, THEN check players
Capybara.using_session(:host) do
  click_on "Start First Question"
  expect(page).to have_content(/question 1/i, wait: 5)  # Gate!
end

[:player2, :player3].each do |session|
  Capybara.using_session(session) do
    expect(page).to have_content(/question 1/i, wait: 5)
  end
end

# WRONG: Check players immediately after service call
Games::SpeedTrivia.start_question(game:)
Capybara.using_session(:player2) do
  expect(page).to have_content("Question 1")  # May fail — broadcast not delivered yet
end
```

### 2. Service Method Calls vs UI Clicks

**Use service methods** to advance game state quickly (skips UI interaction):
```ruby
game = room.reload.current_game
Games::SpeedTrivia.close_round(game: game.reload)
```

**Use UI clicks** when testing JS behavior (Stimulus controllers, form submission, disabled buttons):
```ruby
Capybara.using_session(:player2) do
  expect { click_button "Vote for this answer", match: :first }
    .to change(Vote, :count).by(1)
end
```

**Playtest `bot_act` bypasses JS entirely** — it calls service methods directly. Never rely on it to catch JS bugs.

### 3. Broadcast Recovery (Missed Broadcasts)

Sometimes broadcasts arrive before the session is listening. Use the visit-and-retry pattern:

```ruby
Capybara.using_session(session) do
  unless page.has_content?("Expected text", wait: 5)
    visit current_path  # Force refresh
  end
  expect(page).to have_content("Expected text", wait: 5)
end
```

### 4. Radio Buttons (Peer-Hidden Pattern)

Game template forms use `class="peer hidden"` on radio inputs. Click the label, assert with `visible: false`:

```ruby
# Click the wrapping label by display text
find('label', text: 'Think Fast').click

# Assert checked state (radio is hidden)
expect(find('input[type=radio][value="Speed Trivia"]', visible: false)).to be_checked
```

**Display names:** Comedy Clash = "Write And Vote", Think Fast = "Speed Trivia", A-List = "Category List"

### 5. Room & Player Setup

```ruby
# FactoryBot (preferred)
let!(:room) { FactoryBot.create(:room, game_type: "Speed Trivia", user: nil) }

# Fast setup via service calls (skip UI for setup phases)
before do
  default_pack = create(:trivia_pack, :default)
  # ... create questions/prompts
  Games::SpeedTrivia.game_started(room: room.reload, show_instructions: false, timer_enabled: false)
end

# Set player session directly (for testing specific player roles)
visit set_player_session_path(player)
```

### 6. Worktree Database Isolation

When running specs in a worktree, use `TEST_ENV_NUMBER` to avoid deadlocks with other sessions:

```bash
TEST_ENV_NUMBER=2 bin/rails db:test:prepare   # One-time setup
TEST_ENV_NUMBER=2 bin/rspec spec/system/games/ # Run isolated
```

Pick a unique number per worktree.

## Common Assertions

```ruby
# Content-based waits (most reliable)
expect(page).to have_content("Game Lobby", wait: 5)
expect(page).to have_button("Start Game", wait: 5)

# Selector-based waits
expect(page).to have_selector('[data-test-id^="answer-option"]', minimum: 4)
expect(page).to have_css("[data-controller='score-tally']", wait: 5)

# Either/or state
expect(page).to have_content("Correct!", wait: 5).or have_content("Not quite.", wait: 5)

# Count changes
expect { click_button "Submit" }.to change(Vote, :count).by(1)

# Data attribute extraction
el = find("[data-controller='score-tally']")
from_value = el["data-score-tally-from-value"].to_i
```

## Gotchas

| Gotcha | Why | Fix |
|--------|-----|-----|
| Flaky broadcast assertions | WebSocket delivery is async | Use `wait: 5` on all `expect` and add visit-and-retry fallback |
| `bot_act` misses JS bugs | It calls service methods, not browser clicks | Write UI click tests for any action with Stimulus controllers |
| Action Cable not subscribed | Broadcasts fire before page is fully loaded | Visit page first, wait for initial content, THEN trigger transitions |
| Radio input not found | Peer-hidden pattern hides the input | Use `visible: false` for assertions, click the label for interaction |
| `current_player` scoping | Session ID shared across rooms | Always pass `code: room.code` in form params |
| Database deadlocks in worktrees | Shared test DB across worktrees | Use `TEST_ENV_NUMBER=N` |
