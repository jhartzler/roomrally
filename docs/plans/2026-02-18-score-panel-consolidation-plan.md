# Score Panel Consolidation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Show the animated score panel on the same screen as the answer reveal (Correct/Wrong emoji), so players see their score for the full 5-second step 1 window instead of a brief separate step 2 screen.

**Architecture:** Collapse the two `reviewing_step` branches in `_waiting.html.erb` into a single combined view. Use a step-aware formula so `score_from`/`score_to` produce identical values whether computed at step 1 (projecting forward using `points_awarded`) or step 2 (backing out from the already-updated `player.score`). No changes to the game service or Stimulus controller needed.

**Tech Stack:** Ruby on Rails ERB partials, Tailwind CSS, existing `score-tally` Stimulus controller

---

## Background: Score formula at each step

At **step 1** (`close_round!` just fired):
- `player.score` = accumulated total *before* this round (e.g. 750)
- `player_answer.points_awarded` = points earned this round (e.g. 248)
- So: `score_from = player.score` (750), `score_to = player.score + round_points` (998)

At **step 2** (`calculate_scores!` has run):
- `player.score` = updated total (998)
- `player_answer.points_awarded` = same 248
- So: `score_from = player.score - round_points` (750), `score_to = player.score` (998)

Both give `from=750, to=998`. The animation is visually identical at either step.

---

## Task 1: Rewrite the reviewing branch as a single combined view

**Files:**
- Modify: `app/views/games/speed_trivia/_waiting.html.erb`

**Step 1: Read the current file**

Current `app/views/games/speed_trivia/_waiting.html.erb` has a `reviewing?` branch that splits on `reviewing_step == 2`. We replace the entire `elsif game.reviewing?` block with a single combined view.

**Step 2: Replace the reviewing branch**

Replace the entire `<% elsif game.reviewing? %>` block (lines 24–87) with:

```erb
    <% elsif game.reviewing? %>
      <% current_question = game.current_question %>
      <% player_answer = current_question&.trivia_answers&.find_by(player:) %>
      <% round_points = player_answer&.points_awarded.to_i %>

      <%# Step-aware score formula: produces identical from/to at step 1 and step 2 %>
      <% if game.reviewing_step == 1 %>
        <% score_from = player.score %>
        <% score_to   = player.score + round_points %>
      <% else %>
        <% score_from = player.score - round_points %>
        <% score_to   = player.score %>
      <% end %>

      <%# Rank computation: projected at step 1, actual at step 2 — same result %>
      <% all_players = room.players.active_players.to_a %>
      <% round_points_by_id = current_question.trivia_answers.each_with_object({}) { |a, h| h[a.player_id] = a.points_awarded.to_i } %>
      <% if game.reviewing_step == 1 %>
        <% sorted_now  = all_players.sort_by { |p| -(p.score + round_points_by_id.fetch(p.id, 0)) } %>
        <% sorted_prev = all_players.sort_by { |p| -p.score } %>
      <% else %>
        <% sorted_now  = all_players.sort_by { |p| -p.score } %>
        <% sorted_prev = all_players.sort_by { |p| -(p.score - round_points_by_id.fetch(p.id, 0)) } %>
      <% end %>
      <% current_rank  = sorted_now.index  { |p| p.id == player.id }.to_i + 1 %>
      <% previous_rank = sorted_prev.index { |p| p.id == player.id }.to_i + 1 %>

      <%# Motivational message %>
      <% message = if round_points == 0
        ["Oof!", "Next time!"].sample
      elsif current_rank <= previous_rank
        ["Nice one!", "Way to go!"].sample
      else
        ["Keep it up!", "You can do it!"].sample
      end %>

      <%# Answer result section %>
      <% if player_answer&.correct? %>
        <div class="text-5xl mb-3">🎉</div>
        <p class="text-2xl text-green-400 font-bold mb-1">Correct!</p>
      <% elsif player_answer %>
        <div class="text-5xl mb-3">😅</div>
        <p class="text-2xl text-red-400 font-bold mb-1">Wrong!</p>
        <p class="text-sm text-white mb-1">The answer was: <span class="font-bold text-green-400"><%= current_question.correct_answers.join(", ") %></span></p>
      <% else %>
        <div class="text-5xl mb-3">⏱</div>
        <p class="text-2xl text-gray-400 font-bold mb-1">Time's Up!</p>
        <p class="text-sm text-white mb-1">The answer was: <span class="font-bold text-green-400"><%= current_question&.correct_answers&.join(", ") %></span></p>
      <% end %>

      <hr class="border-white/20 my-4">

      <%# Score panel section %>
      <div class="text-xl font-black text-white mb-4"><%= message %></div>

      <div data-controller="score-tally"
           data-score-tally-from-value="<%= score_from %>"
           data-score-tally-to-value="<%= score_to %>">
        <p class="text-blue-200 text-sm font-bold uppercase tracking-widest mb-1">
          <%= current_rank.ordinalize %> Place
        </p>
        <p class="text-5xl font-black text-white font-mono mb-2"
           data-score-tally-target="display">
          <%= score_from.to_s %>
        </p>
        <% if round_points > 0 %>
          <p class="text-green-400 font-bold text-lg">+<%= round_points %> this round</p>
        <% else %>
          <p class="text-gray-400 font-bold text-lg">+0 this round</p>
        <% end %>
      </div>
```

The full file after editing should be:

```erb
<%# app/views/games/speed_trivia/_waiting.html.erb %>

<header class="max-w-md mx-auto flex justify-between items-center mb-6 px-2">
  <div class="flex flex-col">
    <span class="text-blue-100/80 text-xs font-bold tracking-widest uppercase">
      <%= game.waiting? ? "Get Ready" : "Results" %>
    </span>
  </div>
  <div class="bg-white/10 backdrop-blur-md border border-white/20 rounded-xl px-4 py-2 text-center shadow-sm">
    <p class="text-[10px] text-blue-200 font-bold uppercase tracking-wider">Code</p>
    <p class="text-xl font-black text-white font-mono leading-none"><%= room.code %></p>
  </div>
</header>

<div class="max-w-md mx-auto">
  <div class="bg-white/10 backdrop-blur-md rounded-3xl p-8 border border-white/20 text-center">
    <% if game.waiting? %>
      <div class="text-6xl mb-6 animate-bounce">🧠</div>
      <p class="text-2xl text-white font-bold mb-4">Get Ready!</p>
      <p class="text-lg text-blue-200">
        <%= game.trivia_question_instances.count %> questions
      </p>
      <p class="text-blue-300 mt-4">Faster answers = more points!</p>
    <% elsif game.reviewing? %>
      <% current_question = game.current_question %>
      <% player_answer = current_question&.trivia_answers&.find_by(player:) %>
      <% round_points = player_answer&.points_awarded.to_i %>

      <%# Step-aware score formula: produces identical from/to at step 1 and step 2 %>
      <% if game.reviewing_step == 1 %>
        <% score_from = player.score %>
        <% score_to   = player.score + round_points %>
      <% else %>
        <% score_from = player.score - round_points %>
        <% score_to   = player.score %>
      <% end %>

      <%# Rank computation: projected at step 1, actual at step 2 — same result %>
      <% all_players = room.players.active_players.to_a %>
      <% round_points_by_id = current_question.trivia_answers.each_with_object({}) { |a, h| h[a.player_id] = a.points_awarded.to_i } %>
      <% if game.reviewing_step == 1 %>
        <% sorted_now  = all_players.sort_by { |p| -(p.score + round_points_by_id.fetch(p.id, 0)) } %>
        <% sorted_prev = all_players.sort_by { |p| -p.score } %>
      <% else %>
        <% sorted_now  = all_players.sort_by { |p| -p.score } %>
        <% sorted_prev = all_players.sort_by { |p| -(p.score - round_points_by_id.fetch(p.id, 0)) } %>
      <% end %>
      <% current_rank  = sorted_now.index  { |p| p.id == player.id }.to_i + 1 %>
      <% previous_rank = sorted_prev.index { |p| p.id == player.id }.to_i + 1 %>

      <%# Motivational message %>
      <% message = if round_points == 0
        ["Oof!", "Next time!"].sample
      elsif current_rank <= previous_rank
        ["Nice one!", "Way to go!"].sample
      else
        ["Keep it up!", "You can do it!"].sample
      end %>

      <%# Answer result section %>
      <% if player_answer&.correct? %>
        <div class="text-5xl mb-3">🎉</div>
        <p class="text-2xl text-green-400 font-bold mb-1">Correct!</p>
      <% elsif player_answer %>
        <div class="text-5xl mb-3">😅</div>
        <p class="text-2xl text-red-400 font-bold mb-1">Wrong!</p>
        <p class="text-sm text-white mb-1">The answer was: <span class="font-bold text-green-400"><%= current_question.correct_answers.join(", ") %></span></p>
      <% else %>
        <div class="text-5xl mb-3">⏱</div>
        <p class="text-2xl text-gray-400 font-bold mb-1">Time's Up!</p>
        <p class="text-sm text-white mb-1">The answer was: <span class="font-bold text-green-400"><%= current_question&.correct_answers&.join(", ") %></span></p>
      <% end %>

      <hr class="border-white/20 my-4">

      <%# Score panel section %>
      <div class="text-xl font-black text-white mb-4"><%= message %></div>

      <div data-controller="score-tally"
           data-score-tally-from-value="<%= score_from %>"
           data-score-tally-to-value="<%= score_to %>">
        <p class="text-blue-200 text-sm font-bold uppercase tracking-widest mb-1">
          <%= current_rank.ordinalize %> Place
        </p>
        <p class="text-5xl font-black text-white font-mono mb-2"
           data-score-tally-target="display">
          <%= score_from.to_s %>
        </p>
        <% if round_points > 0 %>
          <p class="text-green-400 font-bold text-lg">+<%= round_points %> this round</p>
        <% else %>
          <p class="text-gray-400 font-bold text-lg">+0 this round</p>
        <% end %>
      </div>
    <% end %>
  </div>
</div>
```

**Step 3: Commit**

```bash
git add app/views/games/speed_trivia/_waiting.html.erb
git commit -m "feat: consolidate score panel onto answer reveal screen"
```

---

## Task 2: Update the system test

**Files:**
- Modify: `spec/system/games/speed_trivia_happy_path_spec.rb`

**Step 1: Move score panel assertions to after `close_round`**

In the spec, find the block after `Games::SpeedTrivia.close_round(game: game.reload)` (around line 105). It currently only checks for "Correct!" or "Wrong!". We extend it to also assert the score panel is present.

Replace this block:

```ruby
    # All players should see their result
    [ :host, :player2, :player3 ].each do |session|
      Capybara.using_session(session) do
        visit current_path
        # Wait for Turbo transition, refresh if stale DOM causes issues
        unless page.has_content?("Correct!", wait: 5) || page.has_content?("Wrong!", wait: 5)
          visit current_path
        end
        expect(page).to have_content("Correct!", wait: 5).or have_content("Wrong!", wait: 5)
        screenshot_checkpoint("reviewing")
      end
    end
```

With:

```ruby
    # All players should see their result AND score panel on the same screen
    [ :host, :player2, :player3 ].each do |session|
      Capybara.using_session(session) do
        visit current_path
        # Wait for Turbo transition, refresh if stale DOM causes issues
        unless page.has_content?("Correct!", wait: 5) || page.has_content?("Wrong!", wait: 5)
          visit current_path
        end
        expect(page).to have_content("Correct!", wait: 5).or have_content("Wrong!", wait: 5)
        # Score panel should appear on the same screen
        expect(page).to have_css("[data-controller='score-tally']", wait: 5)
        expect(page).to have_content(/place/i, wait: 5)
        expect(page).to have_content("this round", wait: 5)
        screenshot_checkpoint("reviewing")
      end
    end
```

**Step 2: Remove the now-redundant score panel block after `show_scores`**

Find and remove this block (added in the previous implementation):

```ruby
    # All players should see their score panel on their phone
    [ :host, :player2, :player3 ].each do |session|
      Capybara.using_session(session) do
        visit current_path
        expect(page).to have_css("[data-controller='score-tally']", wait: 5)
        expect(page).to have_content(/place/i, wait: 5)
        expect(page).to have_content("this round", wait: 5)
        screenshot_checkpoint("score_panel")
      end
    end
```

After removal, the `show_scores` call should flow directly into the `next_question` call:

```ruby
    # Host advances to score podium (step 2 of reviewing)
    Games::SpeedTrivia.show_scores(game: game.reload)

    # Host advances to finish (only had 1 question set up for simplicity)
    game.update!(current_question_index: game.trivia_question_instances.count - 1)
    Games::SpeedTrivia.next_question(game: game.reload)
```

**Step 3: Run the system test**

```bash
bin/rspec spec/system/games/speed_trivia_happy_path_spec.rb
```

Expected: 1 example, 0 failures

**Step 4: Commit**

```bash
git add spec/system/games/speed_trivia_happy_path_spec.rb
git commit -m "test: assert score panel appears alongside answer reveal at step 1"
```

---

## Verification Checklist

After all tasks:

- [ ] `bin/rspec spec/system/games/speed_trivia_happy_path_spec.rb` passes
- [ ] `rubocop` passes (no new offenses)
- [ ] In a real browser: play a round, verify score panel appears immediately with the Correct/Wrong result, animation plays for the full 5-second step 1 window
