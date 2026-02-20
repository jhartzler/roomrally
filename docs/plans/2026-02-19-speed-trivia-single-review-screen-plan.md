# Speed Trivia Single Review Screen Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Collapse the two-step reviewing flow into one combined screen showing the vote distribution row and score podium simultaneously, eliminating the 5-second inter-step delay.

**Architecture:** `close_round` absorbs score calculation immediately (no more `show_scores` or `schedule_score_reveal`). A single `_stage_reviewing` partial replaces two. `reviewing_step` state-machine sub-stepping is retired throughout backend, broadcaster, views, and tests.

**Tech Stack:** Ruby on Rails 8, AASM, Hotwire Turbo Streams, Stimulus, Tailwind CSS (vh-based sizing)

---

## Background: Key Files

- `app/services/games/speed_trivia.rb` — game logic module (Playtest module is nested at the bottom)
- `app/models/speed_trivia_game.rb` — AASM state machine, `calculate_scores!`, `process_timeout`
- `app/broadcasters/game_broadcaster.rb` — renders stage partials via Turbo Streams
- `app/views/stages/show.html.erb` — stage page, selects partial by `game.status`
- `app/views/games/speed_trivia/_stage_reviewing.html.erb` — answer reveal (being redesigned)
- `app/views/games/speed_trivia/_stage_reviewing_scores.html.erb` — score podium (being deleted)
- `app/views/games/speed_trivia/_vote_summary.html.erb` — vote counts (being redesigned to horizontal row)
- `app/views/games/speed_trivia/_score_podium.html.erb` — top-4 podium with bonk animations (unchanged)
- `app/views/games/speed_trivia/_waiting.html.erb` — hand view during reviewing (being simplified)
- `spec/services/games/speed_trivia_spec.rb` — service spec
- `spec/services/games/speed_trivia/playtest_spec.rb` — playtest spec
- `spec/requests/stage_view_spec.rb` — stage view request spec
- `spec/requests/hand_view_spec.rb` — hand view request spec

---

## Task 1: Backend — `close_round` absorbs score calculation, delete `show_scores`

**Files:**
- Modify: `app/services/games/speed_trivia.rb`
- Modify: `spec/services/games/speed_trivia_spec.rb`

### Step 1: Write failing test for new `close_round` behaviour

In `spec/services/games/speed_trivia_spec.rb`, add two tests inside `describe '.close_round'` (after the existing two tests at ~line 186):

```ruby
it 'calculates player scores immediately after closing the round' do
  player = create(:player, room:, score: 0)
  question = create(:trivia_question_instance, speed_trivia_game: game, position: 0)
  create(:trivia_answer, player:, trivia_question_instance: question, points_awarded: 500)

  described_class.close_round(game:)
  expect(player.reload.score).to eq(500)
end

it 'captures previous_top_player_ids on the game instance before updating scores' do
  player = create(:player, room:, score: 1000)

  described_class.close_round(game:)

  expect(game.previous_top_player_ids).to include(player.id)
end
```

Also in `describe '.next_question'`, inside `context 'when more questions remain'`, **delete** the test:

```ruby
# DELETE THIS ENTIRE TEST — close_round now owns score calculation
it 'calculates scores even when show_scores was skipped' do
  ...
end
```

### Step 2: Run to confirm new tests fail

```bash
bin/rspec spec/services/games/speed_trivia_spec.rb -f documentation
```

Expected: 2 failures — `close_round` does not yet calculate scores or set `previous_top_player_ids`.

### Step 3: Implement the changes in `app/services/games/speed_trivia.rb`

Replace the `close_round` method (currently lines 84–88):

```ruby
def self.close_round(game:)
  game.previous_top_player_ids = game.room.players.active_players
    .order(score: :desc).limit(4).pluck(:id)
  game.close_round!
  game.calculate_scores!
  broadcast_all(game)
end
```

Delete the entire `show_scores` method (currently lines 90–101):

```ruby
# DELETE THIS METHOD ENTIRELY
def self.show_scores(game:)
  ...
end
```

Delete the entire `schedule_score_reveal` method (currently lines 167–170):

```ruby
# DELETE THIS METHOD ENTIRELY
def self.schedule_score_reveal(game)
  ...
end
```

Remove `schedule_score_reveal` from the `private_class_method` line (currently line 172):

```ruby
# BEFORE
private_class_method :assign_questions, :start_timer_if_enabled, :broadcast_all, :schedule_score_reveal

# AFTER
private_class_method :assign_questions, :start_timer_if_enabled, :broadcast_all
```

In `next_question` (currently lines 103–122), remove the `game.calculate_scores!` call from the **"questions remaining"** branch only (keep it in the "else/finish" branch):

```ruby
def self.next_question(game:)
  if game.questions_remaining?
    # calculate_scores! removed — close_round now owns this
    game.next_question!
    start_question(game:)
  else
    game.previous_top_player_ids = game.room.players.active_players
      .order(score: :desc).limit(4).pluck(:id)
    game.calculate_scores!
    game.finish_game!
    Analytics.track(
      distinct_id: "room_#{game.room.code}",
      event: "game_completed",
      properties: { game_type: "Speed Trivia", room_code: game.room.code, player_count: game.room.players.active_players.count, duration_seconds: (Time.current - game.created_at).to_i }
    )
    game.room.finish!
    broadcast_all(game)
  end
end
```

### Step 4: Run tests to confirm they pass

```bash
bin/rspec spec/services/games/speed_trivia_spec.rb -f documentation
```

Expected: all pass.

### Step 5: Commit

```bash
git add app/services/games/speed_trivia.rb spec/services/games/speed_trivia_spec.rb
git commit -m "close_round calculates scores immediately, delete show_scores and schedule_score_reveal"
```

---

## Task 2: Clean up SpeedTriviaGame model

**Files:**
- Modify: `app/models/speed_trivia_game.rb`

No new spec needed — we're removing behavior and the model spec (if any tests cover `reset_reviewing_step`) should be deleted. Check `spec/models/speed_trivia_game_spec.rb` — if any test checks that `reviewing_step` is reset to 1 after `close_round`, delete it.

### Step 1: Remove `reset_reviewing_step` from AASM callback

In `app/models/speed_trivia_game.rb`, find the `close_round` event (around line 38):

```ruby
# BEFORE
event :close_round do
  transitions from: :answering, to: :reviewing, after: [ :record_round_close, :reset_reviewing_step ]
end

# AFTER
event :close_round do
  transitions from: :answering, to: :reviewing, after: :record_round_close
end
```

### Step 2: Delete the `reset_reviewing_step` private method

Find and delete (currently around line 110):

```ruby
# DELETE THIS METHOD
def reset_reviewing_step
  update!(reviewing_step: 1)
end
```

### Step 3: Simplify `process_timeout`

Replace the current `process_timeout` (around lines 79–93) with:

```ruby
def process_timeout(job_question_index, step_number)
  return unless current_question_index == job_question_index
  return unless answering?

  Games::SpeedTrivia.handle_timeout(game: self)
end
```

The `step_number` parameter is kept for method signature compatibility with `HasRoundTimer` but no longer branched on.

### Step 4: Run the full service + model specs

```bash
bin/rspec spec/services/games/speed_trivia_spec.rb spec/models/speed_trivia_game_spec.rb -f documentation
```

Expected: all pass.

### Step 5: Commit

```bash
git add app/models/speed_trivia_game.rb spec/models/speed_trivia_game_spec.rb
git commit -m "Remove reviewing_step reset from SpeedTriviaGame, simplify process_timeout"
```

---

## Task 3: Remove reviewing_step routing from GameBroadcaster and stage view

**Files:**
- Modify: `app/broadcasters/game_broadcaster.rb`
- Modify: `app/views/stages/show.html.erb`
- Modify: `spec/requests/stage_view_spec.rb`

### Step 1: Delete the two obsolete stage_view_spec tests

In `spec/requests/stage_view_spec.rb`, delete the entire two contexts added this session (lines 65–98):

```ruby
# DELETE BOTH OF THESE CONTEXTS ENTIRELY:
context "when a SpeedTrivia game is reviewing with step 1 (answer reveal)" do
  ...
end

context "when a SpeedTrivia game is reviewing with step 2 (score podium)" do
  ...
end
```

### Step 2: Run to confirm remaining tests pass

```bash
bin/rspec spec/requests/stage_view_spec.rb -f documentation
```

Expected: 6 examples, 0 failures.

### Step 3: Remove reviewing_step special-casing from GameBroadcaster

In `app/broadcasters/game_broadcaster.rb`, remove lines 20–23 (the `reviewing_step == 2` block):

```ruby
# BEFORE (lines 19–25)
status_suffix = game.status
# Reviewing step 2 gets its own partial for the score podium
if game.respond_to?(:reviewing_step) && game.status == "reviewing" && game.reviewing_step == 2
  status_suffix = "reviewing_scores"
end

partial_name = "games/#{game_folder_name(room.game_type)}/stage_#{status_suffix}"

# AFTER (lines 19–21)
partial_name = "games/#{game_folder_name(room.game_type)}/stage_#{game.status}"
```

Also remove the `locals` block for `previous_top_player_ids` ... wait, keep this — it's still needed for the podium animation. The `locals` block at lines 29–32 stays:

```ruby
locals = { room:, game: }
if game.respond_to?(:previous_top_player_ids) && game.previous_top_player_ids.present?
  locals[:previous_top_player_ids] = game.previous_top_player_ids
end
```

### Step 4: Simplify stages/show.html.erb

In `app/views/stages/show.html.erb`, replace lines 25–29 with a single line:

```erb
<%# BEFORE %>
<% status_suffix = game.status %>
<% if game.respond_to?(:reviewing_step) && game.status == "reviewing" && game.reviewing_step == 2 %>
  <% status_suffix = "reviewing_scores" %>
<% end %>
<% partial_name = "games/#{game_type_folder}/stage_#{status_suffix}" %>

<%# AFTER — single line %>
<% partial_name = "games/#{game_type_folder}/stage_#{game.status}" %>
```

### Step 5: Run specs

```bash
bin/rspec spec/requests/stage_view_spec.rb spec/services/games/speed_trivia_spec.rb -f documentation
```

Expected: all pass.

### Step 6: Commit

```bash
git add app/broadcasters/game_broadcaster.rb app/views/stages/show.html.erb spec/requests/stage_view_spec.rb
git commit -m "Remove reviewing_step routing from GameBroadcaster and stage view"
```

---

## Task 4: Simplify Playtest auto_play_step

**Files:**
- Modify: `app/services/games/speed_trivia.rb` (the nested `Playtest` module)
- Modify: `spec/services/games/speed_trivia/playtest_spec.rb`

### Step 1: Write new failing test

In `spec/services/games/speed_trivia/playtest_spec.rb`, inside `describe ".auto_play_step"`, replace the `context "when game is in reviewing state"` block (lines 134–161) with:

```ruby
it "advances to next question from reviewing" do
  game = start_answering!
  Games::SpeedTrivia.close_round(game:)
  game.reload
  expect(game.status).to eq("reviewing")

  described_class.auto_play_step(game:)
  game.reload

  expect(game.current_question_index).to eq(1)
end
```

### Step 2: Run to confirm it fails

```bash
bin/rspec spec/services/games/speed_trivia/playtest_spec.rb -f documentation
```

Expected: new test fails — auto_play_step currently calls `show_scores` (now deleted) when `reviewing_step == 1`.

### Step 3: Implement the simplification

In `app/services/games/speed_trivia.rb`, find the `Playtest` module's `auto_play_step` method. Replace the `when "reviewing"` branch:

```ruby
# BEFORE
when "reviewing"
  if game.reviewing_step == 1
    Games::SpeedTrivia.show_scores(game:)
  else
    Games::SpeedTrivia.next_question(game:)
  end

# AFTER
when "reviewing"
  Games::SpeedTrivia.next_question(game:)
```

### Step 4: Run to confirm all pass

```bash
bin/rspec spec/services/games/speed_trivia/playtest_spec.rb -f documentation
```

Expected: all pass.

### Step 5: Commit

```bash
git add app/services/games/speed_trivia.rb spec/services/games/speed_trivia/playtest_spec.rb
git commit -m "Simplify Playtest auto_play_step: reviewing always advances to next_question"
```

---

## Task 5: Simplify hand view — remove reviewing_step branching

**Files:**
- Modify: `app/views/games/speed_trivia/_waiting.html.erb`
- Modify: `spec/requests/hand_view_spec.rb`

### Step 1: Update the hand_view_spec

Replace the entire contents of `spec/requests/hand_view_spec.rb` with:

```ruby
require "rails_helper"

RSpec.describe "Hand View - Speed Trivia score animation", type: :request do
  let(:room) { create(:room, game_type: "Speed Trivia") }
  let(:player) { create(:player, room:, score: 0) }

  before do
    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(ApplicationController).to receive(:current_player).and_return(player)
    # rubocop:enable RSpec/AnyInstance
  end

  context "when reviewing and the player scored points this round" do
    # player.score is already the post-round total (calculate_scores! runs in close_round).
    # The animation counts from old score to new score.
    let(:game) do
      g = create(:speed_trivia_game, status: "reviewing", current_question_index: 0)
      room.update!(current_game: g)
      g
    end

    before do
      round_points = 750
      old_score = 500
      player.update!(score: old_score + round_points)
      question = create(:trivia_question_instance, speed_trivia_game: game, position: 0)
      create(:trivia_answer, trivia_question_instance: question, player:, points_awarded: round_points, correct: true)
    end

    it "animates from old score to new score" do
      get room_hand_path(room.code)
      expect(response.body).to include("data-score-tally-from-value=\"500\"")
      expect(response.body).to include("data-score-tally-to-value=\"1250\"")
    end
  end

  context "when reviewing and the player scored zero points this round" do
    # score_from == score_to so no animation fires.
    let(:score) { 500 }
    let(:game) do
      g = create(:speed_trivia_game, status: "reviewing", current_question_index: 0)
      room.update!(current_game: g)
      g
    end

    before do
      player.update!(score:)
      question = create(:trivia_question_instance, speed_trivia_game: game, position: 0)
      create(:trivia_answer, trivia_question_instance: question, player:, points_awarded: 0, correct: false)
    end

    it "sets score_from and score_to both to the same value (no animation)" do
      get room_hand_path(room.code)
      expect(response.body).to include("data-score-tally-from-value=\"#{score}\"")
      expect(response.body).to include("data-score-tally-to-value=\"#{score}\"")
    end
  end
end
```

### Step 2: Run to confirm the new test fails

```bash
bin/rspec spec/requests/hand_view_spec.rb -f documentation
```

Expected: "animates from old score to new score" fails — the view still has reviewing_step branching and will try to check `game.reviewing_step` which defaults to 1, applying the "no animation" path.

### Step 3: Simplify `_waiting.html.erb`

In `app/views/games/speed_trivia/_waiting.html.erb`, replace lines 29–52 (the reviewing_step branching block) with:

```erb
<%# Score animation: count from pre-round total to new total.
    player.score is already the post-round total since calculate_scores! runs in close_round. %>
<% score_from = player.score - round_points %>
<% score_to   = player.score %>

<%# Rank computation: compare actual post-round rank vs pre-round rank. %>
<% all_players = room.players.active_players.to_a %>
<% round_points_by_id = current_question.trivia_answers.each_with_object({}) { |a, h| h[a.player_id] = a.points_awarded.to_i } %>
<% sorted_now  = all_players.sort_by { |p| -p.score } %>
<% sorted_prev = all_players.sort_by { |p| -(p.score - round_points_by_id.fetch(p.id, 0)) } %>
```

### Step 4: Run to confirm all pass

```bash
bin/rspec spec/requests/hand_view_spec.rb -f documentation
```

Expected: 2 examples, 0 failures.

### Step 5: Commit

```bash
git add app/views/games/speed_trivia/_waiting.html.erb spec/requests/hand_view_spec.rb
git commit -m "Simplify hand view: remove reviewing_step branching, always animate to new score"
```

---

## Task 6: New combined stage view

**Files:**
- Modify: `app/views/games/speed_trivia/_stage_reviewing.html.erb`
- Modify: `app/views/games/speed_trivia/_vote_summary.html.erb`
- Delete: `app/views/games/speed_trivia/_stage_reviewing_scores.html.erb`
- Modify: `spec/requests/stage_view_spec.rb`

### Step 1: Write a failing test for the combined view

In `spec/requests/stage_view_spec.rb`, add a new context inside `describe "GET /rooms/:code/stage"` (after the existing "when logged in as the room owner" context):

```ruby
context "when a SpeedTrivia game is in reviewing state" do
  let(:game) { create(:speed_trivia_game, status: "reviewing", current_question_index: 0) }
  let(:speed_trivia_room) { create(:room, user:, game_type: "Speed Trivia", current_game: game) }

  before do
    question = create(:trivia_question_instance,
      speed_trivia_game: game,
      position: 0,
      options: %w[Paris London Berlin Madrid],
      correct_answers: ["Paris"])
    create(:player, room: speed_trivia_room, score: 500, name: "Top Player")
    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    # rubocop:enable RSpec/AnyInstance
  end

  it "renders a single stage_reviewing partial containing both vote counts and score podium" do
    get room_stage_path(speed_trivia_room.code)
    expect(response.body).to include('id="stage_reviewing"')
    expect(response.body).not_to include('id="stage_reviewing_scores"')
    # Vote summary present
    expect(response.body).to include("Paris")
    # Score podium present
    expect(response.body).to include("games--podium")
  end
end
```

### Step 2: Run to confirm the test fails

```bash
bin/rspec spec/requests/stage_view_spec.rb -f documentation
```

Expected: new test fails — the view currently renders vote summary but NOT the podium (that was step 2).

### Step 3: Redesign `_stage_reviewing.html.erb`

Replace the entire file:

```erb
<%# app/views/games/speed_trivia/_stage_reviewing.html.erb %>
<%# Combined answer reveal + score podium. Shown immediately after close_round. %>
<div id="stage_reviewing" class="flex flex-col items-center flex-1 min-h-0 gap-[2vh] animate-fade-in">
  <% current_question = game.current_question %>

  <!-- Question counter -->
  <div class="shrink-0">
    <span class="text-vh-base text-blue-200 font-bold uppercase tracking-widest">
      Question <%= game.current_question_index + 1 %> Results
    </span>
  </div>

  <!-- Correct answer banner -->
  <div class="bg-white/10 backdrop-blur-xl border border-white/20 rounded-2xl p-[1.5vh] text-center max-w-6xl w-full shrink-0">
    <p class="text-vh-lg text-blue-200 mb-[1vh]"><%= current_question&.body %></p>
    <div class="flex flex-wrap items-center justify-center gap-[1vh]">
      <% current_question&.correct_answers&.each do |answer| %>
        <div class="flex items-center gap-1">
          <span class="text-vh-lg">✓</span>
          <h2 class="text-vh-xl font-black text-green-400"><%= answer %></h2>
        </div>
      <% end %>
    </div>
  </div>

  <!-- Vote distribution row -->
  <%= render "games/speed_trivia/vote_summary", question: current_question %>

  <!-- Score podium -->
  <%= render "games/speed_trivia/score_podium",
        game: game,
        room: room,
        previous_top_player_ids: local_assigns[:previous_top_player_ids] || [] %>
</div>
```

### Step 4: Redesign `_vote_summary.html.erb` to horizontal row

Replace the entire file:

```erb
<%# app/views/games/speed_trivia/_vote_summary.html.erb %>
<%# Horizontal 4-column row showing vote count per answer option. %>
<% vote_counts = question.vote_counts %>
<div class="grid grid-cols-4 gap-[1.5vh] max-w-6xl w-full shrink-0">
  <% question.options.each_with_index do |option, index| %>
    <% votes = vote_counts[option] || 0 %>
    <% is_correct = question.correct_answers.include?(option) %>

    <div class="bg-black/40 backdrop-blur-md border-2 <%= is_correct ? 'border-green-500 bg-green-500/10' : 'border-gray-600' %> rounded-xl p-[1.5vh] flex flex-col items-center text-center gap-[0.5vh]">
      <div class="bg-white text-black font-black text-vh-lg h-[4vh] w-[4vh] rounded-full flex items-center justify-center shrink-0">
        <%= (index + 65).chr %>
      </div>
      <p class="text-vh-sm text-white font-bold line-clamp-2 flex-grow"><%= option %></p>
      <div class="text-vh-2xl font-black <%= is_correct ? 'text-green-400' : 'text-blue-300' %> font-mono">
        <%= votes %>
      </div>
      <div class="text-vh-xs text-gray-400"><%= votes == 1 ? "vote" : "votes" %></div>
    </div>
  <% end %>
</div>
```

### Step 5: Delete `_stage_reviewing_scores.html.erb`

```bash
git rm app/views/games/speed_trivia/_stage_reviewing_scores.html.erb
```

### Step 6: Run to confirm tests pass

```bash
bin/rspec spec/requests/stage_view_spec.rb -f documentation
```

Expected: all pass (7 examples).

### Step 7: Commit

```bash
git add app/views/games/speed_trivia/_stage_reviewing.html.erb \
        app/views/games/speed_trivia/_vote_summary.html.erb \
        spec/requests/stage_view_spec.rb
git commit -m "Combined stage review screen: horizontal vote row + score podium in one step"
```

---

## Task 7: Full suite, rubocop, push

### Step 1: Run the full test suite

```bash
bin/rspec
```

Expected: 0 failures. If any failures, fix them before continuing.

### Step 2: Run rubocop

```bash
rubocop
```

Expected: no offenses. If any, run `rubocop -A` for auto-fixes, review, commit.

### Step 3: Push and update PR

```bash
git push origin feature/devplaytest-colocation
```

Then open the PR and note that this adds the combined review screen.
