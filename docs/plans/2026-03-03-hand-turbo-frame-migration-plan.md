# Hand Screen Turbo Frame Migration — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Convert `#hand_screen` from a plain `<div>` to a `<turbo-frame>` so player form submissions update the hand from the HTTP response directly, eliminating the WebSocket broadcast round-trip for the submitting player.

**Architecture:** A `RendersHand` concern provides a zero-argument `render_hand` helper that resolves room and player from controller instance variables, then responds with `turbo_stream.update("hand_screen", ...)` — the same mechanism used by the WebSocket broadcaster, but delivered over HTTP. All 13 in-scope controllers include this concern and replace `head :no_content` with `render_hand`. The `<div id="hand_screen">` in `hands/show.html.erb` becomes `<turbo-frame id="hand_screen">`.

**Tech Stack:** Rails 8, Hotwire/Turbo (`turbo_stream` helper, `turbo_stream.update`), RSpec request specs + system specs (Capybara/Playwright)

**Design doc:** `docs/plans/2026-02-27-hand-screen-turbo-frame-migration.md`

**Important note on response format:** Use `turbo_stream.update` — NOT bare `render partial:` — inside `format.turbo_stream` blocks. A bare `render partial:` sends raw HTML with `Content-Type: text/vnd.turbo-stream.html`, but Turbo expects `<turbo-stream action="...">` wrapper elements in that content type. Without the wrapper, Turbo silently ignores the response. `turbo_stream.update` generates the correct wrapper automatically.

---

### Task 1: Write the failing request spec

Write a request spec that asserts `POST /trivia_answers` returns HTTP 200 with `#hand_screen` content in the body. This will fail right now (currently returns 204) and drives the concern implementation.

**Files:**
- Create: `spec/requests/trivia_answers_spec.rb`

**Step 1: Write the spec**

```ruby
# spec/requests/trivia_answers_spec.rb
require "rails_helper"

RSpec.describe "TriviaAnswers", type: :request do
  describe "POST /trivia_answers (turbo_stream) — renders hand after answer" do
    let(:room) { create(:room, game_type: "Speed Trivia") }
    let(:player) { create(:player, room:) }
    let(:trivia_pack) { create(:trivia_pack) }
    let(:game) do
      g = create(:speed_trivia_game, status: "answering", trivia_pack:)
      room.update!(current_game: g)
      g
    end
    let!(:question_instance) { create(:trivia_question_instance, speed_trivia_game: game, position: 0) }

    before do
      # Set player session (see spec/requests/votes_spec.rb for pattern)
      get set_player_session_path(player)
    end

    it "returns 200 with hand screen content" do
      post trivia_answers_path,
           params: { trivia_answer: { selected_option: "A" } },
           as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("hand_screen")
    end
  end
end
```

**Step 2: Run to verify it fails**

```bash
bin/rspec spec/requests/trivia_answers_spec.rb -f documentation
```

Expected: FAIL — `expected 200 but got 204`

---

### Task 2: Create the RendersHand concern

**Files:**
- Create: `app/controllers/concerns/renders_hand.rb`

**Step 1: Write the concern**

```ruby
# app/controllers/concerns/renders_hand.rb
module RendersHand
  def render_hand
    room = (@game&.room || @room || current_player&.room)&.reload
    player = current_player

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "hand_screen",
          partial: "rooms/hand_screen_content",
          locals: { room:, player: }
        )
      end
      format.html { redirect_to room_hand_path(room) }
    end
  end
end
```

---

### Task 3: Update TriviaAnswersController, run the spec

**Files:**
- Modify: `app/controllers/trivia_answers_controller.rb`

**Step 1: Include the concern and replace the respond_to block**

Replace:
```ruby
respond_to do |format|
  format.turbo_stream { head :no_content }
  format.html { redirect_to room_hand_path(@game.room) }
end
```

With:
```ruby
include RendersHand  # add at top of class
# ...
render_hand
```

Full updated `create` action (happy path):
```ruby
class TriviaAnswersController < ApplicationController
  include RendersHand
  # ... existing before_actions ...

  def create
    unless @game.answering?
      head :unprocessable_content
      return
    end

    selected_option = trivia_answer_params[:selected_option]

    answer = Games::SpeedTrivia.submit_answer(
      game: @game,
      player: current_player,
      selected_option:
    )

    if answer.persisted?
      render_hand
    else
      head :unprocessable_content
    end
  end
  # ... rest unchanged ...
end
```

**Step 2: Run the spec**

```bash
bin/rspec spec/requests/trivia_answers_spec.rb -f documentation
```

Expected: PASS

**Step 3: Run system specs to catch regressions**

```bash
bin/rspec spec/system/games/speed_trivia_spec.rb
```

Expected: all green

**Step 4: Commit**

```bash
git add app/controllers/concerns/renders_hand.rb \
        app/controllers/trivia_answers_controller.rb \
        spec/requests/trivia_answers_spec.rb
git commit -m "feat: add RendersHand concern, update TriviaAnswersController"
```

---

### Task 4: Convert hand_screen div to turbo-frame + fix hand_instructions

These two changes go together — the div conversion is one line, and removing `turbo: false` from hand_instructions is what makes it work correctly with the frame.

**Files:**
- Modify: `app/views/hands/show.html.erb:24`
- Modify: `app/views/games/shared/_hand_instructions.html.erb:12`

**Step 1: Convert the div**

In `app/views/hands/show.html.erb`, change:
```erb
<div id="hand_screen" class="w-full">
```
to:
```erb
<turbo-frame id="hand_screen" class="w-full">
```

And the closing tag from `</div>` to `</turbo-frame>`.

**Step 2: Remove `data: { turbo: false }` from the Start Game button**

In `app/views/games/shared/_hand_instructions.html.erb`, the `button_to` currently has `data: { turbo: false }`. Remove that key entirely. The button should look like:

```erb
<%= button_to "Start Game",
    start_game_path,
    method: :post,
    params: { code: room.code },
    id: "start-from-instructions-btn",
    class: "w-full bg-gradient-to-r from-green-600 to-emerald-600 text-white font-bold py-4 px-6 rounded-xl hover:from-green-700 hover:to-emerald-700 transform hover:scale-105 transition-all duration-200 shadow-lg text-lg cursor-pointer" %>
```

**Step 3: Run a broad system spec smoke test**

```bash
bin/rspec spec/system
```

Expected: all green (turbo-frame is transparent to existing specs)

**Step 4: Commit**

```bash
git add app/views/hands/show.html.erb \
        app/views/games/shared/_hand_instructions.html.erb
git commit -m "feat: convert hand_screen div to turbo-frame, remove turbo:false from hand_instructions"
```

---

### Task 5: Update VotesController

**Files:**
- Modify: `app/controllers/votes_controller.rb`

**Step 1: Include concern and replace respond_to block**

Add `include RendersHand` at the top of the class. In the `create` action, replace:

```ruby
respond_to do |format|
  format.turbo_stream { head :no_content }
end
```

With:
```ruby
render_hand
```

Note: `VotesController` has no `@game` instance variable — the concern correctly falls back to `current_player&.room` for the room.

**Step 2: Run existing votes request spec**

```bash
bin/rspec spec/requests/votes_spec.rb -f documentation
```

The existing "casts the vote successfully" test asserts `have_http_status(:no_content)` — update it to `have_http_status(:ok)`:

```ruby
expect(response).to have_http_status(:ok)
```

Run again — expected: all pass.

**Step 3: Run Write & Vote system specs**

```bash
bin/rspec spec/system/games/write_and_vote_spec.rb
```

Expected: all green

**Step 4: Commit**

```bash
git add app/controllers/votes_controller.rb \
        spec/requests/votes_spec.rb
git commit -m "feat: update VotesController to render hand via RendersHand concern"
```

---

### Task 6: Update CategoryList::SubmissionsController

**Files:**
- Modify: `app/controllers/category_list/submissions_controller.rb`

**Step 1: Include concern and replace respond_to block**

Add `include RendersHand` to the class. Replace:
```ruby
respond_to do |format|
  format.turbo_stream { head :no_content }
  format.html { redirect_to room_hand_path(@game.room) }
end
```

With:
```ruby
render_hand
```

**Step 2: Run Category List system specs**

```bash
bin/rspec spec/system/games/category_list_spec.rb
```

Expected: all green

**Step 3: Commit**

```bash
git add app/controllers/category_list/submissions_controller.rb
git commit -m "feat: update CategoryList::SubmissionsController to render hand"
```

---

### Task 7: Update SpeedTrivia host-action controllers

Four controllers: `GameStartsController`, `AdvancementsController`, `QuestionsController`, `RoundClosuresController`. All follow the same pattern. `SpeedTrivia::ScoreRevealsController` is dead code — skip it.

**Files:**
- Modify: `app/controllers/speed_trivia/game_starts_controller.rb`
- Modify: `app/controllers/speed_trivia/advancements_controller.rb`
- Modify: `app/controllers/speed_trivia/questions_controller.rb`
- Modify: `app/controllers/speed_trivia/round_closures_controller.rb`

**Step 1: For each controller, include concern and replace respond_to**

Pattern (same for all four — adjust action name/method as needed):

```ruby
include RendersHand

def create  # or the relevant action
  # ... existing game logic ...
  render_hand
end
```

Replace the full `respond_to` block (including the `format.html` branch) with `render_hand`.

**Step 2: Run Speed Trivia system specs**

```bash
bin/rspec spec/system/games/speed_trivia_spec.rb
```

Expected: all green

**Step 3: Commit**

```bash
git add app/controllers/speed_trivia/game_starts_controller.rb \
        app/controllers/speed_trivia/advancements_controller.rb \
        app/controllers/speed_trivia/questions_controller.rb \
        app/controllers/speed_trivia/round_closures_controller.rb
git commit -m "feat: update SpeedTrivia host-action controllers to render hand"
```

---

### Task 8: Update CategoryList host-action controllers

Five controllers: `GameStartsController`, `RoundsController`, `ReviewsController`, `ReviewNavigationsController`, `StageScoresController`.

Note: `ReviewsController`, `ReviewNavigationsController`, and `StageScoresController` use `#update` actions (PATCH), not `#create`.

**Files:**
- Modify: `app/controllers/category_list/game_starts_controller.rb`
- Modify: `app/controllers/category_list/rounds_controller.rb`
- Modify: `app/controllers/category_list/reviews_controller.rb`
- Modify: `app/controllers/category_list/review_navigations_controller.rb`
- Modify: `app/controllers/category_list/stage_scores_controller.rb`

**Step 1: For each controller, include concern and replace respond_to**

Same pattern as Task 7 — `include RendersHand` at top, replace the `respond_to` block with `render_hand`.

**Step 2: Run Category List system specs**

```bash
bin/rspec spec/system/games/category_list_spec.rb
```

Expected: all green

**Step 3: Commit**

```bash
git add app/controllers/category_list/game_starts_controller.rb \
        app/controllers/category_list/rounds_controller.rb \
        app/controllers/category_list/reviews_controller.rb \
        app/controllers/category_list/review_navigations_controller.rb \
        app/controllers/category_list/stage_scores_controller.rb
git commit -m "feat: update CategoryList host-action controllers to render hand"
```

---

### Task 9: Update WriteAndVote::GameStartsController

**Files:**
- Modify: `app/controllers/write_and_vote/game_starts_controller.rb`

**Step 1: Include concern and replace respond_to**

Same pattern — `include RendersHand`, replace `respond_to` block with `render_hand`.

**Step 2: Run Write & Vote system specs**

```bash
bin/rspec spec/system/games/write_and_vote_spec.rb
```

Expected: all green

**Step 3: Commit**

```bash
git add app/controllers/write_and_vote/game_starts_controller.rb
git commit -m "feat: update WriteAndVote::GameStartsController to render hand"
```

---

### Task 10: Full system spec run + rubocop

**Step 1: Run all system specs**

```bash
bin/rspec spec/system
```

Expected: all green. If anything fails, fix before proceeding.

**Step 2: Run rubocop**

```bash
rubocop -A
```

If rubocop modifies any files:
```bash
git add -u && git commit -m "style: rubocop auto-fixes"
```

---

### Task 11: Add regression system spec for frame update behavior

Add one spec per game type that verifies the hand updates from the HTTP response (not just the broadcast). The spec submits a player action and asserts the hand partial content changed, without relying on the WebSocket.

**Files:**
- Create: `spec/requests/renders_hand_spec.rb`

**Step 1: Write the spec**

```ruby
# spec/requests/renders_hand_spec.rb
require "rails_helper"

# Regression: after the turbo-frame migration, game action controllers return
# the hand partial in the HTTP response (200 + turbo-stream update) rather than
# 204 no-content. This ensures the submitting player's hand updates from HTTP,
# not just from the WebSocket broadcast.
RSpec.describe "RendersHand concern — HTTP response updates hand", type: :request do
  describe "Speed Trivia: POST /trivia_answers" do
    let(:room) { create(:room, game_type: "Speed Trivia") }
    let(:player) { create(:player, room:) }
    let(:game) do
      g = create(:speed_trivia_game, status: "answering", trivia_pack: create(:trivia_pack))
      room.update!(current_game: g)
      g
    end
    let!(:question_instance) { create(:trivia_question_instance, speed_trivia_game: game, position: 0) }

    before { get set_player_session_path(player) }

    it "returns turbo-stream update targeting hand_screen" do
      post trivia_answers_path,
           params: { trivia_answer: { selected_option: "A" } },
           as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('action="update"')
      expect(response.body).to include('target="hand_screen"')
    end
  end

  describe "Write & Vote: POST /votes" do
    let(:room) { create(:room, game_type: "Write And Vote") }
    let(:player) { create(:player, room:) }
    let(:other_player) { create(:player, room:) }
    let(:prompt_pack) { create(:prompt_pack) }
    let(:game) do
      g = create(:write_and_vote_game, status: "voting", prompt_pack:)
      room.update!(current_game: g)
      g
    end
    let(:prompt_instance) { create(:prompt_instance, write_and_vote_game: game, round: 1) }
    let!(:voteable_response) { create(:response, player: other_player, prompt_instance:) }

    before { get set_player_session_path(player) }

    it "returns turbo-stream update targeting hand_screen" do
      post votes_path,
           params: { vote: { response_id: voteable_response.id }, code: room.code },
           as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('action="update"')
      expect(response.body).to include('target="hand_screen"')
    end
  end

  describe "Category List: POST submissions" do
    let(:room) { create(:room, game_type: "Category List") }
    let(:player) { create(:player, room:) }
    let(:game) do
      g = create(:category_list_game, status: "filling")
      room.update!(current_game: g)
      g
    end

    before { get set_player_session_path(player) }

    it "returns turbo-stream update targeting hand_screen" do
      post category_list_game_submissions_path(game),
           params: { answers: {}, code: room.code },
           as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('action="update"')
      expect(response.body).to include('target="hand_screen"')
    end
  end
end
```

**Step 2: Run the spec**

```bash
bin/rspec spec/requests/renders_hand_spec.rb -f documentation
```

Expected: all pass

**Step 3: Commit**

```bash
git add spec/requests/renders_hand_spec.rb
git commit -m "test: add regression specs for RendersHand HTTP response behavior"
```

---

### Task 12: Update CLAUDE.md

The two hard rules about `turbo: false` and `head :no_content` were workarounds for the old `<div>` architecture. Replace them with documentation of the new pattern.

**Files:**
- Modify: `CLAUDE.md` — the "Turbo Form Submissions in the Hand View" section

**Step 1: Update the section**

Find the section that starts with "### Turbo Form Submissions in the Hand View" and replace the two hard rules with a description of the new architecture:

```markdown
### Turbo Form Submissions in the Hand View

The hand view (`rooms/:code/hand`) uses `<turbo-frame id="hand_screen">` as its
content container. All player actions (submit answers, cast votes, etc.) are submitted
via Turbo forms or `button_to` inside this frame.

**How it works:**

1. Player submits a form inside `#hand_screen`
2. Turbo sends the request with the meta CSRF token (always valid)
3. The controller processes the action and calls `render_hand` (from the `RendersHand` concern)
4. `render_hand` responds with `turbo_stream.update("hand_screen", ...)` — the hand
   partial replaces the frame content immediately from the HTTP response
5. `GameBroadcaster.broadcast_hand` also fires — this updates all *other* players'
   frames via WebSocket. The submitter already has fresh state from step 4.

**The `RendersHand` concern** (`app/controllers/concerns/renders_hand.rb`) resolves
room and player from controller instance variables automatically. Controllers just call
`render_hand` with no arguments.

**All game controllers that handle hand-view actions must include `RendersHand`** and
call `render_hand` instead of `head :no_content`.

**Do not use `head :no_content` (204) in game action controllers.** 204 tells Turbo
there is nothing to render — the frame will not update from the HTTP response, and
the player must wait for the WebSocket broadcast to see their result.
```

**Step 2: Also update the memory file** (`~/.claude/projects/-Users-jackhartzler-projects-roomrally/memory/MEMORY.md`) — update the "Turbo Form Patterns (hand view)" section to reflect the new architecture.

**Step 3: Run a quick smoke test**

```bash
bin/rspec spec/requests/renders_hand_spec.rb spec/system
```

Expected: all green

**Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md to document turbo-frame hand architecture"
```

---

## Checklist

- [ ] Task 1: Failing request spec for TriviaAnswersController
- [ ] Task 2: Create RendersHand concern
- [ ] Task 3: Update TriviaAnswersController + spec passes
- [ ] Task 4: Convert hand_screen div → turbo-frame + fix hand_instructions
- [ ] Task 5: Update VotesController + update votes_spec
- [ ] Task 6: Update CategoryList::SubmissionsController
- [ ] Task 7: Update 4 SpeedTrivia host-action controllers
- [ ] Task 8: Update 5 CategoryList host-action controllers
- [ ] Task 9: Update WriteAndVote::GameStartsController
- [ ] Task 10: Full system spec run + rubocop
- [ ] Task 11: Add regression specs for RendersHand behavior
- [ ] Task 12: Update CLAUDE.md + memory
