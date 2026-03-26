# Post-Game Login Upsell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show logged-out room hosts a soft upsell card on their game-over screen encouraging them to sign up.

**Architecture:** A single shared partial with a visibility guard, rendered at the bottom of each game type's `_game_over.html.erb`. No model/controller/route/JS changes. TDD with a system spec covering the three visibility cases.

**Tech Stack:** Rails ERB partials, Tailwind CSS, RSpec system specs

**Spec:** `docs/superpowers/specs/2026-03-22-post-game-login-upsell-design.md`

---

### Task 1: Write the system spec

**Files:**
- Create: `spec/system/games/login_upsell_spec.rb`

The spec drives a Speed Trivia game to the `finished` state using service methods (same pattern as `speed_trivia_happy_path_spec.rb`), then checks three visibility scenarios. Uses `Capybara.using_session` to isolate host vs player views.

- [ ] **Step 1: Write the failing spec**

```ruby
# spec/system/games/login_upsell_spec.rb
require 'rails_helper'

RSpec.describe "Post-game login upsell", :js, type: :system do
  let!(:room) { create(:room, game_type: "Speed Trivia", user: nil) }

  before do
    default_pack = create(:trivia_pack, :default)
    12.times do |i|
      create(:trivia_question,
        trivia_pack: default_pack,
        body: "Question #{i + 1}?",
        correct_answers: ["Answer #{i + 1}"],
        options: ["Answer #{i + 1}", "Wrong A", "Wrong B", "Wrong C"])
    end
  end

  def join_and_play_to_game_over
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
    end

    # Host starts the game
    Capybara.using_session(:host) do
      unless page.has_button?("Start Game", wait: 3)
        visit current_path
      end
      click_on "Start Game"
      expect(page).to have_content("Get ready!")
      find("#start-from-instructions-btn", wait: 5).click
      expect(page).to have_button("Start First Question", wait: 5)
      click_on "Start First Question"
      expect(page).to have_content(/question 1/i, wait: 5)
    end

    # All players answer
    game = room.reload.current_game
    [:host, :player2, :player3].each do |session|
      Capybara.using_session(session) do
        visit current_path
        find('[data-test-id="answer-option-0"]', match: :first, wait: 5).click
        expect(page).to have_content("Locked in!", wait: 5)
      end
    end

    # Fast-forward to game over
    game.update!(current_question_index: game.trivia_question_instances.count - 1)
    Games::SpeedTrivia.close_round(game: game.reload)
    Games::SpeedTrivia.next_question(game: game.reload)
    game
  end

  context "logged-out host" do
    it "shows the upsell card" do
      join_and_play_to_game_over

      Capybara.using_session(:host) do
        visit current_path
        expect(page).to have_content(/game over/i, wait: 5).or have_content("Place", wait: 5)
        expect(page).to have_content("You just hosted like a pro")
        expect(page).to have_link("Sign up free", href: host_path)
      end
    end
  end

  context "regular player (not host)" do
    it "does not show the upsell card" do
      join_and_play_to_game_over

      Capybara.using_session(:player2) do
        visit current_path
        expect(page).to have_content(/game over/i, wait: 5).or have_content("Place", wait: 5)
        expect(page).not_to have_content("You just hosted like a pro")
      end
    end
  end

  context "logged-in host" do
    let!(:facilitator) { create(:user) }
    let!(:room) { create(:room, game_type: "Speed Trivia", user: facilitator) }

    it "does not show the upsell card" do
      join_and_play_to_game_over

      Capybara.using_session(:host) do
        visit current_path
        expect(page).to have_content(/game over/i, wait: 5).or have_content("Place", wait: 5)
        expect(page).not_to have_content("You just hosted like a pro")
      end
    end
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `TEST_ENV_NUMBER=2 bin/rspec spec/system/games/login_upsell_spec.rb`
Expected: All 3 examples fail — "logged-out host" fails because "You just hosted like a pro" text doesn't exist yet. The other two may pass vacuously (checking absence of non-existent text), but that's fine — they become meaningful once the partial exists.

- [ ] **Step 3: Commit the failing spec**

```bash
git add spec/system/games/login_upsell_spec.rb
git commit -m "test: add failing system spec for post-game login upsell"
```

---

### Task 2: Create the upsell partial

**Files:**
- Create: `app/views/games/shared/_login_upsell.html.erb`

- [ ] **Step 1: Create the partial**

```erb
<% if player == room.host && room.user.nil? %>
  <div class="mt-6 max-w-md mx-auto">
    <div class="bg-white/10 backdrop-blur-md rounded-2xl p-6 border border-white/20 text-center">
      <p class="text-white font-black text-lg mb-2">You just hosted like a pro.</p>
      <p class="text-blue-200 text-sm mb-1">Make it yours — create custom questions, prompts, and categories.</p>
      <p class="text-blue-200 text-sm mb-4">Keep it clean — moderate answers before they hit the big screen.</p>
      <%= link_to "Sign up free", host_path,
            class: "inline-block px-6 py-3 bg-orange-500 hover:bg-orange-600 text-white font-bold rounded-full shadow-lg transform transition hover:scale-105 active:scale-95" %>
    </div>
  </div>
<% end %>
```

- [ ] **Step 2: Commit the partial (tests still fail — not rendered yet)**

```bash
git add app/views/games/shared/_login_upsell.html.erb
git commit -m "feat: add login upsell shared partial"
```

---

### Task 3: Render the upsell in all three game-over partials

**Files:**
- Modify: `app/views/games/write_and_vote/_game_over.html.erb:37` (after feedback CTA, before "Back to Home" link)
- Modify: `app/views/games/speed_trivia/_game_over.html.erb:43` (end of file, after mini leaderboard)
- Modify: `app/views/games/category_list/_game_over.html.erb:49` (end of file, after mini leaderboard)

- [ ] **Step 1: Add render call to Write And Vote game-over**

In `app/views/games/write_and_vote/_game_over.html.erb`, after line 37 (`<%= render "shared/feedback_cta" %>`), before line 39 (`<%= link_to "Back to Home" ...`), add:

```erb
  <%= render "games/shared/login_upsell", room: room, player: player %>
```

- [ ] **Step 2: Add render call to Speed Trivia game-over**

In `app/views/games/speed_trivia/_game_over.html.erb`, at the end of the file (after the closing `</div>` of the mini leaderboard on line 42, before the final `</div>` on line 43), add:

```erb
  <%= render "games/shared/login_upsell", room: room, player: player %>
```

- [ ] **Step 3: Add render call to Category List game-over**

In `app/views/games/category_list/_game_over.html.erb`, at the end of the file (after the closing `</div>` of the mini leaderboard on line 48, before the final `</div>` on line 49), add:

```erb
  <%= render "games/shared/login_upsell", room: room, player: player %>
```

- [ ] **Step 4: Run the spec to verify all tests pass**

Run: `TEST_ENV_NUMBER=2 bin/rspec spec/system/games/login_upsell_spec.rb`
Expected: All 3 examples PASS

- [ ] **Step 5: Run rubocop**

Run: `rubocop app/views/games/shared/_login_upsell.html.erb app/views/games/write_and_vote/_game_over.html.erb app/views/games/speed_trivia/_game_over.html.erb app/views/games/category_list/_game_over.html.erb`
Expected: No offenses

- [ ] **Step 6: Commit**

```bash
git add app/views/games/write_and_vote/_game_over.html.erb app/views/games/speed_trivia/_game_over.html.erb app/views/games/category_list/_game_over.html.erb
git commit -m "feat: render login upsell on all game-over screens for logged-out hosts"
```

---

### Task 4: Final verification

- [ ] **Step 1: Run the full system test suite to check for regressions**

Run: `TEST_ENV_NUMBER=2 bin/rspec spec/system/games/`
Expected: All existing tests still pass

- [ ] **Step 2: Run brakeman security check**

Run: `brakeman -q`
Expected: No new warnings
