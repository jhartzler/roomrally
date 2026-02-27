# In-Game Clarity Phase 1 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix four in-game confusion points across Comedy Clash and A-List: the author-waiting copy, missing letter labels on hand vote cards, missing round count, and A-List scoring hint.

**Architecture:** All changes are view-only (ERB templates). No new models, controllers, or Stimulus controllers. Fix 3 uses a constant already defined in the service (`Games::WriteAndVote::MAX_ROUNDS = 2`). Tests are system specs with `:js` that assert visible copy and UI elements.

**Tech Stack:** Ruby on Rails ERB templates, RSpec system specs with Capybara/Playwright, Tailwind CSS.

---

## Key Files

- `app/views/games/write_and_vote/_voting.html.erb` — hand voting view (Fixes 1 + 2)
- `app/views/games/write_and_vote/_stage_writing.html.erb` — stage writing view (Fix 3)
- `app/views/games/write_and_vote/_prompt_screen.html.erb` — hand writing view (Fix 3)
- `app/views/games/category_list/_answer_form.html.erb` — hand filling view (Fix 4)
- `app/services/games/write_and_vote.rb` — has `MAX_ROUNDS = 2` constant (line 3)

## Test File Conventions

- System specs live in `spec/system/games/`
- Always mark with `:js, type: :system`
- Use `Capybara.using_session(:name)` for multi-player scenarios
- Advance game state via service calls in `before` block (see `write_and_vote_voting_spec.rb` for the pattern)
- Run a single spec: `bin/rspec spec/system/games/your_spec.rb`
- Run all system specs: `bin/rspec spec/system`

---

## Task 1: Fix Author Waiting State Copy (Comedy Clash)

**Files:**
- Modify: `app/views/games/write_and_vote/_voting.html.erb:39-44`
- Test: `spec/system/games/write_and_vote_voting_spec.rb` (update existing assertion)

The `_voting.html.erb` branch at line 38 (`if responses.exists?(player: player)`) shows the author waiting state. The current copy is vague. Replace it with copy that frames the moment as exciting — their answer is being judged.

**Step 1: Update the existing voting spec to assert the new copy**

Open `spec/system/games/write_and_vote_voting_spec.rb`. The existing test (line 82) already asserts `have_content("Voting in Progress")` for the author waiting state. Update that assertion to match the new copy.

Change line 82 from:
```ruby
expect(page).to have_content("Voting in Progress", wait: 5)
```
To:
```ruby
expect(page).to have_content("Your answer is up for a vote!", wait: 5)
```

**Step 2: Run the test — verify it fails**

```bash
bin/rspec spec/system/games/write_and_vote_voting_spec.rb
```

Expected: FAIL — `expected to find text "Your answer is up for a vote!" but did not`

**Step 3: Update the view**

In `app/views/games/write_and_vote/_voting.html.erb`, replace lines 39–44:

```erb
      <div class="text-center p-8 bg-white/5 backdrop-blur-md rounded-xl border border-white/10 flex flex-col items-center">
        <div class="text-4xl mb-3 animate-bounce">🗳️</div>
        <h3 class="text-xl font-bold text-white mb-2">Voting in Progress</h3>
        <p class="text-blue-200">May the best answer win!</p>
        <p class="text-blue-300/50 text-xs mt-4 animate-pulse uppercase tracking-widest font-bold">Waiting for other players...</p>
      </div>
```

With:

```erb
      <div class="text-center p-8 bg-white/5 backdrop-blur-md rounded-xl border border-white/10 flex flex-col items-center">
        <div class="text-4xl mb-3 animate-bounce">🗳️</div>
        <h3 class="text-xl font-bold text-white mb-2">Your answer is up for a vote!</h3>
        <p class="text-blue-200">Sit tight — the room is deciding if you're a comedy genius or just... brave.</p>
        <p class="text-blue-300/50 text-xs mt-4 animate-pulse uppercase tracking-widest font-bold">Waiting for everyone to vote...</p>
      </div>
```

**Step 4: Run the test — verify it passes**

```bash
bin/rspec spec/system/games/write_and_vote_voting_spec.rb
```

Expected: PASS

**Step 5: Commit**

```bash
git add app/views/games/write_and_vote/_voting.html.erb spec/system/games/write_and_vote_voting_spec.rb
git commit -m "fix: update Comedy Clash author waiting state copy to frame it as exciting"
```

---

## Task 2: Add Letter Labels to Hand Vote Buttons (Comedy Clash)

**Files:**
- Modify: `app/views/games/write_and_vote/_voting.html.erb:70-86`
- Test: `spec/system/games/write_and_vote_voting_spec.rb` (add new assertion)

The stage voting view already renders letters using `(index + 65).chr` (line 24 of `_stage_voting.html.erb`) — `65` is the ASCII code for `A`, so index 0 → `A`, 1 → `B`, etc. The hand renders the same `available_responses.order(:id)` but without letters. We need to add the same letter badge to each response card on the hand.

**Step 1: Write a failing test**

Add a new `it` block to `spec/system/games/write_and_vote_voting_spec.rb`:

```ruby
it "shows letter labels (A, B, C...) on response cards so players can coordinate with the stage" do
  Capybara.using_session(:voter) do
    visit set_player_session_path(voter)

    expect(page).to have_content("Vote for the best answer!", wait: 5)
    expect(page).to have_content("A")
    expect(page).to have_content("B")
  end
end
```

**Step 2: Run the test — verify it fails**

```bash
bin/rspec spec/system/games/write_and_vote_voting_spec.rb
```

Expected: FAIL — the letters A and B are not currently rendered on the hand.

**Step 3: Update the view**

In `app/views/games/write_and_vote/_voting.html.erb`, the response cards loop starts at line 72. The loop currently uses `available_responses.each`. Change it to `each_with_index` and add a letter badge.

Replace:
```erb
        <% available_responses.each do |response| %>
          <div class="response-card bg-blue-600/20 backdrop-blur-sm p-6 rounded-2xl border border-blue-400/30 shadow-sm transition-all"
               data-controller="vote-feedback">
            <div class="text-xl font-bold text-white mb-4 leading-relaxed text-center">
              "<%= response.body %>"
            </div>
```

With:
```erb
        <% available_responses.each_with_index do |response, index| %>
          <div class="response-card bg-blue-600/20 backdrop-blur-sm p-6 rounded-2xl border border-blue-400/30 shadow-sm transition-all"
               data-controller="vote-feedback">
            <div class="flex items-center gap-3 mb-4">
              <div class="bg-white/20 text-white font-black text-lg h-9 w-9 rounded-full flex items-center justify-center shrink-0">
                <%= (index + 65).chr %>
              </div>
              <div class="text-xl font-bold text-white leading-relaxed">
                "<%= response.body %>"
              </div>
            </div>
```

**Step 4: Run the test — verify it passes**

```bash
bin/rspec spec/system/games/write_and_vote_voting_spec.rb
```

Expected: PASS

**Step 5: Commit**

```bash
git add app/views/games/write_and_vote/_voting.html.erb spec/system/games/write_and_vote_voting_spec.rb
git commit -m "feat: add A/B/C letter badges to hand vote cards in Comedy Clash"
```

---

## Task 3: Show Round Count During Writing and Voting (Comedy Clash)

**Files:**
- Modify: `app/views/games/write_and_vote/_voting.html.erb:7-11`
- Modify: `app/views/games/write_and_vote/_stage_writing.html.erb:13-14`
- Modify: `app/views/games/write_and_vote/_prompt_screen.html.erb:4-6`
- Test: `spec/system/games/write_and_vote_prompt_display_spec.rb` (add assertions)

`Games::WriteAndVote::MAX_ROUNDS = 2` is defined in `app/services/games/write_and_vote.rb`. Pass this through as `Games::WriteAndVote::MAX_ROUNDS` directly in the view — no new locals needed, the constant is accessible in views.

**Step 1: Write failing tests**

Open `spec/system/games/write_and_vote_prompt_display_spec.rb` and read its existing structure to understand what's already set up. Then add:

```ruby
it "shows total round count during writing phase on the hand" do
  # Set up: get to writing state
  # (follow the existing spec's before block pattern)
  Capybara.using_session(:player) do
    visit set_player_session_path(player)
    expect(page).to have_content("Round 1 of 2", wait: 5)
  end
end

it "shows total round count during voting phase on the hand" do
  # advance to voting
  Capybara.using_session(:voter) do
    visit set_player_session_path(voter)
    expect(page).to have_content("Round 1 of 2", wait: 5)
  end
end
```

**Step 2: Run the tests — verify they fail**

```bash
bin/rspec spec/system/games/write_and_vote_prompt_display_spec.rb
```

Expected: FAIL

**Step 3: Update hand voting progress header**

In `app/views/games/write_and_vote/_voting.html.erb`, replace line 9:

```erb
      Round <%= current_game.round %> • Prompt <%= current_game.current_prompt_index + 1 %> of <%= current_game.current_round_prompts.count %>
```

With:

```erb
      Round <%= current_game.round %> of <%= Games::WriteAndVote::MAX_ROUNDS %> • Prompt <%= current_game.current_prompt_index + 1 %> of <%= current_game.current_round_prompts.count %>
```

**Step 4: Update hand writing header**

In `app/views/games/write_and_vote/_prompt_screen.html.erb`, replace line 5:

```erb
  <span class="text-blue-100/80 text-xs font-bold tracking-widest uppercase">Write your best answer...</span>
```

With:

```erb
  <span class="text-blue-100/80 text-xs font-bold tracking-widest uppercase">Round <%= game.round %> of <%= Games::WriteAndVote::MAX_ROUNDS %> — Write your best answer...</span>
```

**Step 5: Update stage writing label**

In `app/views/games/write_and_vote/_stage_writing.html.erb`, replace line 14:

```erb
      Writing Phase: Round <%= game.round %>
```

With:

```erb
      Writing Phase: Round <%= game.round %> of <%= Games::WriteAndVote::MAX_ROUNDS %>
```

**Step 6: Run the tests — verify they pass**

```bash
bin/rspec spec/system/games/write_and_vote_prompt_display_spec.rb
```

Expected: PASS

**Step 7: Commit**

```bash
git add app/views/games/write_and_vote/_voting.html.erb \
        app/views/games/write_and_vote/_prompt_screen.html.erb \
        app/views/games/write_and_vote/_stage_writing.html.erb \
        spec/system/games/write_and_vote_prompt_display_spec.rb
git commit -m "feat: show total round count (Round X of 2) during Comedy Clash writing and voting"
```

---

## Task 4: Add Scoring Hint to A-List Filling Screen

**Files:**
- Modify: `app/views/games/category_list/_answer_form.html.erb:23-27`
- Test: `spec/system/games/category_list_happy_path_spec.rb` (add assertion)

The hint goes between the letter display and the category form. Use `game.current_letter` which is already used in `_answer_form.html.erb` line 26.

**Step 1: Write a failing test**

Read `spec/system/games/category_list_happy_path_spec.rb` to find where the filling phase is tested. Add an assertion that the scoring hint is visible during filling:

```ruby
it "shows scoring hint during the filling phase" do
  # Advance to filling state (follow existing spec's setup pattern)
  Capybara.using_session(:player2) do
    visit set_player_session_path(player2)
    expect(page).to have_content("= 2pts", wait: 5)
    expect(page).to have_content("= 1pt")
  end
end
```

**Step 2: Run the test — verify it fails**

```bash
bin/rspec spec/system/games/category_list_happy_path_spec.rb
```

Expected: FAIL

**Step 3: Add the scoring hint to the view**

In `app/views/games/category_list/_answer_form.html.erb`, add the hint after the letter display block (after line 27, before the timer block at line 29):

```erb
    <!-- Scoring hint -->
    <p class="text-center text-xs text-white/50 font-medium mb-4">
      💡 Starts with <%= game.current_letter %> = 2pts · unique answer = 1pt · same as someone else = 0pts
    </p>
```

**Step 4: Run the test — verify it passes**

```bash
bin/rspec spec/system/games/category_list_happy_path_spec.rb
```

Expected: PASS

**Step 5: Run the full system suite to check for regressions**

```bash
bin/rspec spec/system
```

Expected: all passing

**Step 6: Commit**

```bash
git add app/views/games/category_list/_answer_form.html.erb \
        spec/system/games/category_list_happy_path_spec.rb
git commit -m "feat: add scoring hint (2pts/1pt/0pts) to A-List filling screen"
```

---

## Task 5: Final Check and PR

**Step 1: Run rubocop**

```bash
rubocop
```

If there are failures, run `rubocop -A` to auto-fix, then re-run to confirm clean.

**Step 2: Run the full system suite one more time**

```bash
bin/rspec spec/system
```

Expected: all passing

**Step 3: Create a feature branch and PR**

These changes were made on `main` during planning. Move them to a branch:

```bash
git checkout -b fix/in-game-clarity-phase-1
git push -u origin fix/in-game-clarity-phase-1
```

Then open a PR against `main`. PR description should cover:
- **Why:** New player confusion from user testing — vague waiting states, no letter labels, surprise second round, missing scoring rules at the moment of decision
- **Decisions:** All view-only changes; used existing `MAX_ROUNDS` constant rather than hardcoding `2`; scoring hint is intentionally muted (not a banner) so it doesn't interrupt the flow
- **Reviewer notes:** The letter badge order on hand must match stage — both use `.order(:id)` on the same `responses` relation, so they're consistent
