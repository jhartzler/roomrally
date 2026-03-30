# Skip Question Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow Speed Trivia hosts to skip upcoming questions during the reviewing state to shorten a game in progress.

**Architecture:** New service method increments `current_question_index` without entering `answering` state. New controller + route follow the existing host-action pattern (single-action controller with `GameHostAuthorization` + `RendersHand`). Host controls partial gets a secondary "Skip" button during reviewing. Three observability channels (Rails logger, PostHog, GameEvent) capture skip events.

**Tech Stack:** Rails, AASM, Turbo Streams, RSpec

**Spec:** `docs/superpowers/specs/2026-03-29-skip-question-design.md`

---

### Task 1: Service method — test and implement `skip_next_question`

**Files:**
- Modify: `app/services/games/speed_trivia.rb`
- Test: `spec/services/games/speed_trivia_spec.rb`

- [ ] **Step 1: Write the failing tests**

Add to `spec/services/games/speed_trivia_spec.rb`:

```ruby
describe '.skip_next_question' do
  let(:room) { create(:room, game_type: "Speed Trivia") }
  let(:pack) { create(:trivia_pack, :default) }
  let(:game) { create(:speed_trivia_game, status: "reviewing", current_question_index: 2) }

  before do
    create_list(:player, 3, room:)
    room.update!(current_game: game)
    5.times { |i| create(:trivia_question_instance, speed_trivia_game: game, position: i) }
    allow(GameBroadcaster).to receive(:broadcast_host_controls)
    allow(GameBroadcaster).to receive(:broadcast_hand)
  end

  it 'increments current_question_index' do
    expect { described_class.skip_next_question(game:) }
      .to change { game.reload.current_question_index }.from(2).to(3)
  end

  it 'stays in reviewing state' do
    described_class.skip_next_question(game:)
    expect(game.reload.status).to eq("reviewing")
  end

  it 'broadcasts host controls and hand' do
    described_class.skip_next_question(game:)
    expect(GameBroadcaster).to have_received(:broadcast_host_controls).with(room: game.room)
    expect(GameBroadcaster).to have_received(:broadcast_hand).with(room: game.room)
  end

  it 'does not broadcast stage' do
    allow(GameBroadcaster).to receive(:broadcast_stage)
    described_class.skip_next_question(game:)
    expect(GameBroadcaster).not_to have_received(:broadcast_stage)
  end

  it 'logs a GameEvent' do
    described_class.skip_next_question(game:)
    event = game.game_events.find_by(event_name: "question_skipped")
    expect(event).to be_present
    expect(event.metadata["question_index"]).to eq(3)
  end

  it 'tracks analytics' do
    allow(Analytics).to receive(:track)
    described_class.skip_next_question(game:)
    expect(Analytics).to have_received(:track).with(
      hash_including(event: "question_skipped")
    )
  end

  context 'when not in reviewing state' do
    before { game.update!(status: "answering") }

    it 'does nothing' do
      expect { described_class.skip_next_question(game:) }
        .not_to change { game.reload.current_question_index }
    end
  end

  context 'when no questions remaining' do
    before { game.update!(current_question_index: 4) }

    it 'does nothing' do
      expect { described_class.skip_next_question(game:) }
        .not_to change { game.reload.current_question_index }
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `TEST_ENV_NUMBER=2 bin/rspec spec/services/games/speed_trivia_spec.rb -e "skip_next_question" --format documentation`

Expected: FAIL — `NoMethodError: undefined method 'skip_next_question'`

- [ ] **Step 3: Implement `skip_next_question` in the service**

Add to `app/services/games/speed_trivia.rb`, after the `handle_timeout` method (before `start_timer_if_enabled`):

```ruby
def self.skip_next_question(game:)
  return unless game.reviewing?
  return unless game.questions_remaining?

  skipped_index = game.current_question_index + 1
  skipped_question = game.trivia_question_instances.find_by(position: skipped_index)

  game.with_lock { game.increment!(:current_question_index) }

  Rails.logger.info({
    event: "question_skipped",
    room_code: game.room.code,
    question_index: skipped_index,
    question_body: skipped_question&.body&.truncate(80)
  })

  Analytics.track(
    distinct_id: game.room.user_id ? "user_#{game.room.user_id}" : "room_#{game.room.code}",
    event: "question_skipped",
    properties: {
      game_type: game.room.game_type,
      room_code: game.room.code,
      question_index: skipped_index,
      questions_remaining: game.questions_remaining?
    }
  )

  GameEvent.log(game, "question_skipped",
    question_index: skipped_index,
    question_body: skipped_question&.body&.truncate(80))

  GameBroadcaster.broadcast_host_controls(room: game.room)
  GameBroadcaster.broadcast_hand(room: game.room)
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `TEST_ENV_NUMBER=2 bin/rspec spec/services/games/speed_trivia_spec.rb -e "skip_next_question" --format documentation`

Expected: all 7 examples pass

- [ ] **Step 5: Run rubocop**

Run: `rubocop app/services/games/speed_trivia.rb spec/services/games/speed_trivia_spec.rb -A`

- [ ] **Step 6: Commit**

```bash
git add app/services/games/speed_trivia.rb spec/services/games/speed_trivia_spec.rb
git commit -m "feat: add skip_next_question service method for Speed Trivia"
```

---

### Task 2: Controller and route

**Files:**
- Create: `app/controllers/speed_trivia/question_skips_controller.rb`
- Modify: `config/routes.rb`

- [ ] **Step 1: Create the controller**

Create `app/controllers/speed_trivia/question_skips_controller.rb`:

```ruby
module SpeedTrivia
  class QuestionSkipsController < ApplicationController
    include RendersHand
    include GameHostAuthorization

    before_action :set_game
    before_action :authorize_host

    def create
      Games::SpeedTrivia.skip_next_question(game: @game)

      render_hand
    end

    private

    def set_game
      @game = SpeedTriviaGame.find(params[:speed_trivia_game_id])
    end
  end
end
```

- [ ] **Step 2: Add the route**

In `config/routes.rb`, inside the `resources :speed_trivia_games` block, add `resource :question_skip, only: :create` alongside the existing resources:

```ruby
resources :speed_trivia_games, only: [] do
  scope module: :speed_trivia do
    resource :question, only: :create
    resource :round_closure, only: :create
    resource :advancement, only: :create
    resource :game_start, only: :create
    resource :question_skip, only: :create
  end
end
```

- [ ] **Step 3: Verify route exists**

Run: `bin/rails routes -g question_skip`

Expected output includes: `speed_trivia_game_question_skip POST /speed_trivia_games/:speed_trivia_game_id/question_skip`

- [ ] **Step 4: Run rubocop**

Run: `rubocop app/controllers/speed_trivia/question_skips_controller.rb config/routes.rb -A`

- [ ] **Step 5: Commit**

```bash
git add app/controllers/speed_trivia/question_skips_controller.rb config/routes.rb
git commit -m "feat: add question skip controller and route for Speed Trivia"
```

---

### Task 3: Host controls UI — skip button

**Files:**
- Modify: `app/views/games/speed_trivia/_host_controls.html.erb`

- [ ] **Step 1: Add the skip button to the reviewing state**

In `app/views/games/speed_trivia/_host_controls.html.erb`, in the `reviewing?` branch, after the "Next Question" button (and before the `else` for "Finish Game"), add the skip button. The full `reviewing?` block becomes:

```erb
<% elsif game.reviewing? %>
  <% current_q = game.current_question %>
  <div class="bg-white/5 rounded-xl p-4 mb-4">
    <p class="text-white font-medium mb-2"><%= current_q&.body %></p>
    <p class="text-green-400">Answer: <%= current_q&.correct_answers&.join(", ") %></p>
  </div>

  <% if game.questions_remaining? %>
    <%= button_to "Next Question",
        speed_trivia_game_advancement_path(game),
        method: :post,
        params: { code: room.code },
        data: { turbo_submits_with: "Loading…" },
        class: "w-full bg-gradient-to-r from-indigo-600 to-blue-600 hover:from-indigo-500 hover:to-blue-500 text-white font-bold py-3 px-6 rounded-xl transition duration-200 shadow-lg cursor-pointer border border-white/10" %>

    <% next_q = game.trivia_question_instances.find_by(position: game.current_question_index + 1) %>
    <div class="mt-3 text-center">
      <%= button_to "Skip Next Question",
          speed_trivia_game_question_skip_path(game),
          method: :post,
          params: { code: room.code },
          data: { turbo_submits_with: "Skipping…" },
          class: "text-sm text-gray-400 underline hover:text-gray-200 transition cursor-pointer" %>
      <p class="text-xs text-gray-500 mt-1 truncate">
        Up next: <%= next_q&.body&.truncate(60) %>
      </p>
    </div>
  <% else %>
    <%= button_to "Finish Game",
        speed_trivia_game_advancement_path(game),
        method: :post,
        params: { code: room.code },
        data: { turbo_submits_with: "Finishing…" },
        class: "w-full bg-gradient-to-r from-yellow-600 to-orange-600 hover:from-yellow-500 hover:to-orange-500 text-white font-bold py-3 px-6 rounded-xl transition duration-200 shadow-lg cursor-pointer border border-white/10" %>
  <% end %>
```

Note: also adding `params: { code: room.code }` to the existing "Next Question" and "Finish Game" buttons for defense-in-depth (per CLAUDE.md convention). These were missing before.

- [ ] **Step 2: Run rubocop on the view (ERB lint)**

Run: `rubocop app/views/games/speed_trivia/_host_controls.html.erb -A`

- [ ] **Step 3: Commit**

```bash
git add app/views/games/speed_trivia/_host_controls.html.erb
git commit -m "feat: add skip question button to Speed Trivia host controls"
```

---

### Task 4: SessionRecap formatting

**Files:**
- Modify: `app/services/session_recap.rb`
- Test: `spec/services/session_recap_spec.rb` (if it exists, otherwise inline verification)

- [ ] **Step 1: Check if SessionRecap has tests**

Run: `ls spec/services/session_recap_spec.rb 2>/dev/null || echo "no spec file"`

- [ ] **Step 2: Add the `question_skipped` case to `format_game_event`**

In `app/services/session_recap.rb`, update the `format_game_event` method:

```ruby
def format_game_event(ge)
  case ge.event_name
  when "state_changed"
    "State: #{ge.metadata["from"]} → #{ge.metadata["to"]}"
  when "game_created"
    "Game started (#{ge.metadata["game_type"]})"
  when "game_finished"
    "Game finished (#{ge.metadata["duration_seconds"]}s)"
  when "question_skipped"
    "Question #{ge.metadata["question_index"].to_i + 1} skipped"
  else
    ge.event_name.humanize
  end
end
```

Note: `+ 1` converts from 0-indexed to 1-indexed for human display.

- [ ] **Step 3: Run rubocop**

Run: `rubocop app/services/session_recap.rb -A`

- [ ] **Step 4: Commit**

```bash
git add app/services/session_recap.rb
git commit -m "feat: display question_skipped events in admin session timeline"
```

---

### Task 5: System spec — host skips a question

**Files:**
- Create: `spec/system/games/speed_trivia_skip_question_spec.rb`

- [ ] **Step 1: Write the system spec**

Create `spec/system/games/speed_trivia_skip_question_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe "Speed Trivia Skip Question", :js, type: :system do
  let!(:room) { FactoryBot.create(:room, game_type: "Speed Trivia", user: nil) }

  before do
    default_pack = FactoryBot.create(:trivia_pack, :default)
    5.times do |i|
      FactoryBot.create(:trivia_question,
        trivia_pack: default_pack,
        body: "Question #{i + 1} body?",
        correct_answers: ["Answer #{i + 1}"],
        options: ["Answer #{i + 1}", "Wrong A", "Wrong B", "Wrong C"])
    end
  end

  it "host skips a question and it is never shown to players" do
    # Host joins and claims host
    Capybara.using_session(:host) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Host"
      click_on "Join Game"
      expect(page).to have_content("Game Lobby")
      click_on "Claim Host"
      expect(page).to have_content("You're the host!")
    end

    # Player joins
    Capybara.using_session(:player1) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Alice"
      click_on "Join Game"
      expect(page).to have_content("The crowd is gathering...")
    end

    # Host starts game
    Capybara.using_session(:host) do
      expect(page).to have_button("Start Game", wait: 5)
      click_on "Start Game"
      expect(page).to have_selector("#start-from-instructions-btn", wait: 5)
      find("#start-from-instructions-btn").click
      expect(page).to have_button("Start First Question", wait: 5)
    end

    # Play through question 1: start, answer, close
    game = room.reload.current_game
    Games::SpeedTrivia.start_question(game:)

    Capybara.using_session(:host) do
      expect(page).to have_content("Question 1 body?", wait: 5)
    end

    # Stage shows question 1
    Capybara.using_session(:stage) do
      visit stage_path(room)
      expect(page).to have_content("Question 1 body?", wait: 5)
    end

    # Player answers
    Capybara.using_session(:player1) do
      expect(page).to have_content("Question 1 body?", wait: 5)
      first("button", text: /\A[A-D]\z/).click
    end

    # Close the round
    Games::SpeedTrivia.close_round(game: game.reload)

    # Host is now in reviewing state — should see skip button
    Capybara.using_session(:host) do
      expect(page).to have_content("Reviewing", wait: 5)
      expect(page).to have_button("Next Question", wait: 5)
      expect(page).to have_button("Skip Next Question")

      # Preview shows next question
      expect(page).to have_content("Up next:")
      expect(page).to have_content("Question 2 body?")

      # Skip question 2
      click_on "Skip Next Question"

      # Now preview shows question 3 (question 2 was skipped)
      expect(page).to have_content("Question 3 body?", wait: 5)
    end

    # Advance to the next question (should be question 3, not 2)
    game.reload
    Games::SpeedTrivia.next_question(game:)

    # Stage should show question 3, never question 2
    Capybara.using_session(:stage) do
      expect(page).to have_content("Question 3 body?", wait: 5)
      expect(page).not_to have_content("Question 2 body?")
    end

    # Verify question counter shows objective numbering (3 of 5)
    Capybara.using_session(:host) do
      expect(page).to have_content("Question 3 of 5", wait: 5)
    end
  end

  it "host skips multiple questions in a row" do
    # Host joins, claims host, starts game
    Capybara.using_session(:host) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Host"
      click_on "Join Game"
      click_on "Claim Host"
      expect(page).to have_button("Start Game", wait: 5)
      click_on "Start Game"
      expect(page).to have_selector("#start-from-instructions-btn", wait: 5)
      find("#start-from-instructions-btn").click
    end

    # Play through question 1
    game = room.reload.current_game
    Games::SpeedTrivia.start_question(game:)
    Games::SpeedTrivia.close_round(game: game.reload)

    # Skip questions 2, 3, and 4
    Capybara.using_session(:host) do
      expect(page).to have_button("Skip Next Question", wait: 5)
      click_on "Skip Next Question"
      expect(page).to have_content("Question 3 body?", wait: 5)

      click_on "Skip Next Question"
      expect(page).to have_content("Question 4 body?", wait: 5)

      click_on "Skip Next Question"
      expect(page).to have_content("Question 5 body?", wait: 5)

      # No more questions after 5 — skip button should be gone
      expect(page).not_to have_button("Skip Next Question")
      expect(page).to have_button("Next Question")
    end
  end

  it "skip button disappears when on the last question" do
    Capybara.using_session(:host) do
      visit join_room_path(room)
      fill_in "player[name]", with: "Host"
      click_on "Join Game"
      click_on "Claim Host"
      expect(page).to have_button("Start Game", wait: 5)
      click_on "Start Game"
      expect(page).to have_selector("#start-from-instructions-btn", wait: 5)
      find("#start-from-instructions-btn").click
    end

    # Fast-forward to the last question via service calls
    game = room.reload.current_game

    # Play questions 1-4
    4.times do
      Games::SpeedTrivia.start_question(game: game.reload)
      Games::SpeedTrivia.close_round(game: game.reload)
      Games::SpeedTrivia.next_question(game: game.reload) if game.reload.questions_remaining?
    end

    # Now on question 5 (last), close it
    Games::SpeedTrivia.close_round(game: game.reload) if game.reload.answering?

    Capybara.using_session(:host) do
      expect(page).to have_button("Finish Game", wait: 5)
      expect(page).not_to have_button("Skip Next Question")
    end
  end
end
```

- [ ] **Step 2: Run the system spec**

Run: `TEST_ENV_NUMBER=2 bin/rspec spec/system/games/speed_trivia_skip_question_spec.rb --format documentation`

Expected: all 3 examples pass

- [ ] **Step 3: Fix any failures and re-run**

If failures occur, diagnose from error output, fix, and re-run.

- [ ] **Step 4: Run rubocop**

Run: `rubocop spec/system/games/speed_trivia_skip_question_spec.rb -A`

- [ ] **Step 5: Commit**

```bash
git add spec/system/games/speed_trivia_skip_question_spec.rb
git commit -m "test: add system specs for Speed Trivia skip question feature"
```

---

### Task 6: Full test suite verification

- [ ] **Step 1: Run the full Speed Trivia test suite**

Run: `TEST_ENV_NUMBER=2 bin/rspec spec/services/games/speed_trivia_spec.rb spec/system/games/speed_trivia_happy_path_spec.rb spec/system/games/speed_trivia_skip_question_spec.rb --format documentation`

Expected: all examples pass, no regressions

- [ ] **Step 2: Run rubocop on all changed files**

Run: `rubocop -A`

- [ ] **Step 3: Run brakeman**

Run: `brakeman -q`

Expected: no new warnings

- [ ] **Step 4: Fix any issues and commit if needed**
